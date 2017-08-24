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
        interface Queue<retr_msg_t> as RetrQueue;
        interface Queue<msg_t> as HandleQueue;
    }

} implementation {

    //*** Variables declaration ***//
    message_t packet;
    message_t packet_i;
    
    //Data for subscription management
    bool topic_sub [MAX_NODES][TOPIC_COUNT];
    bool qos_sub [MAX_NODES][TOPIC_COUNT];

    //*** Tasks declaration ***//
    task void handleMsg();
    task void retrMsg();

    //*** Function declaration ***//
    void manageConn(uint8_t node_id);
    void manageSub(uint8_t node_id, sub_payload_t sub_pl);

    /**
    * Support function that simply prints on the console the current status
    * of the subscriptions of the client nodes (topic names and relative QoS levels).
    */
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

    /**
    * This task is in charge of managing the received PUB messages from the client nodes: for each PUB message received, it
    * has to prepare a new message that, later, will be forwarded to every subscribed node. In order to do this, the Broker
    * node uses a different queue (namely retrQueue) where message ready to be sent are enqueued, while if this queue is full 
    * messages are simply discarded.
    * Lastly, the task itself is reposted again if there are received PUB still to read and manage. 
    */
    task void handleMsg(){
        uint8_t id;
        retr_msg_t retr_msg;
        msg_t msg_temp;
        
        if(call HandleQueue.empty()){
            printf("[Broker] *** ERROR: Handling queue empty ***\n");
            return;
        }
        msg_temp = call HandleQueue.dequeue();
  
        for(id=2; id<MAX_NODES+NODE_OFFSET; id++){
            if(topic_sub[id-NODE_OFFSET][msg_temp.msg_payload.pub_payload.topic_id]){
                
                retr_msg.dest_node_id = id;
                retr_msg.msg = msg_temp;
                
                //store QoS level of the destination node
                retr_msg.msg.msg_payload.pub_payload.qos = qos_sub[id-NODE_OFFSET][msg_temp.msg_payload.pub_payload.topic_id];
                
                if(call RetrQueue.size() < call RetrQueue.maxSize())
                    call RetrQueue.enqueue(retr_msg);
                else
                    printf("[Broker] *** WARNING: Retransmission queue full, msg discarded ***\n");
            }
        }

        printf("[Broker] Messages about PUB from node %d have been enqueued\n",msg_temp.node_id);
        //if the handling queue is not empty (i.e. more messages still to read), the task is reposted
        if(!call HandleQueue.empty())
            post handleMsg();
        else
            if(DEBUG)
                printf("[Broker] Handling Queue empty\n");

    }
    
    /**
    * This task is used for dequeuing and sending (already preparead) PUB messages to client nodes;
    * according to the QoS level, a synchronous ACK can be requested to the destination node.
    */
    task void retrMsg(){
        uint8_t err_code;
        
        //dequeue and prepare msg to send
        retr_msg_t msg_temp = call RetrQueue.dequeue();
        msg_t* msg = (msg_t*)(call Packet.getPayload(&packet_i,sizeof(msg_t)));
        msg -> msg_type = msg_temp.msg.msg_type;
        msg -> node_id = msg_temp.msg.node_id;
        msg -> msg_payload = msg_temp.msg.msg_payload;
        
        printf("[Broker] Sending PUB (source node: %d, topic: %s, data: %d) to node %d\n", msg_temp.msg.node_id, topic_name[msg_temp.msg.msg_payload.pub_payload.topic_id], msg_temp.msg.msg_payload.pub_payload.data, msg_temp.dest_node_id);
        
        //sync ack on sending packet is requested or not depending on the subscription info of 
        //the receiver node, which is stored in the proper message field
        if(qos_sub[msg_temp.msg.node_id-NODE_OFFSET][msg_temp.msg.msg_payload.pub_payload.topic_id])
            call PacketAcknowledgements.requestAck( &packet_i );
        else
            call PacketAcknowledgements.noAck( &packet_i );
            
        err_code = call AMSend.send(msg_temp.dest_node_id,&packet_i,sizeof(msg_t));
        if(err_code == SUCCESS){
            printf("[Broker] PUB msg passed to lower level\n");
        }else
            printf("[Broker] *** ERROR %d: PUB msg not passed to lower level ***\n", err_code);        
    }

    /**
    * Called upon reception of a CONN message, this function registers the newly connected node,
    * if the maximum number of clients hasn't been reached yet, and send back to it a CONNACK message.
    */
    void manageConn(uint8_t node_id){
        uint8_t err_code;
        msg_t* msg = (msg_t*)(call Packet.getPayload(&packet,sizeof(msg_t)));
        msg -> msg_type = CONNACK;

        printf("[Broker] Received CONN from node %d\n", node_id);

        //check on max number of clients
        if(node_id > MAX_NODES+1){
            printf("[Broker] WARNING: maximum number of connected clients reached\n");
            return;
        }

        //set node_id as active and connected
        if(!(call connected_nodes.get(node_id-NODE_OFFSET)))
            call connected_nodes.set(node_id-NODE_OFFSET);
        else
            printf("[Broker] *** ERROR: CONN already received from %d ***\n", node_id);

        //send back CONNACK
        printf("[Broker] Try to send back CONNACK to node %d\n", node_id);
        err_code = call AMSend.send(node_id,&packet,sizeof(msg_t));
        if(err_code == SUCCESS){
            printf("[Broker] CONNACK msg passed to lower level\n");
        }else
            printf("[Broker] *** ERROR %d: CONNACK msg not passed to lower level ***\n", err_code);
    }

    /**
    * For every SUB message received, this function is responsible for storing the preferences about topics and relative
    * QoS levels. After that, a SUBACK is sent back to the subscribing node.
    */
    void manageSub(uint8_t node_id, sub_payload_t sub_payload){
        uint8_t i;
        msg_t* msg = (msg_t*)(call Packet.getPayload(&packet,sizeof(msg_t)));
        msg -> msg_type = SUBACK;
        
        //check if node is connected
        if(!(call connected_nodes.get(node_id-NODE_OFFSET))){
            printf("[Broker] *** ERROR: node %d trying to subscribe but not yet connected\n", node_id);
            return;
        }   

        //store preferences on topic and QoS levels
        printf("[Broker] Received SUB from node %d\n", node_id);
        for(i=0; i<TOPIC_COUNT; i++){
            topic_sub[node_id-NODE_OFFSET][i] = sub_payload.topic[i];
            if(sub_payload.topic[i])
                qos_sub[node_id-NODE_OFFSET][i] = sub_payload.qos[i];
        }

        //print actual situation of subscription
        printSub();

        //send back SUBACK
        printf("[Broker] Try to send back SUBACK to node %d\n", node_id);
        i = call AMSend.send(node_id,&packet,sizeof(msg_t));
        if(i == SUCCESS){
            printf("[Broker] SUBACK msg passed to lower level\n");
        }
        else
            printf("[Broker] *** ERROR %d: SUBACK msg not passed to lower level ***\n", i);
    }

    /**
    * Every time a PUB message is received from a client node, this function sends back a PUBACK message (only if requested)
    * and enqueues in the handling queue, if not full, the received PUB message.
    * Finally, the task which will handle properly the publication message is posted. 
    */
    void managePub(uint8_t node_id, pub_payload_t pub_payload){
        uint8_t err_code;
        msg_t msg_temp;
        msg_t* msg = (msg_t*)(call Packet.getPayload(&packet,sizeof(msg_t)));
        msg -> msg_type = PUBACK;

        printf("[Broker] Received PUB from node %d\n", node_id);
        
        msg_temp.node_id = node_id;
        msg_temp.msg_type = PUB;
        msg_temp.msg_payload.pub_payload = pub_payload;

        // PUBACK msg sent back only if received QoS is 1
        if(pub_payload.qos){
            printf("[Broker] Try to send back PUBACK to node %d\n", node_id);
            err_code = call AMSend.send(node_id,&packet,sizeof(msg_t));
            if(err_code == SUCCESS){
                printf("[Broker] PUBACK msg passed to lower level\n");
            }
            else {
                printf("[Broker] *** ERROR %d: PUBACK msg not passed to lower level ***\n", err_code);
                return;
            }
        }
        
        if(call HandleQueue.size() < call HandleQueue.maxSize())
            call HandleQueue.enqueue(msg_temp);
        else
            printf("[Broker] *** WARNING: Handling queue full, msg discarded ***\n");
            
        post handleMsg();
        if(DEBUG)
            printf("[Broker] End PUB management from node %d\n", node_id);
    }

    //***************** Boot interface ********************//
    event void Boot.booted() {
        printf("[Broker] Application Booted\n");
        printfflush();
        call connected_nodes.clearAll(); //clear connected nodes status
        call SplitControl.start();
    }

    //***************** SplitControl interface ********************//
    /**
    * Once the radio module is on, the timer for message retransmission is activated.
    */
    event void SplitControl.startDone(error_t err){

        if(err == SUCCESS) {
            printf("[Broker] Radio on\n");
            if ( TOS_NODE_ID != 1 ) {
                printf("[Broker] ERROR: wrong node identifier\n");
            }
            call MilliTimer.startPeriodic(RETR_DELAY);
        } else {
            call SplitControl.start();
        }
    }

    event void SplitControl.stopDone(error_t err){
        //nothing to do here
    }

    //***************** MilliTimer interface ********************//
    /**
    * When the timer expires, if the retransmission queue is not emtpy
    * the post for message retransmission is posted.
    */
    event void MilliTimer.fired() {
        if(!(call RetrQueue.empty())){
            post retrMsg();
        } else
            if(DEBUG)
                printf("[Broker] Retransmission Queue empty\n");
    }


    //********************* AMSend interface ****************//
    /**
    * On message send done, a check is carried out to verify the outcome of the operation; 
    * in particular, a more complex verification is done on publish related messages.
    * Indeed, it is verified that if an ACK has been requested, it is actually received and in
    * case it is not received, the sent message is re-enqueued for retransmission.
    */
    event void AMSend.sendDone(message_t* buf,error_t err) {
        retr_msg_t retr_msg;
        msg_t* mess = call Packet.getPayload(&packet_i,sizeof(msg_t));
        
        //CONN,CONNACK,SUB,SUBACK messages check
        if(&packet == buf && err == SUCCESS ) {
            printf("[Broker] msg sent\n");
        } else if(&packet == buf && err != SUCCESS)
            printf("[Broker] *** ERROR: impossible to send message ***\n");
           
        //PUB related messages check 
        if(&packet_i == buf && err == SUCCESS ) {
            printf("[Broker] msg sent to node %d\n", call AMPacket.destination(buf));
            
            //check on syncACK on forwarded PUB message
            if (call PacketAcknowledgements.wasAcked(buf) && mess->msg_type == PUB && mess->msg_payload.pub_payload.qos) {
                printf("[Broker] msg ACK from node %d\n", call AMPacket.destination(buf));
            } else if (!(call PacketAcknowledgements.wasAcked(buf)) && mess->msg_type == PUB && mess->msg_payload.pub_payload.qos) {
                printf("[Broker] *** ERROR: msg NOT ACK, msg type %d, node %d ***\n",mess->msg_type, call AMPacket.destination(buf));
                //the msg is not acked from the dest node, then the msg is enqeueud again in the retransmission queue
                retr_msg.dest_node_id = call AMPacket.destination(buf);
                retr_msg.msg.node_id = mess->node_id;
                retr_msg.msg.msg_type = mess->msg_type;
                retr_msg.msg.msg_payload = mess->msg_payload;
                
                if(call RetrQueue.size() < call RetrQueue.maxSize()){
                    call RetrQueue.enqueue(retr_msg);
                    printf("[Broker] PUB msg to node %d re-enqueud for retransmission\n", retr_msg.dest_node_id);
                }
                else
                    printf("[Broker] *** WARNING: Retransmission queue full, msg discarded ***\n");
            }
        } else if(&packet_i == buf && err != SUCCESS)
            printf("[Broker] *** ERROR: impossible to send message ***\n");
    }

    //******************* Receive interface *****************//
    /**
    * Every time a new message is received, a proper function is called according
    * to the message type.
    */
    event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {

        msg_t* mess = (msg_t*)payload;

        // React accordingly to the received message type
        switch(mess->msg_type){

            case CONN:
                manageConn(mess->node_id);
                break;

            case SUB:
                manageSub(mess->node_id, mess->msg_payload.sub_payload);
                break;

            case PUB:
                managePub(mess->node_id, mess->msg_payload.pub_payload);
                break;

            default:
                printf("[Broker] ERROR: received unexpected msg type (%d)\n", mess->msg_type);
        };
        return buf;
    }
}
