import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/models/app_settings.dart';
import 'package:postureguard/models/calibration.dart';
import 'package:postureguard/services/ios_foreground_monitoring_service.dart';
import 'package:postureguard/services/monitoring_service.dart';
import 'package:postureguard/services/statistics_repository.dart';

class _FakeMotionSensorSource implements MotionSensorSource {
  _FakeMotionSensorSource() {
    _controller = StreamController<MotionSensorSample>.broadcast(
      sync: true,
      onListen: () => listenCount++,
      onCancel: () => cancelCount++,
    );
  }

  late final StreamController<MotionSensorSample> _controller;
  int listenCount = 0;
  int cancelCount = 0;

  @override
  Stream<MotionSensorSample> samples() => _controller.stream;

  void add(MotionSensorSample sample) => _controller.add(sample);

  void addError(Object error) => _controller.addError(error);

  Future<void> close() => _controller.close();
}

class _FakeClock {
  _FakeClock(this.value);

  DateTime value;

  DateTime call() => value;

  void advance(Duration duration) {
    value = value.add(duration);
  }
}

IosForegroundMonitoringController _controller({
  required _FakeMotionSensorSource sensorSource,
  required _FakeClock clock,
  AppSettings settings = const AppSettings(
    monitoringEnabled: true,
    alertDelaySeconds: 5,
    alertFrequencySeconds: 30,
    alertsEnabled: false,
  ),
  Duration sensorAvailabilityTimeout = const Duration(minutes: 1),
  ForegroundStatsWriter? writeStats,
  Future<void> Function()? initializeNotifications,
}) {
  return IosForegroundMonitoringController(
    sensorSource: sensorSource,
    loadSettings: () async => settings,
    loadCalibration: () async => const Calibration(neutralPhoneAngle: 90),
    loadAlertsMuted: () async => false,
    initializeNotifications: initializeNotifications ?? () async {},
    showPostureAlert: () async {},
    cancelPostureAlert: () async {},
    writeStats: writeStats ?? (dateKey, delta) async {},
    synchronizeStats: () async {},
    now: clock.call,
    isAppForeground: () => true,
    sensorAvailabilityTimeout: sensorAvailabilityTimeout,
    monitoringTickInterval: const Duration(hours: 1),
  );
}

Map<dynamic, dynamic> _lastState(List<Map<dynamic, dynamic>> events) {
  return events.lastWhere((event) => event['type'] == 'monitoringState');
}

