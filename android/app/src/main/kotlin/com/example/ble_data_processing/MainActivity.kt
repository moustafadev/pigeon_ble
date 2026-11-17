package com.example.ble_data_processing

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    val messenger = flutterEngine.dartExecutor.binaryMessenger

    val events = BleEventsHandler()
    BleEventsStreamHandler.register(messenger, events)
    BleHostApi.setUp(messenger, BleHostApiImpl(events))
  }
}