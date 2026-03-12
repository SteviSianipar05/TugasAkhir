import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert';

class MqttService {
  final client = MqttServerClient('http://10.128.45.199:1880/mqtt_publish', '');

  Future<void> connect() async {
    client.port = 1883;
    client.logging(on: true);
    client.keepAlivePeriod = 20;

    try {
      await client.connect();
      print("MQTT Connected!");
    } catch (e) {
      print("MQTT ERROR: $e");
    }
  }

  void sendProfile(Map<String, dynamic> data) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(data));

    client.publishMessage(
      'iot/control/profile',
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }
}
