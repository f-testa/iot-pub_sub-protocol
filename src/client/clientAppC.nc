/**
 *  Configuration file for the Client node.
 *  Alongside all the requested component for packets and timer management,
 *  it also contains the components needed for the usage of printf function
 *  which is used for debugging purposes.
 */
#define NEW_PRINTF_SEMANTICS
#include "printf.h"
#include "definitions.h"

configuration clientAppC {}

implementation {

    components MainC, clientC as App;
    components new AMSenderC(AM_MY_MSG);
    components new AMReceiverC(AM_MY_MSG);
    components ActiveMessageC;
    components new TimerMilliC() as CTimer;
    components new TimerMilliC() as STimer;
    components new FakeSensorC();
    components SerialPrintfC;
    components SerialStartC;
    components RandomC;

    //Boot interface
    App.Boot -> MainC.Boot;

    //Send and Receive interfaces
    App.Receive -> AMReceiverC;
    App.AMSend  -> AMSenderC;

    //Radio Control
    App.SplitControl -> ActiveMessageC;

    //Interfaces to access package fields
    App.AMPacket -> AMSenderC;
    App.Packet   -> AMSenderC;
    App.PacketAcknowledgements -> ActiveMessageC;

    //Timer interface
    App.ConnTimer   -> CTimer;
    App.SampleTimer -> STimer;
    
    //Fake Sensor read
    App.Read -> FakeSensorC;
    
    //Random
    App.Random -> RandomC;
	RandomC <- MainC.SoftwareInit;

}

