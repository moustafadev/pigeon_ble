import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/pigeon/connect_ble/ble_event.g.dart',
    kotlinOut: 'android/app/src/main/kotlin/com/example/ble_data_processing/BleEvent.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.example.ble_data_processing'),
    swiftOut: 'ios/Runner/BleEvent.g.swift',
    dartPackageName: 'ble_data_processing',
  ),
)
enum ConnectionState { disconnected, connecting, connected }

class BleDevice {
  BleDevice({required this.id, required this.rssi});
  String id;
  String? name;
  int rssi;
}

sealed class BleEvent {}

class DeviceFound extends BleEvent {
  DeviceFound(this.device);
  BleDevice device;
}

class StateChanged extends BleEvent {
  StateChanged(this.state);
  ConnectionState state;
}

class DataReceived extends BleEvent {
  DataReceived(this.bytes);
  Uint8List bytes;
}

@HostApi()
abstract class BleHostApi {
  void startScan();
  void stopScan();

  @async
  void connect(String deviceId);

  @async
  void disconnect();

  @async
  void write(Uint8List bytes);

  @async
  Uint8List heavyProcess(Uint8List input);
}

@EventChannelApi()
abstract class BleEvents {
  BleEvent bleEvents();
}
