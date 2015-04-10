#include <Timer.h>
#include "NeighborTable.h"

module NeighborTableC {
    uses interface Boot;
    uses interface Leds;
    uses interface Timer<TMilli> as Timer0;
    uses interface Timer<TMilli> as Timer1;
    uses interface Timer<TMilli> as Timer2;
    uses interface Pool<DetectedNode> as DetectedPool;
    uses interface Pool<NeighborNode> as NeighborPool;
    
    uses interface SplitControl as AMControl;
    uses interface Packet;
    uses interface AMPacket;
    uses interface AMSend;
    uses interface Receive as AMReceive;
    
    uses interface StdControl as DisseminationControl;
    uses interface DisseminationValue<uint16_t> as Value;
    uses interface DisseminationUpdate<uint16_t> as Update;
    
    uses interface StdControl as CollectorControl;
    uses interface RootControl;
    uses interface Receive as CollectorReceive;
    uses interface Send as CollectorSend;
    
    uses interface SplitControl as SerialControl;
    uses interface Receive as SerialReceive;
    uses interface AMSend as SerialSend;
    uses interface Packet as SerialPacket;
}

implementation {
    
    bool busy = FALSE;
    bool cbusy = FALSE;
    bool sbusy = FALSE;
    
    message_t pkt, nbpkt, spkt;
    
    uint16_t requestid = -1;

    NeighborNode* ntb[100];
    DetectedNode* dtb[100];
    int nidx = -1;
    int didx = -1;
    int current = -1;
    
    int i = 0;
    
    int ldirect;
    int lcount;
    int lwho;

    
    void dispatch(IAmHereMsg* msg);
    void sendneighbor();
    void light(uint8_t direct);
    uint8_t islastneighbor(int curr);
    
    /*
     * Components start&stop
     */
    event void Boot.booted() {
        for(i=0; i<100; i++){
        	ntb[i] = NULL;
        	dtb[i] = NULL;
        }
        
        call AMControl.start();
    }

    event void AMControl.startDone(error_t err) {
        if (err == SUCCESS) {
            call Timer0.startPeriodic(SENDER_PERIOD_MILLI);
            
            call DisseminationControl.start();
            call CollectorControl.start();
            
            if(TOS_NODE_ID == 1){
                call RootControl.setRoot();
                call SerialControl.start();
            }
        }
        else {
            call AMControl.start();
        }
    }

    event void AMControl.stopDone(error_t err) {
    }
    
    event void SerialControl.startDone(error_t err) {
        if(err == SUCCESS) {
             /*light(0);*/
        }
    }
    
    event void SerialControl.stopDone(error_t err) {
    }


    /* 
     * ActiveMessage send&receive 
     */
    event void Timer0.fired() {
        if (!busy) {
            IAmHereMsg* p = (IAmHereMsg*)(call Packet.getPayload(&pkt, sizeof(IAmHereMsg)));
            p->nodeid = TOS_NODE_ID;

            if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(IAmHereMsg)) == SUCCESS) {
                busy = TRUE;
            }
        }
    }
    
    event void AMSend.sendDone(message_t* msg, error_t error) {
        if (&pkt == msg) {
            busy = FALSE;
            call Leds.led0Toggle();
        }
    }
    
    event message_t* AMReceive.receive(message_t* msg, void *payload, uint8_t len) {
        if (len == sizeof(IAmHereMsg)) {
            call Leds.led1Toggle();
            dispatch(payload);
        }
        return msg;
    }
    
    
    /*
     * INPUT
     */
    event message_t* SerialReceive.receive(message_t* buffer, void* payload, uint8_t len) {
        NeighborTableMsg* msg = (NeighborTableMsg*)payload;
        requestid = msg->nodeid;
        /*light(0);*/
        call Update.change(&requestid);
        return buffer;
    }
    
    event void Value.changed() {
        const uint16_t* newval = call Value.get();
        requestid = *newval;
        if (requestid == TOS_NODE_ID) {
            /* fire Timer1 to send neighbor table */
            call Leds.led2On();
            sendneighbor();
        }
    }
    
    event void Timer1.fired() {
        if (current == -1) {
            call Timer1.stop();
            call Leds.led2Off();
        }
        else if(!cbusy){
            if(!ntb[current]->deleted) {
                NeighborTableMsg* p = (NeighborTableMsg*)(call CollectorSend.getPayload(&nbpkt, sizeof(NeighborTableMsg)));
                p->nodeid = ntb[current]->nodeid;
                p->reliability = ntb[current]->reliability;
                p->eof = 0;
                if (islastneighbor(current)) {
                    /* meaning data is sent over */
                    p->eof = 1;
                    current = 0;
                }
                if (call CollectorSend.send(&nbpkt, sizeof(NeighborTableMsg)) == SUCCESS) {
             	    cbusy = TRUE;
                }
            }
            current--;
        }
    }
    
    event void CollectorSend.sendDone(message_t* msg, error_t err) {
        if (&nbpkt == msg) {
            cbusy = FALSE;
        }
    }
    
    
    /*
     * OUTPUT
     */
   event message_t* CollectorReceive.receive(message_t* msg, void* payload, uint8_t len) {
        NeighborTableMsg* rec = (NeighborTableMsg*)payload;
        if(!sbusy) {
            NeighborTableMsg* p = (NeighborTableMsg*)call SerialPacket.getPayload(&spkt, sizeof(NeighborTableMsg));
            p->nodeid = rec->nodeid;
            p->reliability = rec->reliability;
            p->eof = rec->eof;
            if(rec->eof == 1){
                light(5);
            }
            if(call SerialSend.send(AM_BROADCAST_ADDR, &spkt, sizeof(NeighborTableMsg)) == SUCCESS) {
                sbusy = TRUE;
            }
        }
        return msg;
    } 
    
    event void SerialSend.sendDone(message_t* buffer, error_t err) {
        if(buffer == &spkt) {
            sbusy = FALSE;
        }
    }
    
    
    /* Debug used light */
    event void Timer2.fired() {
        if(lcount == 0) {
            call Timer2.stop();
        }
        else {
            if(ldirect == 0) {
                if(lwho == 0) {
                    call Leds.set(0);
                }
                else {
                    call Leds.set(255);
                }
                lwho = 1 - lwho;
            }
            else if(ldirect == 1 || ldirect == 2) {
                /* ldirect == 1 or ldirect == 2 */
                if(lwho % 3 == 0){
                    call  Leds.led0Toggle();
                }
                else if(lwho % 3 == 1) {
                    call Leds.led1Toggle();
                }
                else {
                    call Leds.led2Toggle();
                }
                lwho ++;
                if(ldirect == 2){
                    lwho++;
                }
            }
            else if(ldirect == 3) {
                call Leds.led0Toggle();
            }
            else if(ldirect == 4) {
                call Leds.led1Toggle();
            }
            else if(ldirect == 5) {
                call Leds.led2Toggle();
            }
            lcount--;
        }
    }

    
    /*
     * private functions
     */
    void light(uint8_t direct) {
        ldirect = direct;
        lcount = WARNING_TIMES;
        if(direct == 0) {
            lwho = 1;
        }
        else if(direct == 1) {
            lwho = 0;
        }
        else if(direct == 2) {
            lwho = 2;
        }
        else {
            lwho = 0;
        }
        call Timer2.startPeriodic(WARNING_PERIOD_MILLI);
    }
     
    void sendneighbor() {
        current = nidx;
        call Timer1.startPeriodic(PACKET_PERIOD_MILLI);
    }
    
    uint8_t islastneighbor(int curr) {
        for(i=curr-1; i>=0; i--) {
            if(!ntb[i]->deleted)return 0;
        }
        return 1;
    }
    
    uint8_t canbeneighbor(DetectedNode* p) {
        if (p && !p->deleted) {
            if ((p->times > PACKET_LEAST_TIMES) && 
                ((p->ltime - p->ftime)/SENDER_PERIOD_MILLI < (p->times)*PACKET_LOST_RATE)) {
                return 1;
            }
        }
        return 0;
    }
    
    NeighborNode* getneighbor(uint16_t nodeid) {
        NeighborNode* p = NULL;
        for(i=0; i<=nidx; i++) {
	        p = ntb[i];
            if (p->nodeid == nodeid) {
                return p;
            }
        }
        return NULL;
    }
    
    void addneighbor(DetectedNode* p) {
        NeighborNode* pnew = getneighbor(p->nodeid);
        if (!pnew) {
            pnew = call NeighborPool.get();
	        ntb[++nidx] = pnew;
        }
        pnew->nodeid = p->nodeid;
        /* 0.0~1.0 */
        pnew->reliability = (p->times*100) / ((p->ltime - p->ftime)/SENDER_PERIOD_MILLI);
        pnew->deleted = 0;
    }
    
    void updateneighbor(DetectedNode* p) {
        NeighborNode* pn = getneighbor(p->nodeid);
        if(!pn) return;
        pn->reliability = (p->times*100) / ((p->ltime - p->ftime)/SENDER_PERIOD_MILLI);
    }
    
    void removeneighbor(DetectedNode* dp) {
        NeighborNode *p = NULL;
        for(i=0; i<=nidx; i++){
	        p =  ntb[i];
	        if(!p->deleted && p->nodeid == dp->nodeid){
            	  p->deleted = 1;
        	}
        }
    }
    
    DetectedNode* getdetected(uint16_t nodeid) {
        DetectedNode* p = NULL;
        for(i=0; i<=didx; i++){
	        p = dtb[i];
            if (p->nodeid == nodeid) {
                return p;
            }
        }
        return NULL;
    }
    
    void adddetected(IAmHereMsg* msg) {
        uint32_t timenow = call Timer0.getNow();
        DetectedNode* pnew = getdetected(msg->nodeid);
        if (!pnew) {
            pnew = call DetectedPool.get();
            dtb[++didx] = pnew;
        }
        pnew->nodeid = msg->nodeid;
        pnew->ftime = timenow;
        pnew->ltime = timenow;
        pnew->times = 1;
        pnew->isneighbor = 0;
        pnew->deleted = 0;
    }
    
    void dispatch(IAmHereMsg* msg) {
        bool existed = FALSE;
        DetectedNode* p = NULL;
        uint32_t timenow = call Timer0.getNow();
    	for(i=0; i<=didx; i++){
    	    p = dtb[i];
            if (p->deleted) continue;
            if (p->nodeid == msg->nodeid) {
                existed = TRUE;
                p->ltime = timenow;
                p->times = p->times + 1;
                if (p->isneighbor == 0 && canbeneighbor(p)) {
                    p->isneighbor = 1;
                    addneighbor(p);
                }
                else if(p->isneighbor) {
                    updateneighbor(p);
                }
            }
            else if(timenow - p->ltime > ACTIVE_PERIOD_MILLI){
               p->deleted = 1;
               if (p->isneighbor) {
                   removeneighbor(p);
               }
            }
        }
        if (!existed) {
	        adddetected(msg);
        }
    }
}
