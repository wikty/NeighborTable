#include <Timer.h>
#include "NeighborTable.h"

configuration NeighborTableAppC {
}

implementation {
    components MainC;
    components LedsC;
    components NeighborTableC as App;
    components new TimerMilliC() as Timer0;
    components new TimerMilliC() as Timer1;
    components new TimerMilliC() as Timer2;
    components new PoolC(DetectedNode, 100) as DetectedPoolC;
    components new PoolC(NeighborNode, 100) as NeighborPoolC;
    
    components ActiveMessageC;
    components new AMSenderC(AM_IAMHEREMSG);
    components new AMReceiverC(AM_IAMHEREMSG);
    
    components DisseminationC;
    components new DisseminatorC(uint16_t, 0x1234) as Diss16C;
    
    components CollectionC as Collector;
    components new CollectionSenderC(0xee);
    
    components SerialActiveMessageC as SerialAM;
    

    App.Boot -> MainC;
    App.Leds -> LedsC;
    App.Timer0 -> Timer0;
    App.Timer1 -> Timer1;
    App.Timer2 -> Timer2;
    App.DetectedPool -> DetectedPoolC;
    App.NeighborPool -> NeighborPoolC;
    
    App.AMControl -> ActiveMessageC;
    App.Packet -> AMSenderC;
    App.AMPacket -> AMSenderC;
    App.AMSend -> AMSenderC;
    App.AMReceive -> AMReceiverC;
    
    App.DisseminationControl -> DisseminationC;
    App.Value -> Diss16C;
    App.Update -> Diss16C;
    
    App.CollectorControl -> Collector;
    App.RootControl -> Collector;
    App.CollectorReceive -> Collector.Receive[0xee];
    App.CollectorSend -> CollectionSenderC;
    
    App.SerialPacket -> SerialAM;
    App.SerialControl -> SerialAM;
    App.SerialReceive -> SerialAM.Receive[AM_NEIGHBORTABLEMSG];
    App.SerialSend -> SerialAM.AMSend[AM_NEIGHBORTABLEMSG];
}
