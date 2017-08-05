/**
 *  Implementation of the Client node.
 */

#include "definitions.h" 
#include "Timer.h"
#include "printf.h"

module clientC {

    uses {
        interface Boot;
        interface AMPacket;
        interface Packet;
        interface PacketAcknowledgements;
        interface AMSend;
        interface SplitControl;
        interface Receive;
        interface Timer<TMilli> as ConnTimer;
        interface Timer<TMilli> as SampleTimer;
        interface Read<uint8_t>;
    }

} implementation {

    //*** Variables declaration ***//
    bool is_connected = 0;
    bool qos[TOPIC_COUNT] = {1,0,0};
    bool sub_topic[TOPIC_COUNT] = {1,0,0};
    char str [((TOPIC_NAME_LENGTH+2)*TOPIC_COUNT+(TOPIC_COUNT-1))];
    message_t packet;
  
    //*** Tasks declaration ***//
    task void sendConn();
    task void sendSub();
    
    //*** Functions declaration ***//
    void printSubscription();
    
    /**
    * TODO
    */
    void printSubscription(){
        uint8_t i;
        char src [TOPIC_NAME_LENGTH+2];
        
        for(i=0; i<TOPIC_COUNT; i++){
            if(sub_topic[i]){
                sprintf(src, "%s:%d", topic_name[i],qos[i]);
                strcat(str, src);
            }
        }
    }

    //****************** Task send Connect *****************//
    task void sendConn(){
        msg_t* mess=(msg_t*)(call Packet.getPayload(&packet,sizeof(msg_t)));
        mess -> msg_type = CONN;
        mess -> node_id = TOS_NODE_ID;
        
        printf("[Client %d] Try to send CONN to Broker\n", TOS_NODE_ID);
        if(call AMSend.send(BROKER_ADDRESS,&packet,sizeof(msg_t)) == SUCCESS){
            printf("[Client %d] CONN msg passed to lower level\n",TOS_NODE_ID);
        }
    } 
    
    
    //****************** Task send Subscribe *****************//
    task void sendSub(){
        uint8_t i;
        msg_t* mess=(msg_t*)(call Packet.getPayload(&packet,sizeof(msg_t)));
        mess->msg_type = SUB;
        mess->node_id = TOS_NODE_ID;
        
        for(i=0; i<TOPIC_COUNT; i++){
            mess->msg_payload.sub_payload.topic[i] = sub_topic[i];
            mess->msg_payload.sub_payload.qos[i] = qos[i];
        }
        
        printf("[Client %d] Try to SUB with <Topic:QoS> as follows: %s\n", TOS_NODE_ID, str);
        if(call AMSend.send(BROKER_ADDRESS,&packet,sizeof(msg_t)) == SUCCESS){
            printf("[Client %d] SUB msg passed to lower level\n",TOS_NODE_ID);
        }
    }        


    //***************** Boot interface ********************//
    event void Boot.booted() {
        printf("[Client %d] Application booted\n", TOS_NODE_ID);
        printfflush();
        call SplitControl.start();
    }


    //***************** SplitControl interface ********************//
    event void SplitControl.startDone(error_t err){
      
        if(err == SUCCESS) {
            printf("[Client %d] Radio on\n", TOS_NODE_ID);
            if ( TOS_NODE_ID > 1 ) {
                // TODO decide qos+topic
                call ConnTimer.startPeriodic( CONN_RETRY );
                post sendConn();
            } else {
                printf("[Client %d] ERROR: wrong node identifier",TOS_NODE_ID);
            }
        } else {
            call SplitControl.start();
        }  
    }
  
    event void SplitControl.stopDone(error_t err){
        //nothing to do here
    }


    //***************** ConnTimer interface ********************//
    /**
    * The called task depends on the value of is_connected flag:
    * if the node is not yet connected to the broker, then the connection
    * task will be called, otherwise the called task refers to the 
    * subscription management.
    */
    event void ConnTimer.fired() {
        if(!is_connected){
            printf("[Client %d] CONN Timeout\n", TOS_NODE_ID);
            post sendConn();
        } else { 
            printf("[Client %d] SUB Timeout\n", TOS_NODE_ID);
            post sendSub();             
        }
    }
    
    //***************** SampleTimer interface ********************//
    event void SampleTimer.fired() {
        call Read.read();
    }
  

    //********************* AMSend interface ****************//
    event void AMSend.sendDone(message_t* buf,error_t err) {

        if(&packet == buf && err == SUCCESS ) {
            printf("[Client %d] msg sent\n", TOS_NODE_ID);

            /*if ( call PacketAcknowledgements.wasAcked( buf ) ) {
              dbg_clear("radio_ack", "and ack received");
              //call MilliTimer.stop();
            } else {
              dbg_clear("radio_ack", "but ack was not received");
              //post sendReq();
            }*/  
        }
    }

    //************************** Receive interface ********************//
    event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {

        msg_t* mess=(msg_t*)payload;
        
        // React accordingly to the received message type
        switch(mess->msg_type){
        
            case CONNACK:
                call ConnTimer.stop();
                printf("[Client %d] CONNACK received, succesfully connected to Broker\n", TOS_NODE_ID);
                is_connected = 1;
                printSubscription();
                post sendSub();
                call ConnTimer.startPeriodic( SUB_RETRY );
                call SampleTimer.startPeriodic( SAMPLE_DELAY );
                break;
                
            case SUBACK:
                printf("[Client %d] SUBACK received, succesfully subscribed\n", TOS_NODE_ID);
                call ConnTimer.stop();
                break;
                
            case PUB:
                // TODO
                break;
                
            case PUBACK:
                // TODO
                break;
                
            default:
                printf("[Client %d] ERROR: received message with a wrong type identifier\n", TOS_NODE_ID);
        };
        
        return buf;
    }
  
    //************************* Read interface **********************//
    event void Read.readDone(error_t result, uint8_t data) {

        msg_t* mess=(msg_t*)(call Packet.getPayload(&packet,sizeof(msg_t)));
        mess->msg_type = PUB;
        mess->node_id = TOS_NODE_ID;
        mess->msg_payload.pub_payload.data = data;
        //TODO topic qos field?
          
        //dbg("radio_send", "Try to send a response to node 1 at time %s \n", sim_time_string());
        //call PacketAcknowledgements.requestAck( &packet );
        if(call AMSend.send(BROKER_ADDRESS,&packet,sizeof(msg_t)) == SUCCESS){
            // TODO fix topic name
            printf("[Client %d] PUB msg passed to lower layer; topic: %s, value: %u\n",TOS_NODE_ID, topic_name[0], data); 
        }
    }
}

