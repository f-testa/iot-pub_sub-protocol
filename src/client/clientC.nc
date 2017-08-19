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
        interface Random;
    }

} implementation {

    //*** Variables declaration ***//
    bool is_connected = 0;
    bool is_sub = 0;
    bool pending_puback = 0;
    uint8_t last_data;
    
    //subscription info
    bool sub_topic[TOPIC_COUNT] = {1,1,1}; 
    bool sub_qos[TOPIC_COUNT] = {1,0,1};
    
    //publish info
    char str [((TOPIC_NAME_LENGTH+2)*TOPIC_COUNT+(TOPIC_COUNT-1))];
    uint8_t pub_topic_id;
    bool pub_qos;
    
    message_t packet;

    //*** Tasks declaration ***//
    task void sendConn();
    task void sendSub();
    task void retrPub();

    //*** Functions declaration ***//
    void printSubscription();
    
    /**
    * This function prepares a simple string which contains the list of topics
    * and relative QoS level that the client will subscribe to once connected to the Broker
    */
    void printSubscription(){
        uint8_t i;
        char src [TOPIC_NAME_LENGTH+2];

        for(i=0; i<TOPIC_COUNT; i++){
            if(sub_topic[i]){
                sprintf(src, "%s:%d ", topic_name[i],sub_qos[i]);
                strcat(str, src);
            }
        }
    }

    /**
    * This function is used to set the topic identifier and the QoS level on which
    * the client will publish the data received from the fake sensor.
    * Please notice that a client node can publish only on a SINGLE topic.
    */
    void setPublishInfo(){
        pub_topic_id = TOS_NODE_ID % TOPIC_COUNT;
        pub_qos = TOS_NODE_ID % QOS_LEVEL_COUNT;
        printf("[Client %d] Will Publish on Topic %s, with QoS %d\n", TOS_NODE_ID, topic_name[pub_topic_id], pub_qos);
    }
    
    /**
    * This function sets the topic identifiers and the related QoS levels to which the node will subscribe.
    * If the STATIC_ASSIGNMENT flag is set, the assignment of the subcriptions is static and constant (for testing purposes) 
    * otherwise the assignment is dynamic and random (thus ensuring a more realistic scenario).
    */
    void setSubInfo(){
        uint8_t i;
        
        if(STATIC_ASSIGNMENT){
            //do not overwrite static assignment of topics and QoS
        } else {
            //overwrite static assignments with dynamic and randon ones
            for(i=0; i<TOPIC_COUNT; i++){
                sub_topic[i] = call Random.rand16() % 2;
                sub_qos[i] = call Random.rand16() % QOS_LEVEL_COUNT;
                if(sub_topic[i])
                    printf("[Client %d] SUB to Topic:%s -> QoS:%d\n", TOS_NODE_ID, topic_name[i], sub_qos[i]);
            }
        }
    }

    //****************** Task sendConn *****************//
    /**
    * The task is responsible for sending the CONN msg to the Broker and
    * it will display a message on the output console with the outcome of this
    * operation.
    */
    task void sendConn(){
        msg_t* mess=(msg_t*)(call Packet.getPayload(&packet,sizeof(msg_t)));
        mess -> msg_type = CONN;
        mess -> node_id = TOS_NODE_ID;

        printf("[Client %d] Try to send CONN to Broker\n", TOS_NODE_ID);
        if(call AMSend.send(BROKER_ADDRESS,&packet,sizeof(msg_t)) == SUCCESS){
            printf("[Client %d] CONN msg passed to lower level\n",TOS_NODE_ID);
        } else
            printf("[Client %d] *** ERROR: CONN msg not passed to lower level ***\n",TOS_NODE_ID);
    }


    //****************** Task sendSub *****************//
    /**
    * It will send to the Broker a SUB message and its payload holds the 
    * subscription info (that is chosen topic and related QoS level).
    * Then it will display a message with the operation outcome (success or fail).
    */
    task void sendSub(){
        uint8_t i;
        msg_t* mess=(msg_t*)(call Packet.getPayload(&packet,sizeof(msg_t)));
        mess->msg_type = SUB;
        mess->node_id = TOS_NODE_ID;

        for(i=0; i<TOPIC_COUNT; i++){
            mess->msg_payload.sub_payload.topic[i] = sub_topic[i];
            mess->msg_payload.sub_payload.qos[i] = sub_qos[i];
        }

        printf("[Client %d] Try to SUB with <Topic:QoS> as follows: %s\n", TOS_NODE_ID, str);
        if(call AMSend.send(BROKER_ADDRESS,&packet,sizeof(msg_t)) == SUCCESS){
            printf("[Client %d] SUB msg passed to lower level\n",TOS_NODE_ID);
        } else
            printf("[Client %d] *** ERROR: SUB msg not passed to lower level ***\n",TOS_NODE_ID);
    }
    
    //****************** Task retrPub *****************//
    /**
    * This task is called every time a PUBACK is not received in the PUB timeout interval;
    * then, it resends a PUB message to the Broker with the latest data obtained from the sensor
    * and prints a message on the console. 
    * If the QoS of PUB is equal to 1, it also sets a flag that signals a PUBACK is expected and 
    * finally starts the timer.  
    */
    task void retrPub(){
        uint8_t err_code;
        msg_t* mess=(msg_t*)(call Packet.getPayload(&packet,sizeof(msg_t)));
        mess->msg_type = PUB;
        mess->node_id = TOS_NODE_ID;
        mess->msg_payload.pub_payload.topic_id = pub_topic_id;
        mess->msg_payload.pub_payload.qos = pub_qos;
        mess->msg_payload.pub_payload.data = last_data;
        printf("[Client %d] Resending PUB after PUBACK timeout\n", TOS_NODE_ID);
        
        err_code = call AMSend.send(BROKER_ADDRESS,&packet,sizeof(msg_t));
        if(err_code == SUCCESS){
            printf("[Client %d] PUB msg passed to lower layer; topic: %s, value: %u\n",TOS_NODE_ID, topic_name[pub_topic_id], last_data);
            if (pub_qos){
                pending_puback = 1; // set pending flag
                call ConnTimer.startOneShot(PUBACK_DELAY);
            }
        } else
            printf("[Client %d] *** ERROR: impossible to send PUB msg ***\n", TOS_NODE_ID);
    }   

    //***************** Boot interface ********************//
    event void Boot.booted() {
        printf("[Client %d] Application booted\n", TOS_NODE_ID);
        printfflush();
        call SplitControl.start();
    }


    //***************** SplitControl interface ********************//
    /** 
    * Once the radio module is on, the client node calls the functions
    * that will set the info about publishing and subscribing.
    * Also a simple check is done on the identifier of the node to preserve
    * the correct behavior of the system.
    */
    event void SplitControl.startDone(error_t err){

        if(err == SUCCESS) {
            printf("[Client %d] Radio on\n", TOS_NODE_ID);
            if ( TOS_NODE_ID > 1 ) {
                setSubInfo();
                setPublishInfo();
                call ConnTimer.startPeriodic( CONN_RETRY );
                post sendConn();
            } else {
                printf("[Client %d] *** ERROR: wrong node identifier ***\n",TOS_NODE_ID);
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
    * The called task depends on the value of is_connected, is_sub and pending_puback flags:
    * accordingly to their values, a proper task for connection, subscription or retransmission
    * of a PUB message is posted.
    */
    event void ConnTimer.fired() {
        if(!is_connected & !is_sub & !pending_puback){
            printf("[Client %d] CONN Timeout\n", TOS_NODE_ID);
            post sendConn();
        } else if(is_connected & !is_sub & !pending_puback) {
            printf("[Client %d] SUB Timeout\n", TOS_NODE_ID);
            post sendSub();
        } else if(is_connected & is_sub & pending_puback){
            printf("[Client %d] PUBACK Timeout, try to resend PUB msg\n", TOS_NODE_ID);
            post retrPub();
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
        } else
            printf("[Client %d] *** ERROR, msg not sent ***\n", TOS_NODE_ID);
    }

    //************************** Receive interface ********************//
    /**
    * According to the received message type, the node will execute all the necessary actions;
    * in case of unexpected message, a warning will be printed on the output console.
    */
    event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {

        msg_t* mess=(msg_t*)payload;

        // React accordingly to the received message type
        switch(mess->msg_type){

            /*
            * Once the node is correctly connected to the Broker, it can send the following
            * SUB message but it can also start sampling data from the attached fake sensor.
            */
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
                call ConnTimer.stop();
                printf("[Client %d] SUBACK received, succesfully subscribed\n", TOS_NODE_ID);
                is_sub = 1; // now the cliet node is correctly subscribed
                break;

            case PUB:
                printf("[Client %d] PUB received from node: %d, topic: %s data: %d\n", TOS_NODE_ID, mess->node_id, topic_name[mess->msg_payload.pub_payload.topic_id], mess->msg_payload.pub_payload.data);
                break;

            case PUBACK:
                printf("[Client %d] PUBACK received\n", TOS_NODE_ID);
                pending_puback = 0; //clear pending flag
                break;

            default:
                printf("[Client %d] *** ERROR: received unexpected msg type (%d) ***\n", TOS_NODE_ID, mess->msg_type);
        };

        return buf;
    }

    //************************* Read interface **********************//
    /**
    * When the Sampling timer expires, the read command is launched and this event is
    * notified: the node prepares and sends a PUB message to the Broker with the data just read.
    * If the sending operation is succesfull, a proper flag is asserted and the timer for the PUBACK
    * reception is started.
    */
    event void Read.readDone(error_t result, uint8_t data) {

        msg_t* mess=(msg_t*)(call Packet.getPayload(&packet,sizeof(msg_t)));
        //prepare PUB msg to send
        mess->msg_type = PUB;
        mess->node_id = TOS_NODE_ID;
        mess->msg_payload.pub_payload.topic_id = pub_topic_id;
        mess->msg_payload.pub_payload.qos = pub_qos;
        mess->msg_payload.pub_payload.data = data;
        
        //save last data read from the fake sensor
        last_data = data;

        if(call AMSend.send(BROKER_ADDRESS,&packet,sizeof(msg_t)) == SUCCESS){
            printf("[Client %d] PUB msg passed to lower layer; topic: %s, value: %u\n",TOS_NODE_ID, topic_name[pub_topic_id], data);
            if (pub_qos){
                pending_puback = 1; // set pending flag
                call ConnTimer.startOneShot(PUBACK_DELAY);
            }
        } else
            printf("[Client %d] *** ERROR: impossible to send PUB msg ***\n", TOS_NODE_ID);
    }
}
