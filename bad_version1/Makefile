COMPONENT=NeighborTableAppC

BUILD_EXTRA_DEPS += NeighborTable.class
CLEAN_EXTRA = *.class NeighborTableMsg.java SerialRequestMsg.java

CFLAGS += -I$(TOSDIR)/lib/net \
          -I$(TOSDIR)/lib/net/drip \
          -I$(TOSDIR)/lib/net/le \
          -I$(TOSDIR)/lib/net/ctp \
          -I$(TOSDIR)/lib/T2Hack

NeighborTable.class: $(wildcard *.java) NeighborTableMsg.java SerialRequestMsg.java

NeighborTableMsg.java:
        mig java -target=null $(CFLAGS) -java-classname=NeighborTablelMsg NeighborTable.h NeighborTableMsg -o $@

SerialRequestMsg.java:
        mig java -target=null $(CFLAGS) -java-classname=SerialRequestMsg NeighborTable.h SerialRequestMsg -o $@

include $(MAKERULES)
