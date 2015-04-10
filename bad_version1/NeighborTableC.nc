#include <Timer.h>
#include "NeighborTable.h"

module NeighborTableC {
    uses interface Boot;
    uses interface Timer<TMilli> as Timer0;
    uses interface Timer<TMilli> as Timer1;
    uses interface Pool<DetectedNode> as DetectedPool;
    uses interface Pool<NeighborNode> as NeighborPool;
    
    /* control the ActiveMessageC component starting and stoping */
    uses interface SplitControl as AMControl;
    
    uses interface Packet;
    uses interface AMPacket;
    uses interface AMSend;
    
    uses interface Receive as AMReceive;
    
    /* dissemination */
    uses interface StdControl as DisseminationControl;
    /* consumer */
    uses interface DisseminationValue<uint16_t> as Value;
    /* producer */
    uses interface DisseminationUpdate(uint16_t> as Update;
    
    /* collector */
    uses interface StdControl as RoutingControl;
    uses interface RootControl;
    uses interface Receive as CollectorReceive;
    uses interface Send as CollectorSend;
    
    /* Serial communication */
    uses interface SplitControl as SerialControl;
    uses interface Receive as SerialReceive;
    uses interface AMSend as SerialAMSend;
    uses interface Packet as SerialPacket;
}

implementation {
    
    /* flag to track whether radio is busy */
    bool busy = FALSE;
    bool cbusy = FALSE;  /* collector sender is busy */
    bool sbusy = FALSE;  /* serial port communication */
    message_t pkt, nbpkt, spkt;
    uint16_t requestid = -1;
    NeighborNode* current = NULL;
    
    
    /* the list of neighbor */
    NeighborNode* ntb = NULL;
    /* the list of detected */
    DetectedNode* dtb = NULL;
    
    /* function delcare */
    void dispatch(IAmHereMsg* msg);
    void sendneighbor();

    event void Boot.booted() {
        /* starting radio driver */
        call AMControl.start();
    }

    event void AMControl.startDone(error_t err) {
        /* if radio starting is done, then fire timer */
        if (err == SUCCESS) {
            call Timer0.startPeriodic(SENDER_PERIOD_MILLI);
            
            /* start dissemination */
            call DisseminationControl.start();
            
            /* start collection */
            call RoutingControl.start();
            
            if(TOS_NODE_ID == 1){
                /* node1 is root node, responsible for collection data that sent from others node in the network */
                call RootControl.setRoot();
                
                /* node1 communicate with PC by serial port */
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

    /* send nodeid packet */
    event void Timer0.fired() {
        if (!busy) {
            IAmHereMsg* p = (IAmHereMsg*)(call Packet.getPayload(&pkt, sizeof(IAmHereMsg)));
            p->nodeid = TOS_NODE_ID;
            /* broadcast packet to all nodes in radio range */
            if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(IAmHereMsg)) == SUCCESS) {
                busy = TRUE;  /* own radio until sendDone */
            }
        }
    }
    
    /* nodeid packet send done */
    event void AMSend.SendDone(message_t* msg, error_t error) {
        if (&pkt == msg) {
            busy = FALSE;
        }
    }
    
    /* receive nodeid packet */
    event message_t* AMReceive.receive(message_t* msg, void *payload, uint8_t len) {
        if (len == sizeof(IAmHereMsg)) {
            dispatch(payload);
        }
        return msg;
    }
    
    /* send neighbor info */
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

    
    /* neighbor info send done */
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

    

/***************************************************/  
/*    Input nodeid                                 */
/**************************************************/
    /* producer
        requestid = 2;
        call Update.change(&requestid);
    */
    event message_t* SerialReceive.receive(message_t* buffer, void* payload, uint8_t len) {
        if(len != sizeof(SerialRequestMsg)) return buffer;
        
        SerialRequestMsg* msg = (SerialRequestMsg*)payload;
        requestid = msg->nodeid;
        call Update.change(&requestid);
        return buffer;
    }
    
    /* only consumer(non-basestation node) will be fired this event */
    event void Value.changed() {
        const uint8_t* newval = call Value.get();
        requestid = *newval;
        /* basestation request current node's route information */
        if (requestid == TOS_NODE_ID) {
            sendneighbor();
        }
    }

/**************************************************/ 
/*            Output   neighbor table             */
/*************************************************/
    /* only for root node to collect data */
    /* post data to PC by serial port */
    event message_t* CollectorReceive.receive(message_t* msg, void* payload, uint8_t len) {
        if(len != sizeof(NeighborTableMsg)) return msg;
        NeighborTableMsg* rec = (NeighborTableMsg*)payload;
        if(!sbusy) {
            NeighborTableMsg* pkt = (NeighborTableMsg*)call SerialPacket.getPayload(&spkt, sizeof(NeighborTableMsg));
            if(pkt==NULL) return msg;
            if(call SerialPacket.maxPayloadLength() < sizeof(NeighborTableMsg)) {
                return msg;
            }
            pkt->nodeid = rec->nodeid;
            pkt->reliability = rec->reliability;
            pkt->eof = rec->eof;
            
            if(call SerialAMSend.send(AM_BROADCAST_ADDR, &spkt, sizeof(NeighborTableMsg)) == SUCCESS) {
                sbusy = TRUE;
            }
        }
        return msg;
    }
    
    event void SerialAMSend.sendDone(message_t* buffer, error_t err) {
        if(buffer == &spkt) {
            sbusy = FALSE;
        }
    }
    
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
        pnew->reliability = ((float)(p->times))/((p->ltime - p->ftime)/SENDER_PERIOD_MILLI);
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
