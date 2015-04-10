COMPONENT=NeighborTableAppC

BUILD_EXTRA_DEPS += NeighborTable.class
CLEAN_EXTRA = *.class NeighborTableMsg.java SerialRequestMsg.java

PFLAGS = -DCC1K_DEF_FREQ=20

CFLAGS += -I$(TOSDIR)/lib/net \
          -I$(TOSDIR)/lib/net/drip \
          -I$(TOSDIR)/lib/net/le \
          -I$(TOSDIR)/lib/net/ctp \
          -I$(TOSDIR)/lib/T2Hack

NeighborTable.class:  NeighborTable.java NeighborTableMsg.java SerialRequestMsg.java
	javac *.java

NeighborTableMsg.java: NeighborTable.h
	mig java -target=$(PLATFORM) $(CFLAGS) -java-classname=NeighborTableMsg NeighborTable.h NeighborTableMsg -o $@

SerialRequestMsg.java: NeighborTable.h
	mig java -target=$(PLATFORM) $(CFLAGS) -java-classname=SerialRequestMsg NeighborTable.h SerialRequestMsg -o $@

include $(MAKERULES)
