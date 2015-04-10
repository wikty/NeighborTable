#include <Timer.h>
#include "NeighborTable.h"

module NeighborTableC {
    uses interface Boot;
    uses interface Leds;
    uses interface Timer<TMilli> as Timer0;
    uses interface Timer<TMilli> as Timer1;
    uses interface Pool<DetectedNode> as DetectedPool;
    uses interface Pool<NeighborNode> as NeighborPool;
    
    uses interface SplitControl as AMControl;
    uses interface Packet;
    uses interface AMPacket;
    uses interface AMSend;
    uses interface Receive as AMReceive;
    
    uses interface StdControl as DisseminationControl;
    uses interface DisseminationValue<uint16_t> as Value;
    uses interface DisseminationUpdate(uint16_t> as Update;
    
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
    
    NeighborNode* ntb = NULL;
    DetectedNode* dtb = NULL;
    NeighborNode* current = NULL;
    
    void dispatch(IAmHereMsg* msg);
    void sendneighbor();

    /*
     * Components start&stop
     */
    event void Boot.booted() {
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
    
    event SerialControl.startDone(error_t err) {
    }
    
    event SerialControl.stopDone(error_t err) {
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
    
    event void AMSend.SendDone(message_t* msg, error_t error) {
        if (&pkt == msg) {
            busy = FALSE;
        }
    }
    
    event message_t* AMReceive.receive(message_t* msg, void *payload, uint8_t len) {
        if (len == sizeof(IAmHereMsg)) {
            dispatch(payload);
        }
        return msg;
    }
    
    
    /*
     * INPUT
     */
    event message_t* SerialReceive.receive(message_t* buffer, void* payload, uint8_t len) {
        if(len != sizeof(SerialRequestMsg)) return buffer;
        
        SerialRequestMsg* msg = (SerialRequestMsg*)payload;
        requestid = msg->nodeid;
        call Update.change(&requestid);
        return buffer;
    }
    
    event void Value.changed() {
        const uint8_t* newval = call Value.get();
        requestid = *newval;
        if (requestid == TOS_NODE_ID) {
            /* fire Timer1 to send neighbor table */
            sendneighbor();
        }
    }
    
    event void Timer1.fired() {
        if (!current) {
            call Timer1.stop();
        }
        else if(!cbusy){
            NeighborTableMsg* p = (NeighborTableMsg*)(call CollectorSend.getPayload(&nbpkt, sizeof(NeighborTableMsg)));
            p->nodeid = current->nodeid;
            p->reliability = current->reliability;
            p->eof = 0;
            current = current->next;
            if (!current) {
                /* meaning data is sent over */
                p->eof = 1;
            }
            if (call CollectorSend.send(&nbpkt, sizeof(NeighborTableMsg)) != SUCCESS) {
                /* call Leds.led0On(); */
            }
            else {
                cbusy = TRUE;
            }
        }
    }
    
    event void CollectorSend.sendDone(message_t* msg, error_t err) {
        /*
        if(err != SUCCESS){
            call Leds.led0On();
        }
        */
        if (&nbpkt == msg) {
            cbusy = FALSE;   
        }
    }
    
    
    /*
     * OUTPUT
     */
   event message_t* CollectorReceive.receive(message_t* msg, void* payload, uint8_t len) {
        if(len != sizeof(NeighborTableMsg)) return msg;
        NeighborTableMsg* rec = (NeighborTableMsg*)payload;
        if(!sbusy) {
            NeighborTableMsg* p = (NeighborTableMsg*)call SerialPacket.getPayload(&spkt, sizeof(NeighborTableMsg));
            if(p==NULL) return msg;
            if(call SerialPacket.maxPayloadLength() < sizeof(NeighborTableMsg)) {
                return msg;
            }
            p->nodeid = rec->nodeid;
            p->reliability = rec->reliability;
            p->eof = rec->eof;
            
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
    
    /*
     * private functions
     */
    void sendneighbor() {
        current = ntb;
        call Timer1.startPeriodic(PACKET_PERIOD_MILLI);
    }
    
    uint8_t canbeneighbor(DetectedNode* p) {
        if (p && !p->deleted) {
            if ((p->times > PACKET_LEAST_TIMES) && 
                ((p->ltime - p->ftime)/(PACKET_LOST_RATE*SENDER_PERIOD_MILLI) < p->times)) {
                return 1;
            }
        }
        return 0;
    }
    
    NeighborNode* getneighbor(uint16_t nodeid) {
        NeighborNode* p = ntb;
        while (p) {
            if (p->nodeid == nodeid) {
                return p;
            }
            p = p->next;
        }
        return NULL;
    }
    
    NeighborNode* addneighbor(DetectedNode* p) {
        bool updated = TRUE;
        NeighborNode* pnew = getneighbor(p->nodeid);
        if (!pnew) {
            pnew = call NeighborPool.get();
            pnew->next = NULL;
            updated = FALSE;
        }
        pnew->nodeid = p->nodeid;
        /* 0.0~1.0 */
        pnew->reliability = ((float)(p->times))/((float)(p->ltime - p->ftime)/SENDER_PERIOD_MILLI);
        pnew->deleted = 0;
        
        if (updated) {
            return ntb;
        }
        
        if (ntb) {
            pnew->next = ntb;
        }
        return pnew;
    }
    
    void removeneighbor(DetectedNode* p) {
        NeighborNode *pnbr = ntb;
        while (pnbr) {
            if (!pnbr->deleted && pnbr->nodeid == p->nodeid) {
                pnbr->deleted = 1;
            }
            pnbr = pnbr->next;
        }
    }
    
    DetectedNode* getdetected(uint16_t nodeid) {
        DetectedNode* p = dtb;
        while (p) {
            if (p->nodeid == nodeid) {
                return p;
            }
            p = p->next;
        }
        return NULL;
    }
    
    DetectedNode* adddetected(IAmHereMsg* msg) {
        bool updated = TRUE;
        uint32_t timenow = call Timer0.getNow();
        DetectedNode* pnew = getdetected(msg->nodeid);
        if (!pnew) {
            updated = FALSE;
            pnew = call DetectedPool.get();
            pnew->next = NULL;
        }
        pnew->nodeid = msg->nodeid;
        pnew->ftime = timenow;
        pnew->ltime = timenow;
        pnew->times = 1;
        pnew->isneighbor = 0;
        pnew->deleted = 0;
        
        if (updated) {
            return dtb;
        }
        
        if (dtb) {
            pnew->next = dtb;
        }
        return pnew;
    }
    
    
    
    void dispatch(IAmHereMsg* msg) {
        bool existed = FALSE;
        DetectedNode* p = dtb;
        uint32_t timenow = call Timer0.getNow();
        while (p) {
            if (p->deleted) continue;
            if (p->nodeid == msg->nodeid) {
                existed = TRUE;
                p->ltime = timenow;
                p->times = p->times + 1;
                if (p->isneighbor == 0 && canbeneighbor(p)) {
                    p->isneighbor = 1;
                    ntb = addneighbor(p);
                }
            }
            else if(timenow - p->ltime > ACTIVE_PERIOD_MILLI){
                p->deleted = 1;
                if (p->isneighbor) {
                    removeneighbor(p);
                }
            }
            p = p->next;
        }
        if (!existed) {
            dtb = adddetected(msg);   
        }
    }
}
