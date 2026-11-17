package com.example.ble_data_processing

import kotlin.random.Random
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class BleHostApiImpl(
  private val events: BleEventsHandler
) : BleHostApi {
  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
  private var dataJob: Job? = null

  override fun startScan() {
    events.emit(DeviceFound(BleDevice(id = "TEST-0001", name = "Test", rssi = -50)))
  }

  override fun stopScan() {}

  override suspend fun connect(deviceId: String) {
    events.emit(StateChanged(ConnectionState.CONNECTING))
    delay(500)

    if (deviceId == "FAIL") {
      events.emit(StateChanged(ConnectionState.DISCONNECTED))
      throw FlutterError("CONNECT_FAILED", "Fake failure for testing", null)
    }

    events.emit(StateChanged(ConnectionState.CONNECTED))
    startFakeData()
  }

  override suspend fun disconnect() {
    stopFakeData()
    events.emit(StateChanged(ConnectionState.DISCONNECTED))
  }

  override suspend fun write(bytes: ByteArray) {
    events.emit(DataReceived(bytes))
  }

  override suspend fun heavyProcess(input: ByteArray): ByteArray =
    withContext(Dispatchers.Default) {
      input
    }

  private fun startFakeData() {
    dataJob?.cancel()
    dataJob = scope.launch {
      while (isActive) {
        delay(1000)
        val bytes = ByteArray(1000) { Random.nextInt(256).toByte() }
        events.emit(DataReceived(bytes))
      }
    }
  }

  private fun stopFakeData() {
    dataJob?.cancel()
    dataJob = null
  }
}
