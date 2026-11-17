# Pigeon BLE

A Flutter app that talks to Bluetooth through [Pigeon](https://pub.dev/packages/pigeon). The UI lists devices, connects to one, and follows connection state. Commands go out on a typed host API. Discoveries, state changes, and incoming bytes come back on a single event stream.

Android and iOS still ship stand-in hosts, so the screen and the channel can be exercised without a radio.

## The screen

Opening the app starts a scan. Devices show up as cards, strongest signal first, with a name, an id, and RSSI.

- **Start / stop** lives in the app bar. An empty scan shows the same actions in the body.
- **Connect** marks that device as connecting, then connected, and pins a status bar to the bottom.
- **Disconnect** returns the bar to idle once the host reports `disconnected`.
- A host error replaces the list with a message and a retry, or sits in a banner if devices are already on screen.

## The contract

Everything the UI is allowed to say lives in [`lib/core/pigeon/connect_ble/ble_event.dart`](lib/core/pigeon/connect_ble/ble_event.dart).

```text
Flutter
  BleHostApi     startScan · stopScan · connect · disconnect · write · heavyProcess
  BleEvents      DeviceFound · StateChanged · DataReceived
       │
       ▼
Android BleHostApiImpl          iOS BleHostApiImpl
```

| Type | Role |
| --- | --- |
| `BleDevice` | `id`, optional `name`, `rssi` |
| `ConnectionState` | `disconnected`, `connecting`, `connected` |
| `DeviceFound` | A device seen during scan |
| `StateChanged` | The active connection moved |
| `DataReceived` | Bytes from the peripheral |
| `write` | Bytes toward the peripheral |
| `heavyProcess` | A background pass over a byte buffer. Both hosts echo the input today |

Generated output is checked in:

- [`lib/core/pigeon/connect_ble/ble_event.g.dart`](lib/core/pigeon/connect_ble/ble_event.g.dart)
- [`android/app/src/main/kotlin/com/example/BleDataProcessing/BleEvent.g.kt`](android/app/src/main/kotlin/com/example/BleDataProcessing/BleEvent.g.kt)
- [`ios/Runner/BleEvent.g.swift`](ios/Runner/BleEvent.g.swift)

Each platform registers the handler in its Flutter entry point: [`MainActivity`](android/app/src/main/kotlin/com/example/ble_data_processing/MainActivity.kt) on Android and [`AppDelegate`](ios/Runner/AppDelegate.swift) on iOS.

## What the hosts do today

These are fakes so the scan screen has something to render. They do not open the Bluetooth radio.

**Android** ([`BleHostApiImpl.kt`](android/app/src/main/kotlin/com/example/ble_data_processing/BleHostApiImpl.kt)) emits one device (`Test`, RSSI −50) on `startScan`, then reports connected or disconnected.

**iOS** ([`BleIosTest.swift`](ios/Runner/BleIosTest.swift)) emits `TEST-0001`, waits half a second in `connecting`, then `connected`, and pushes a kilobyte of random bytes every second. `connect("FAIL")` drops back to `disconnected` and returns `CONNECT_FAILED`. `write` echoes the same bytes as `DataReceived`.

The screen listens for those events. It does not render `DataReceived` yet.

## Run it

Flutter is pinned to **3.50.0** in [`.fvmrc`](.fvmrc).

```bash
fvm install
fvm flutter pub get
fvm flutter run
```

Without FVM, any Flutter 3.50.x install works the same way: `flutter pub get`, then `flutter run`.

Widget tests drive the page with a fake host and a `Stream<BleEvent>`, so they do not need a device:

```bash
fvm flutter test
```

## Change the channel

Edit `ble_event.dart`, then regenerate. Do not hand-edit the `*.g.dart`, `*.g.kt`, or `*.g.swift` files.

```bash
fvm dart run pigeon --input lib/core/pigeon/connect_ble/ble_event.dart
```

## Layout

```text
lib/main.dart                                      scan screen
lib/core/pigeon/connect_ble/ble_event.dart         Pigeon schema
android/.../ble_data_processing/BleHostApiImpl.kt  Android host
android/.../ble_data_processing/MainActivity.kt    Android registration
ios/Runner/BleIosTest.swift                        iOS host
ios/Runner/AppDelegate.swift                       iOS registration
```

## Next

Swap each `BleHostApiImpl` for a real scanner and GATT client behind the same API. Bluetooth permissions are not declared yet, and `heavyProcess` is still an echo.