void main() {
  test(
    'iOS foreground start reuses posture math and alert-delay classification',
    () async {
      final source = _FakeMotionSensorSource();
      final clock = _FakeClock(DateTime(2026, 8, 29, 10));
      final events = <Map<dynamic, dynamic>>[];
      final writtenDeltas = <StatsDelta>[];
      final controller = _controller(
        sensorSource: source,
        clock: clock,
        writeStats: (dateKey, delta) async => writtenDeltas.add(delta),
      );
      final service = IosForegroundMonitoringPlatformService(
        controller: controller,
      );
      service.addTaskDataCallback((data) {
        if (data is Map) events.add(data);
      });
      addTearDown(source.close);

      expect(
        await service.notificationPermission(),
        NotificationPermission.denied,
      );
      final result = await service.start().timeout(const Duration(seconds: 1));

      expect(result.success, isTrue);
      expect(result.isRunning, isTrue);
      expect(source.listenCount, 1);
      expect(controller.isSensorTracking, isTrue);

      source.add(const MotionSensorSample(x: 1, y: 0, z: 0));
      source.add(const MotionSensorSample(x: 0, y: 0, z: 1));
      source.add(const MotionSensorSample(x: 0, y: 0, z: 1));
      expect(_lastState(events)['postureStatus'], 'WARNING');

      clock.advance(const Duration(seconds: 5));
      source.add(const MotionSensorSample(x: 0, y: 0, z: 1));
      expect(_lastState(events)['postureStatus'], 'BAD');
      await controller.tickForTesting();

      service.reportCameraUnavailable();
      expect(controller.isSensorTracking, isTrue);

      await service.stop();
      expect(
        writtenDeltas.fold<int>(0, (sum, delta) => sum + delta.screenSeconds),
        5,
      );
      expect(
        writtenDeltas.fold<int>(0, (sum, delta) => sum + delta.badSeconds),
        5,
      );
      expect(
        writtenDeltas.fold<int>(0, (sum, delta) => sum + delta.badDetections),
        1,
      );
      expect(
        writtenDeltas.fold<int>(
          0,
          (sum, delta) => sum + delta.cameraUnavailable,
        ),
        1,
      );
    },
  );

  test(
    'foreground to background pauses and resume restores enabled monitoring',
    () async {
      final source = _FakeMotionSensorSource();
      final clock = _FakeClock(DateTime(2026, 8, 29, 11));
      final events = <Map<dynamic, dynamic>>[];
      final controller = _controller(sensorSource: source, clock: clock);
      final service = IosForegroundMonitoringPlatformService(
        controller: controller,
      );
      service.addTaskDataCallback((data) {
        if (data is Map) events.add(data);
      });
      addTearDown(source.close);

      expect((await service.start()).success, isTrue);
      source.add(const MotionSensorSample(x: 1, y: 0, z: 0));
      expect(controller.hasSensorReading, isTrue);

      await service.handleAppLifecycleState(AppLifecycleState.paused);
      expect(controller.isForegroundActive, isFalse);
      expect(controller.isSensorTracking, isFalse);
      expect(controller.hasSensorReading, isFalse);
      expect(source.cancelCount, 1);
      expect(_lastState(events)['active'], isFalse);

      await service.handleAppLifecycleState(AppLifecycleState.resumed);
      expect(await service.isRunning(), isTrue);
      expect(controller.isForegroundActive, isTrue);
      expect(controller.isSensorTracking, isTrue);
      expect(source.listenCount, 2);
      expect(_lastState(events)['active'], isTrue);

      await service.stop();
      await service.handleAppLifecycleState(AppLifecycleState.resumed);
      expect(source.listenCount, 2);
    },
  );

  test(
    'missing simulator sensor samples fail safely without a stuck start',
    () async {
      final source = _FakeMotionSensorSource();
      final clock = _FakeClock(DateTime(2026, 8, 29, 12));
      final events = <Map<dynamic, dynamic>>[];
      final controller = _controller(
        sensorSource: source,
        clock: clock,
        sensorAvailabilityTimeout: Duration.zero,
      );
      final service = IosForegroundMonitoringPlatformService(
        controller: controller,
      );
      service.addTaskDataCallback((data) {
        if (data is Map) events.add(data);
      });
      addTearDown(source.close);

      final result = await service.start().timeout(const Duration(seconds: 1));
      source.add(const MotionSensorSample(x: 0, y: 0, z: 0));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(result.success, isTrue);
      expect(controller.isEnabled, isTrue);
      expect(controller.isForegroundActive, isTrue);
      expect(controller.isSensorTracking, isFalse);
      expect(controller.hasSensorReading, isFalse);
      expect(
        events.where(
          (event) =>
              event['type'] == 'monitoringError' &&
              event['code'] == 'motionSensorsUnavailable',
        ),
        hasLength(1),
      );

      final lateEvents = <Map<dynamic, dynamic>>[];
      service.addTaskDataCallback((data) {
        if (data is Map) lateEvents.add(data);
      });
      await Future<void>.delayed(Duration.zero);
      expect(
        lateEvents.where(
          (event) => event['code'] == 'motionSensorsUnavailable',
        ),
        hasLength(1),
      );

      service.requestState();
      expect(_lastState(events)['hasSensorReading'], isFalse);
      await service.stop();
    },
  );

  test(
    'sensor stream errors do not stop the foreground service state',
    () async {
      final source = _FakeMotionSensorSource();
      final clock = _FakeClock(DateTime(2026, 8, 29, 13));
      final events = <Map<dynamic, dynamic>>[];
      final controller = _controller(sensorSource: source, clock: clock);
      final service = IosForegroundMonitoringPlatformService(
        controller: controller,
      );
      service.addTaskDataCallback((data) {
        if (data is Map) events.add(data);
      });
      addTearDown(source.close);

      expect((await service.start()).success, isTrue);
      source.addError(StateError('accelerometer unavailable'));
      await Future<void>.delayed(Duration.zero);

      expect(await service.isRunning(), isTrue);
      expect(controller.isSensorTracking, isFalse);
      expect(_lastState(events)['sensorAvailable'], isFalse);
      await service.stop();
    },
  );

  test('notification setup failure does not block sensor monitoring', () async {
    final source = _FakeMotionSensorSource();
    final clock = _FakeClock(DateTime(2026, 8, 29, 14));
    final controller = _controller(
      sensorSource: source,
      clock: clock,
      initializeNotifications: () async {
        throw StateError('notification permission unavailable');
      },
    );
    final service = IosForegroundMonitoringPlatformService(
      controller: controller,
    );
    addTearDown(source.close);

    final result = await service.start().timeout(const Duration(seconds: 1));
    await Future<void>.delayed(Duration.zero);

    expect(result.success, isTrue);
    expect(controller.isSensorTracking, isTrue);
    source.add(const MotionSensorSample(x: 1, y: 0, z: 0));
    expect(controller.hasSensorReading, isTrue);
    await service.stop();
  });
}
