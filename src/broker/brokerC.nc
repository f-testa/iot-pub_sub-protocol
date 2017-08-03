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
        // TODO qos data structure
        // TODO pkt queue
    }

} implementation {

    //*** Variables declaration ***//
    message_t packet; 

    //*** Tasks declaration ***//
    task void sendReq();
    task void sendResp();
    
    //*** Function declaration ***//
    void manageConn(uint8_t node_id);
    void manageSub(sub_payload_t sub_pl);
    
    
    //***************** Task send request ********************//
    task void sendReq() {

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

    }        

    //****************** Task send response *****************//
    task void sendResp() {
        //call Read.read();
    }
    
    /**
    * TODO
    */
    void manageConn(uint8_t node_id){
        msg_t* mess = (msg_t*)(call Packet.getPayload(&packet,sizeof(msg_t)));
        mess -> msg_type = CONNACK;
        
        //check on max number of clients
        if(node_id > MAX_NODES+1){
            printf("[Broker] WARNING: maximum number of connected clients reached\n");
            return;
        }
        
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
    void manageSub(sub_payload_t sub_payload){
        //msg_t* mess = (msg_t*)(call Packet.getPayload(&packet,sizeof(msg_t)));
        int i;
        
        for(i=0; i<TOPIC_COUNT; i++){
            // TODO
        }
        
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

        //printf("Message received at time %s \n", sim_time_string());
        /*printf(">>>Pack \n \t Payload length %hhu \n", call Packet.payloadLength( buf ) );
        printf("\t Source: %d \n", call AMPacket.source( buf ) );
        printf("\t Destination: %d \n", call AMPacket.destination( buf ) );
        printf("\t AM Type: %hhu \n", call AMPacket.type( buf ) );
        printf("\t\t Payload \n" );
        printf("\t\t msg_type: %hhu \n", mess->msg_type);
        printf("\t\t node_id: %d \n", mess->node_id);
        printf("\t\t value: %hhu \n", mess->value);*/

        // React accordingly to the received message type
        switch(mess->msg_type){
        
            case CONN:
                manageConn(mess->node_id);
                break;
                
            case SUB:
                //manageSub(mess->msg_payload.sub_payload);
                break;
                
            case PUB:
                // TODO
                break;
                
            case PUBACK:
                // TODO
                break;
                
            default:
                //TODO
        };

        return buf;

    }
    
}

