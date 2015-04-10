#ifndef NEIGHBOR_TABLE_H_
#define NEIGHBOR_TABLE_H_

enum {
    PACKET_LOST_RATE = 2,
    PACKET_LEAST_TIMES=3,
    AM_IAMHEREMSG = 6,
    PACKET_PERIOD_MILLI = 130,
    SENDER_PERIOD_MILLI = 250,
    AM_SERIALMSG = 0x89,
    ACTIVE_PERIOD_MILLI = 2000
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
    ux_uint8_t deleted;
    nx_struct DetectedNode* next;
} DetectedNode;

typedef nx_struct NeighborNode {
    nx_uint16_t nodeid;
    nx_float reliability;
    nx_uint8_t deleted;
    nx_struct NeighborNode* next;
} NeighborNode;

typedef nx_struct NeighborTableMsg {
    nx_uint16_t nodeid;
    nx_float reliability;
    nx_uint8 eof;
} NeighborTableMsg;

typedef nx_struct SerialRequestMsg {
    nx_uint16 nodeid;
} SerialRequestMsg;

#endif
