import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/platform/platform_capabilities.dart';
import 'package:postureguard/services/monitoring_service.dart';

class _RecordingMonitoringPlatformService
    extends UnsupportedBackgroundMonitoringPlatformService {
  bool communicationInitialized = false;
  bool initialized = false;
  int runningChecks = 0;
  int starts = 0;
  int stops = 0;
  final List<MonitoringTaskDataCallback> callbacks = [];
  final List<AppLifecycleState> lifecycleStates = [];

  @override
  bool get isSupported => true;

  @override
  void initializeCommunicationPort() => communicationInitialized = true;

  @override
  void initialize() => initialized = true;

  @override
  void addTaskDataCallback(MonitoringTaskDataCallback callback) {
    callbacks.add(callback);
  }

  @override
  void removeTaskDataCallback(MonitoringTaskDataCallback callback) {
    callbacks.remove(callback);
  }

  @override
  Future<bool> isRunning() async {
    runningChecks++;
    return true;
  }

  @override
  Future<MonitoringActionResult> start() async {
    starts++;
    return const MonitoringActionResult(success: true, isRunning: true);
  }

  @override
  Future<MonitoringActionResult> stop() async {
    stops++;
    return const MonitoringActionResult(success: true, isRunning: false);
  }

  @override
  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    lifecycleStates.add(state);
  }
}

void main() {
  const capabilityResolver = PlatformCapabilityResolver();
  const monitoringResolver = BackgroundMonitoringPlatformServiceResolver();

  tearDown(MonitoringService.resetPlatformServiceForTesting);

  test('Android keeps the existing foreground-service implementation', () {
    final service = monitoringResolver.resolve(
      capabilities: capabilityResolver.resolve(
        platform: TargetPlatform.android,
        isWeb: false,
      ),
    );

    expect(service, isA<AndroidBackgroundMonitoringPlatformService>());
  });

  test(
    'iOS selects foreground monitoring without claiming background parity',
    () {
      final service = monitoringResolver.resolve(
        capabilities: capabilityResolver.resolve(
          platform: TargetPlatform.iOS,
          isWeb: false,
        ),
      );

      expect(service, isA<IosForegroundMonitoringPlatformService>());
      expect(service.isSupported, isTrue);
    },
  );

  test('non-mobile monitoring is explicit and never claims to run', () async {
    final service = monitoringResolver.resolve(
      capabilities: capabilityResolver.resolve(
        platform: TargetPlatform.windows,
        isWeb: false,
      ),
    );

    expect(service, isA<UnsupportedBackgroundMonitoringPlatformService>());
    expect(service.isSupported, isFalse);
    expect(await service.isRunning(), isFalse);
    final result = await service.start();
    expect(result.success, isFalse);
    expect(result.isRunning, isFalse);
  });

  test('MonitoringService facade delegates to its platform service', () async {
    final service = _RecordingMonitoringPlatformService();
    MonitoringService.usePlatformServiceForTesting(service);
    void callback(Object data) {}

    MonitoringService.initializeCommunicationPort();
    MonitoringService.initialize();
    MonitoringService.addTaskDataCallback(callback);
    expect(await MonitoringService.isRunning(), isTrue);
    expect((await MonitoringService.start()).isRunning, isTrue);
    await MonitoringService.handleAppLifecycleState(AppLifecycleState.paused);
    expect((await MonitoringService.stop()).isRunning, isFalse);
    MonitoringService.removeTaskDataCallback(callback);

    expect(service.communicationInitialized, isTrue);
    expect(service.initialized, isTrue);
    expect(service.runningChecks, 1);
    expect(service.starts, 1);
    expect(service.stops, 1);
    expect(service.lifecycleStates, [AppLifecycleState.paused]);
    expect(service.callbacks, isEmpty);
  });
}
