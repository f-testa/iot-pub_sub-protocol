/**
 *  This header file contains the definitions of application parameters (such as maximum number of nodes,
 *  the values of the timers,...) and the structure of the exchanged messages and the related
 *  message types and topic names.
 */

#ifndef DEFINITIONS_H
#define DEFINITIONS_H

// 1 debug mode on, 0 debug mode off
#define DEBUG               1

//1 for static assignment of topics and qos levels subscription, 0 for random values
#define STATIC_ASSIGNMENT   1

#define MAX_NODES       8
#define BROKER_ADDRESS  1
#define TOPIC_COUNT     3
#define QOS_LEVEL_COUNT 2

#define CONN_RETRY      2000
#define SUB_RETRY       2000
#define SAMPLE_DELAY    30000
#define RETR_DELAY      300
#define PUBACK_DELAY    1500

#define NODE_OFFSET     2

#define TOPIC_NAME_LENGTH 4

#define RETR_QUEUE_SIZE   250
#define HANDLE_QUEUE_SIZE 10

/** MESSAGE STRUCTURE AND TYPES **/
typedef enum {
    CONN, CONNACK,
    SUB,  SUBACK,
    PUB,  PUBACK,
} msg_type_t;

typedef nx_struct {

    nx_bool topic[TOPIC_COUNT];
    nx_bool qos[TOPIC_COUNT];
    
} sub_payload_t;

typedef nx_struct {

    nx_uint8_t topic_id;
    nx_bool qos;
    nx_uint8_t data;
    
} pub_payload_t;

typedef nx_struct {

    nx_uint8_t node_id;
    nx_uint8_t msg_type;
	nx_union {
	    sub_payload_t sub_payload;
	    pub_payload_t pub_payload;
	} msg_payload;
	
} msg_t;
 
typedef nx_struct {

    nx_uint8_t dest_node_id;
    msg_t msg;
	
} retr_msg_t;

/** TOPICS **/
typedef enum {
    TEMPERATURE = 0,
    LUMINOSITY  = 1,
    HUMIDITY    = 2,
} topic_t;

char topic_name[TOPIC_COUNT][TOPIC_NAME_LENGTH+1]={"TEMP\0", "LUMI\0", "HUMI\0"};

enum{
    AM_MY_MSG = 6,
};

#endif
