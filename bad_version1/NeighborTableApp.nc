#include <Timer.h>
#include "NeighborTable.h"

/*
 * Install into mote:
 *      $ make telosb install,1
 *      $ make telosb reinstall,2
 */
/*
COMPONENT=EasyDisseminationAppC
CFLAGS += -I$(TOSDIR)/lib/net \
          -I$(TOSDIR)/lib/net/drip

include $(MAKERULES)
*/
/*
COMPONENT=EasyCollectionAppC
CFLAGS += -I$(TOSDIR)/lib/net \
          -I$(TOSDIR)/lib/net/le \
          -I$(TOSDIR)/lib/net/ctp
include $(MAKERULES)
*/
/* 
COMPONENT=TestSerialAppC
BUILD_EXTRA_DEPS += TestSerial.class
CLEAN_EXTRA = *.class TestSerialMsg.java

CFLAGS += -I$(TOSDIR)/lib/T2Hack

TestSerial.class: $(wildcard *.java) TestSerialMsg.java

TestSerialMsg.java:
        mig java -target=null $(CFLAGS) -java-classname=TestSerialMsg TestSerial.h test_serial_msg -o $@
        
include $(MAKERULES)

*/
/*
In Unix for serial port
$ java net.tinyos.tools.Listen -comm serial@/dev/ttyS0:telos
In Unix for serial-over-USB port
$ java net.tinyos.tools.Listen -comm serial@/dev/ttyUSB0:telos
$ java net.tinyos.tools.Listen -comm serial@/dev/usb/tts/0:telos

on Linux you will typically need to make this serial port world writeable. As superuser, execute the following command:
$ chmod 666 serialport
*/

configuration NeighborTableC {
}

implementation {
    components MainC;
    components Leds;
    components NeighborTableC as App;
    components new TimerMilliC() as Timer0;
    components new TimerMilliC() as Timer1;
    components new PoolC(DetectedNode, 100) as DetectedPoolC;
    components new PoolC(NeighborNode, 100) as NeighborPoolC;
    
    /* radio layer */
    /* because AcitveMessageC is a wrapper for various platforms, so you can find it in the directory tos/platforms/someplatem/ActiveMessageC.nc */
    components ActiveMessageC;
    
    /* AM_NEIGHBORTABLE indicates AM type, defined in *.h file */
    /* The AM_NEIGHBORTABLE parameter indicates the AM type of the AMReceiverC and is chosen to be the same as that used for the AMSenderC used earlier, which ensures that the same AM type is being used for both transmissions and receptions */
    components new AMSenderC(AM_IAMHEREMSG);
    components new AMReceiverC(AM_IAMHEREMSG);
    
    components DisseminationC;
    
    /* (type, key), type is the type of the value we want to dissemination, key allows to have diffreent instances of DisseminatorC */
    components new DisseminatorC(uint16_t, 0x1234) as Diss16C;
    
    /* tos/lib/net/ctp/CollectionC.nc */
    components CollectionC as Collector;
    /* tos/lib/net/ctp/CollectionSenderC.nc */
    components new CollectionSenderC(0xee);
    
    /* Serial communication */
    components SerialActiveMessageC as SerialAM;
    

    App.Boot -> MainC;
    App.Leds -> LedsC;
    App.Timer0 -> Timer0;
    App.Timer1 -> Timer1;
    App.DetectedPool -> DetectedPoolC;
    App.NeighborPool -> NeighborPoolC;
    
    App.AMControl -> ActiveMessageC;  /* App.SplitControl -> ActiveMessageC.SplitControl, AMControl is a as alias for SplitControl, defined in BlinkToRadioC.nc */
    
    
    /* Although it is possible to wire directly to the ActiveMessageC component, we will instead use the AMSenderC component */
    /* AMSenderC in the  tos/system/AMSenderC.nc, is a configuration component and provides AMSend, Packet, AMPacket, PacketAcknowledgements interfaces, you can manunal those interfaces in the directory tos/interfaces */
    App.Packet -> AMSenderC;  /* App.Packet -> AMSenderC.Packet */
    App.AMPacket -> AMSenderC;  /* App.AMPacket -> AMSenderC.AMPacket */
    App.AMSend -> AMSenderC;  /* App.AMSend -> AMSenderC->AMSend */
    
    App.AMReceive -> AMReceiverC;  /* App.Receive -> AMReceiverC.Receive */
    
     /* control dissemination */
    /* because DisseminationControl is alias for StdContolr, EasyDisseminationC.StdControl -> DisseminationC; */
    App.DisseminationControl -> DisseminationC;
    
    /* DisseminatorC provide DisseminationValue and DisseminationUpdate interfaces */
    App.Value -> Diss16C;
    App.Update -> Diss16C;
    
    /* control Collection starting and stoping */
    App.RoutingControl -> Collector;
    /* set/unset root node */
    App.RootControl -> Collector;
    /* root node receive collection data */
    App.CollectorReceive -> Collector.Receive[0xee];
    /* non-root node send collection data */
    /* collector and sender should be used the same collection_id(here is 0xee) */
    App.CollectorSend -> CollectionSenderC;
    
    App.SerialPacket -> SerialAM;
    App.SerialControl -> SerialAM;
    App.SerialReceive -> SerialAM.Receive[AM_SERIALMSG];
    App.SerialAMSend -> SerialAM.AMSend[AM_SERIALMSG];
}
