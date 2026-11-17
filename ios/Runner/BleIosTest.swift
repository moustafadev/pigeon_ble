import Flutter
import Foundation


final class BleEventsHandler: BleEventsStreamHandler {
  private var sink: PigeonEventSink<BleEvent>?

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<BleEvent>) {
    self.sink = sink
  }

  override func onCancel(withArguments arguments: Any?) {
    sink = nil
  }

  /// Safe to call from any thread: the actual send happens on the main thread.
  func emit(_ event: BleEvent) {
    DispatchQueue.main.async { [weak self] in
      self?.sink?.success(event)
    }
  }
}


final class BleHostApiImpl: BleHostApi {
  private let events: BleEventsHandler
  private var timer: Timer?

  init(events: BleEventsHandler) {
    self.events = events
  }

  func startScan() throws {
    events.emit(DeviceFound(device: BleDevice(id: "TEST-0001", name: "Test", rssi: -50)))
  }

  func stopScan() throws {}

  func connect(deviceId: String) async throws {
    events.emit(StateChanged(state: .connecting))

    try await Task.sleep(nanoseconds: 500_000_000)

    if deviceId == "FAIL" {
      events.emit(StateChanged(state: .disconnected))
      throw PigeonError(code: "CONNECT_FAILED", message: "Fake failure for testing", details: nil)
    }

    events.emit(StateChanged(state: .connected))
    startFakeData()
  }

  func disconnect() async throws {
    stopFakeData()
    events.emit(StateChanged(state: .disconnected))
  }

  func write(bytes: FlutterStandardTypedData) async throws {
    events.emit(DataReceived(bytes: bytes))
  }

  func heavyProcess(input: FlutterStandardTypedData) async throws -> FlutterStandardTypedData {
    return try await Task.detached(priority: .userInitiated) {
      // TODO: your heavy work goes here
      return input
    }.value
  }

  private func startFakeData() {
    DispatchQueue.main.async { [weak self] in
      self?.timer?.invalidate()
      self?.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        let bytes = (0..<1000).map { _ in UInt8.random(in: 0...255) }
        self?.events.emit(DataReceived(bytes: FlutterStandardTypedData(bytes: Data(bytes))))
      }
    }
  }

  private func stopFakeData() {
    DispatchQueue.main.async { [weak self] in
      self?.timer?.invalidate()
      self?.timer = nil
    }
  }
}
