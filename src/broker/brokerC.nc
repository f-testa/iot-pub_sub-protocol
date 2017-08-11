/**
 *  This is the implementation of the Broker (i.e. PAN coordinator) component of the application.
 */

#include "definitions.h"
#include "Timer.h"
#include "printf.h"

module brokerC {

    uses {
        interface Boot;
        interface AMPacket;
        interface Packet;
        interface PacketAcknowledgements;
        interface AMSend;
        interface SplitControl;
        interface Receive;
        interface Timer<TMilli> as MilliTimer;
        interface BitVector as connected_nodes;
        // topic qos
        // TODO pkt queue
    }

} implementation {

    //*** Variables declaration ***//
    message_t packet;
    bool topic_sub [MAX_NODES][TOPIC_COUNT]; 
    bool qos_sub [MAX_NODES][TOPIC_COUNT]; 

    //*** Tasks declaration ***//
    //task void sendReq();
    
    //*** Function declaration ***//
    void manageConn(uint8_t node_id);
    void manageSub(uint8_t node_id, sub_payload_t sub_pl);
    
    // TODO
    void printSub(){
        uint8_t i=0,j;
        printf("-----------------------------------------\n");
        printf("|  Node ID    | ");
        for(i=0; i<MAX_NODES; i++){
                printf("%d  ", i+2);
        }
        printf("|\n");
        printf("-----------------------------------------\n");
        for(j=0; j<TOPIC_COUNT; j++){   
            printf("|  Topic %s | ", topic_name[j]);
            for(i=0; i<MAX_NODES; i++){
                printf("%d  ", topic_sub[i][j]);
            }
            printf("|\n");
            printf("|  QoS        | ");
            for(i=0; i<MAX_NODES; i++){
                printf("%d  ", qos_sub[i][j]);
            }
            printf("|\n");
            printf("-----------------------------------------\n");
        }
    }
    
    
    //***************** Task send request ********************//
    //task void sendReq() {

        /*msg_t* mess=(msg_t*)(call Packet.getPayload(&packet,sizeof(msg_t)));
        mess->msg_type = REQ;

        dbg("radio_send", "Try to send a request to node 2 at time %s \n", sim_time_string());

        call PacketAcknowledgements.requestAck( &packet );

        if(call AMSend.send(2,&packet,sizeof(msg_t)) == SUCCESS){

            dbg("radio_send", "Packet passed to lower layer successfully!\n");
            dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
            dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
            dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
            dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
            dbg_clear("radio_pack","\t\t Payload \n" );
            dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
            dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
            dbg_clear("radio_pack", "\t\t value: %hhu \n", mess->value);
            dbg_clear("radio_send", "\n ");
            dbg_clear("radio_pack", "\n");

        }*/

    //}
    
    /**
    * TODO
    */
    void manageConn(uint8_t node_id){
        msg_t* msg = (msg_t*)(call Packet.getPayload(&packet,sizeof(msg_t)));
        msg -> msg_type = CONNACK;
        
        //check on max number of clients
        if(node_id > MAX_NODES+1){
            printf("[Broker] WARNING: maximum number of connected clients reached\n");
            return;
        }
        
        //set node_id as active and connected
        call connected_nodes.set(node_id-NODE_OFFSET);
        
        printf("[Broker] Received CONN from node %d\n", node_id);
       
        printf("[Broker] Try to send back CONNACK to node %d\n", node_id);
        if(call AMSend.send(node_id,&packet,sizeof(msg_t)) == SUCCESS){
            printf("[Broker] CONNACK msg passed to lower level %d\n", node_id);
        }
    }
    
    /**
    TODO
    */
    void manageSub(uint8_t node_id, sub_payload_t sub_payload){
        uint8_t i;
        msg_t* msg = (msg_t*)(call Packet.getPayload(&packet,sizeof(msg_t)));
        msg -> msg_type = SUBACK;
        
        printf("[Broker] Received SUB from node %d\n", node_id);            
        for(i=0; i<TOPIC_COUNT; i++){
            topic_sub[node_id-NODE_OFFSET][i] = sub_payload.topic[i];
            if(sub_payload.topic[i])
                qos_sub[node_id-NODE_OFFSET][i] = sub_payload.qos[i];
        }
    
        printSub();
        
        printf("[Broker] Try to send back SUBACK to node %d\n", node_id);
        i = call AMSend.send(node_id,&packet,sizeof(msg_t));
        if(i == SUCCESS){
            printf("[Broker] SUBACK msg passed to lower level\n");
        }
        else
            printf("[Broker] *** ERROR, SUBACK msg not passed to lower level (error code: %d) ***\n", i);       
    }

    //***************** Boot interface ********************//
    event void Boot.booted() {
        printf("[Broker] Application Booted\n");
        printfflush();
        call connected_nodes.clearAll();
        call SplitControl.start();
    }

    //***************** SplitControl interface ********************//
    event void SplitControl.startDone(error_t err){

        if(err == SUCCESS) {
            printf("[Broker] Radio on\n");
            if ( TOS_NODE_ID != 1 ) {
                printf("[Broker] ERROR: wrong node identifier\n");
            }
        } else {
            call SplitControl.start();
        }
    }

    event void SplitControl.stopDone(error_t err){
        //nothing to do here
    }

    //***************** MilliTimer interface ********************//
    event void MilliTimer.fired() {
        //TODO
    }


    //********************* AMSend interface ****************//
    event void AMSend.sendDone(message_t* buf,error_t err) {

        if(&packet == buf && err == SUCCESS ) {
            printf("[Broker] msg sent\n");
            
            /*if ( call PacketAcknowledgements.wasAcked( buf ) ) {
                dbg_clear("radio_ack", "and ack received");
                //call MilliTimer.stop();
            } else {
                dbg_clear("radio_ack", "but ack was not received");
                //post sendReq();
            }*/
        }
    }

    //******************* Receive interface *****************//
    event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {

        msg_t* mess = (msg_t*)payload;

        // React accordingly to the received message type
        switch(mess->msg_type){
        
            case CONN:
                //printf("%d\n",mess->node_id);
                manageConn(mess->node_id);
                break;
                
            case SUB:
                manageSub(mess->node_id, mess->msg_payload.sub_payload);
                break;
                
            case PUB:
                // TODO
                break;
                
            case PUBACK:
                // TODO
                break;
                
            default:
                printf("[Broker] ERROR: received message with a wrong type identifier\n");
        };
        return buf;
    }
    
}

