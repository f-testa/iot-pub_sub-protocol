/**
 *  Configuration file of the Broker node. 
 *  Alongside all the requested component for packets and timer management,
 *  it also contains the components needed for the usage of printf function
 *  which is used for debugging purposes.
 */
 
#define NEW_PRINTF_SEMANTICS
#include "printf.h"
#include "definitions.h"

configuration brokerAppC {}

implementation {

    components MainC, brokerC as App;
    components new AMSenderC(AM_MY_MSG);
    components new AMReceiverC(AM_MY_MSG);
    components ActiveMessageC;
    components new TimerMilliC();
    components new BitVectorC(MAX_NODES);
    components SerialPrintfC;
    components SerialStartC;

    //Boot interface
    App.Boot -> MainC.Boot;

    //Send and Receive interfaces
    App.Receive -> AMReceiverC;
    App.AMSend -> AMSenderC;

    //Radio Control
    App.SplitControl -> ActiveMessageC;

    //Interfaces to access package fields
    App.AMPacket -> AMSenderC;
    App.Packet -> AMSenderC;
    App.PacketAcknowledgements->ActiveMessageC;

    //Timer interface
    App.MilliTimer -> TimerMilliC;

    //BitVector 
    App.connected_nodes -> BitVectorC;
}

