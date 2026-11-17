import 'dart:async';

import 'package:ble_data_processing/core/pigeon/connect_ble/ble_event.g.dart';
import 'package:ble_data_processing/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;

void main() {
  testWidgets('adds a discovered device and connects', (tester) async {
    final events = StreamController<BleEvent>.broadcast();
    final api = _FakeBleHostApi();
    addTearDown(events.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BleHomePage(api: api, events: events.stream, autoStart: false),
      ),
    );

    expect(find.text('No devices yet'), findsOneWidget);

    events.add(
      DeviceFound(
        device: BleDevice(id: '00:11:22', name: 'Test sensor', rssi: -50),
      ),
    );
    await tester.pump();

    expect(find.text('Test sensor'), findsOneWidget);
    expect(find.text('00:11:22'), findsOneWidget);
    expect(find.text('RSSI -50'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pump();

    expect(api.connectedId, '00:11:22');
    expect(find.text('Connecting to Test sensor'), findsOneWidget);

    events.add(StateChanged(state: ConnectionState.connected));
    await tester.pump();

    expect(find.text('Connected to Test sensor'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Disconnect'));
    await tester.pump();
    expect(api.disconnects, 1);

    events.add(StateChanged(state: ConnectionState.disconnected));
    await tester.pump();

    expect(find.text('Connected to Test sensor'), findsNothing);
    expect(find.text('Connected'), findsNothing);
  });

  testWidgets('start scan asks the host to scan', (tester) async {
    final events = StreamController<BleEvent>.broadcast();
    final api = _FakeBleHostApi();
    addTearDown(events.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BleHomePage(api: api, events: events.stream, autoStart: false),
      ),
    );

    await tester.tap(find.byTooltip('Start scan'));
    await tester.pump();

    expect(api.scans, 1);
    expect(find.byTooltip('Stop scan'), findsOneWidget);
  });
}

class _FakeBleHostApi extends BleHostApi {
  String? connectedId;
  int scans = 0;
  int disconnects = 0;

  @override
  Future<void> startScan() async {
    scans++;
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(String deviceId) async {
    connectedId = deviceId;
  }

  @override
  Future<void> disconnect() async {
    disconnects++;
    connectedId = null;
  }
}
