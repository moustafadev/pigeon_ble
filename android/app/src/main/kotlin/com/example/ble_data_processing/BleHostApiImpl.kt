package com.example.ble_data_processing

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class BleHostApiImpl(
  private val events: BleEventsHandler
) : BleHostApi {

  override fun startScan() {
    events.emit(DeviceFound(BleDevice(id = "00:11:22", name = "Test", rssi = -50)))
  }

  override fun stopScan() {}

  override suspend fun connect(deviceId: String) {
    events.emit(StateChanged(ConnectionState.CONNECTED))
  }

  override suspend fun disconnect() {
    events.emit(StateChanged(ConnectionState.DISCONNECTED))
  }

  override suspend fun write(bytes: ByteArray) {
  }

  override suspend fun heavyProcess(input: ByteArray): ByteArray =
    withContext(Dispatchers.Default) {
      input
    }
}