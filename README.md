# Internet of Things Course
## *Politecnico di Milano, AY 2016-2017* 

Course project: implementation of a **lightweight publish-subscribe application protocol**

The project refers to the design and the implementation of a lightweight application protocol similar to MQTT.
The test phase will be carried out on a star-shaped network topology with 8 client nodes and a PAN coordinator (*broker*).

### Main features
  - Three supported topics: Temperature, Humidity and Luminosity
  - QoS management: level 0 (just one transmission), level 1 (continuos retransmission until ACK is received)
  - Connection phase: an initial CONNECT message which is followed by a CONNACK
  - Subscription phase: a SUBSCRIBE message, containing *node_id, topic and QoS_level*, followed by SUBACK
  - Publication phase: PUBLISH message with *topic, payload, QoS_level*, eventual PUBACK is sent only if QoS is set to 1

### Implementation
The project will be developed using TinyOS and will be tested in a proper simulation environment, such as TOSSIM or Cooja.
