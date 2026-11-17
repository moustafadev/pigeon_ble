import 'dart:async';

import 'package:ble_data_processing/core/pigeon/connect_ble/ble_event.g.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pigeon BLE',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const BleHomePage(),
    );
  }
}

class BleHomePage extends StatefulWidget {
  const BleHomePage({super.key, this.api, this.events, this.autoStart = true});

  final BleHostApi? api;
  final Stream<BleEvent>? events;
  final bool autoStart;

  @override
  State<BleHomePage> createState() => _BleHomePageState();
}

class _BleHomePageState extends State<BleHomePage> {
  final Map<String, BleDevice> _devices = {};

  late final BleHostApi _api;
  StreamSubscription<BleEvent>? _subscription;

  bool _scanning = false;
  ConnectionState _connection = ConnectionState.disconnected;
  String? _activeId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? BleHostApi();
    _scanning = widget.autoStart;
    _subscription = (widget.events ?? bleEvents()).listen(
      _onEvent,
      onError: _onStreamError,
    );
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_startScan());
      });
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    if (_scanning) {
      unawaited(_api.stopScan().then((_) {}, onError: (_, _) {}));
    }
    super.dispose();
  }

  void _onEvent(BleEvent event) {
    if (event is! DataReceived) {
      debugPrint('onEvent: $event');
    }
    if (!mounted) return;
    switch (event) {
      case DeviceFound(:final device):
        setState(() => _devices[device.id] = device);
      case StateChanged(:final state):
        setState(() {
          _connection = state;
          if (state == ConnectionState.disconnected) {
            _activeId = null;
          }
        });
      case DataReceived():
        break;
    }
  }

  void _onStreamError(Object error) {
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _error = _describe(error);
    });
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _error = null;
      _devices.clear();
    });
    try {
      await _api.startScan();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = _describe(error);
      });
    }
  }

  Future<void> _stopScan() async {
    try {
      await _api.stopScan();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _describe(error));
      return;
    }
    if (!mounted) return;
    setState(() => _scanning = false);
  }

  Future<void> _connect(String deviceId) async {
    setState(() {
      _activeId = deviceId;
      _connection = ConnectionState.connecting;
      _error = null;
    });
    try {
      await _api.connect(deviceId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connection = ConnectionState.disconnected;
        _activeId = null;
        _error = _describe(error);
      });
    }
  }

  Future<void> _disconnect() async {
    try {
      await _api.disconnect();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _describe(error));
    }
  }

  List<BleDevice> get _sortedDevices {
    final devices = _devices.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return devices;
  }

  @override
  Widget build(BuildContext context) {
    final devices = _sortedDevices;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Pigeon BLE'),
        actions: [
          if (_scanning)
            const Padding(
              padding: EdgeInsetsDirectional.only(end: 4),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            tooltip: _scanning ? 'Stop scan' : 'Start scan',
            onPressed: () {
              unawaited(_scanning ? _stopScan() : _startScan());
            },
            icon: Icon(_scanning ? Icons.stop : Icons.bluetooth_searching),
          ),
        ],
      ),
      body: devices.isEmpty
          ? _EmptyDevices(
              scanning: _scanning,
              error: _error,
              onStart: () => unawaited(_startScan()),
              onStop: () => unawaited(_stopScan()),
            )
          : Column(
              children: [
                if (_error != null)
                  _ErrorBanner(
                    message: _error!,
                    onRetry: () => unawaited(_startScan()),
                  ),
                Expanded(
                  child: _DeviceList(
                    devices: devices,
                    activeId: _activeId,
                    connection: _connection,
                    onConnect: (id) => unawaited(_connect(id)),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _connection == ConnectionState.disconnected
          ? null
          : _ConnectionBar(
              label: _statusLabel(),
              connection: _connection,
              onDisconnect: () => unawaited(_disconnect()),
            ),
    );
  }

  String _statusLabel() {
    final device = _activeId == null ? null : _devices[_activeId];
    final name = deviceLabel(device);
    return switch (_connection) {
      ConnectionState.connecting => 'Connecting to $name',
      ConnectionState.connected => 'Connected to $name',
      ConnectionState.disconnected => 'Disconnected',
    };
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({
    required this.devices,
    required this.activeId,
    required this.connection,
    required this.onConnect,
  });

  final List<BleDevice> devices;
  final String? activeId;
  final ConnectionState connection;
  final ValueChanged<String> onConnect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
      itemCount: devices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final device = devices[index];
        return _DeviceTile(
          key: ValueKey(device.id),
          device: device,
          activeId: activeId,
          connection: connection,
          onConnect: onConnect,
        );
      },
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    super.key,
    required this.device,
    required this.activeId,
    required this.connection,
    required this.onConnect,
  });

  final BleDevice device;
  final String? activeId;
  final ConnectionState connection;
  final ValueChanged<String> onConnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isActive = device.id == activeId;
    final isConnecting = isActive && connection == ConnectionState.connecting;
    final isConnected = isActive && connection == ConnectionState.connected;

    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                  color: isConnected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceLabel(device),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        device.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'RSSI ${device.rssi}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _DeviceAction(
                isConnecting: isConnecting,
                isConnected: isConnected,
                enabled: connection != ConnectionState.connecting,
                onConnect: () => onConnect(device.id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceAction extends StatelessWidget {
  const _DeviceAction({
    required this.isConnecting,
    required this.isConnected,
    required this.enabled,
    required this.onConnect,
  });

  final bool isConnecting;
  final bool isConnected;
  final bool enabled;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (isConnecting) {
      return const SizedBox.square(
        dimension: 48,
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (isConnected) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: scheme.primary),
          const SizedBox(width: 8),
          Text('Connected', style: TextStyle(color: scheme.primary)),
        ],
      );
    }
    return FilledButton(
      style: const ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(48, 48)),
      ),
      onPressed: enabled ? onConnect : null,
      child: const Text('Connect'),
    );
  }
}

