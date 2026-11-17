package com.example.ble_data_processing

import android.os.Handler
import android.os.Looper


class BleEventsHandler : BleEventsStreamHandler() {
  private var sink: PigeonEventSink<BleEvent>? = null
  private val main = Handler(Looper.getMainLooper())

  override fun onListen(p0: Any?, sink: PigeonEventSink<BleEvent>) {
    this.sink = sink
  }

  override fun onCancel(p0: Any?) {
    sink = null
  }

  fun emit(event: BleEvent) {
    main.post { sink?.success(event) }
  }
}