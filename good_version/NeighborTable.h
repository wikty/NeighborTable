#ifndef NEIGHBOR_TABLE_H_
#define NEIGHBOR_TABLE_H_

enum {
    PACKET_LOST_RATE = 2,
    PACKET_LEAST_TIMES=3,
    AM_IAMHEREMSG = 16,
    WARNING_TIMES = 18,
    PACKET_PERIOD_MILLI = 240,
    SENDER_PERIOD_MILLI = 250,
    WARNING_PERIOD_MILLI = 260,
    AM_SERIALREQUESTMSG = 0x88,
    AM_NEIGHBORTABLEMSG = 0x89,
    ACTIVE_PERIOD_MILLI = 3000
};

/* nx_* are defined by tinyos, convert to specific paltform data type */
typedef nx_struct IAmHereMsg {
    nx_uint16_t nodeid;
} IAmHereMsg;

typedef nx_struct DetectedNode {
    nx_uint16_t nodeid;
    nx_uint32_t ftime;
    nx_uint32_t ltime;
    nx_uint32_t times;
    nx_uint8_t isneighbor;
    nx_uint8_t deleted;
} DetectedNode;

typedef nx_struct NeighborNode {
    nx_uint16_t nodeid;
    nx_uint16_t reliability;
    nx_uint8_t deleted;
} NeighborNode;

typedef nx_struct NeighborTableMsg {
    nx_uint16_t nodeid;
    nx_uint16_t reliability;
    nx_uint8_t eof;
} NeighborTableMsg;

typedef nx_struct SerialRequestMsg {
    nx_uint16_t nodeid;
} SerialRequestMsg;

#endif