class _ConnectionBar extends StatelessWidget {
  const _ConnectionBar({
    required this.label,
    required this.connection,
    required this.onDisconnect,
  });

  final String label;
  final ConnectionState connection;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connected = connection == ConnectionState.connected;
    return Material(
      color: scheme.primaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
          child: Row(
            children: [
              Icon(
                connected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_searching,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: scheme.onPrimaryContainer),
                ),
              ),
              if (connected)
                TextButton(
                  onPressed: onDisconnect,
                  child: const Text('Disconnect'),
                )
              else
                const Padding(
                  padding: EdgeInsetsDirectional.all(12),
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDevices extends StatelessWidget {
  const _EmptyDevices({
    required this.scanning,
    required this.error,
    required this.onStart,
    required this.onStop,
  });

  final bool scanning;
  final String? error;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final failed = error != null;
    final IconData icon;
    final String message;
    if (failed) {
      icon = Icons.bluetooth_disabled;
      message = error!;
    } else if (scanning) {
      icon = Icons.bluetooth_searching;
      message = 'Scanning for devices';
    } else {
      icon = Icons.bluetooth;
      message = 'No devices yet';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            if (scanning && !failed)
              const CircularProgressIndicator()
            else
              FilledButton(
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(48, 48)),
                ),
                onPressed: onStart,
                child: Text(failed ? 'Try again' : 'Start scan'),
              ),
            if (scanning && !failed) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onStop, child: const Text('Stop scan')),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String deviceLabel(BleDevice? device) {
  final name = device?.name;
  if (name != null && name.isNotEmpty) return name;
  return device?.id ?? 'device';
}

String _describe(Object error) {
  if (error is PlatformException) {
    final message = error.message;
    if (message != null && message.isNotEmpty) return message;
    return error.code;
  }
  return 'Something went wrong';
}
