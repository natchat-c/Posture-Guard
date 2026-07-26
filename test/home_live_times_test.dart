import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/models/home_live_times.dart';
import 'package:postureguard/services/statistics_repository.dart';

class _FakeTimer implements Timer {
  bool active = true;
  bool cancelled = false;
  int ticks = 0;

  @override
  bool get isActive => active;

  @override
  int get tick => ticks;

  @override
  void cancel() {
    active = false;
    cancelled = true;
  }
}

void main() {
  test(
    'live values advance once per presentation tick without persistence',
    () {
      final values = HomeLiveTimes(dateKey: '2026-07-26')
        ..reconcile(
          const DailyStats(
            monitoredTimeSeconds: 100,
            badPostureSeconds: 20,
            deviceScreenTimeSeconds: 200,
          ),
        );

      values.advance(
        now: DateTime(2026, 7, 26, 12),
        monitoringActive: true,
        postureStatus: 'GOOD',
        incrementDeviceScreenTime: true,
      );
      expect(values.monitoredSeconds, 101);
      expect(values.goodPostureSeconds, 81);
      expect(values.badPostureSeconds, 20);
      expect(values.deviceScreenTimeSeconds, 201);

      values.advance(
        now: DateTime(2026, 7, 26, 12, 0, 1),
        monitoringActive: true,
        postureStatus: 'BAD',
        incrementDeviceScreenTime: true,
      );
      expect(values.monitoredSeconds, 102);
      expect(values.badPostureSeconds, 21);
    },
  );

  test('disabled monitoring freezes posture but not device screen time', () {
    final values = HomeLiveTimes(dateKey: '2026-07-26')
      ..monitoredSeconds = 50
      ..badPostureSeconds = 10
      ..deviceScreenTimeSeconds = 500;

    values.advance(
      now: DateTime(2026, 7, 26, 12),
      monitoringActive: false,
      postureStatus: 'BAD',
      incrementDeviceScreenTime: true,
    );

    expect(values.monitoredSeconds, 50);
    expect(values.badPostureSeconds, 10);
    expect(values.deviceScreenTimeSeconds, 501);
  });

  test(
    'authoritative repository values reconcile optimistic display values',
    () {
      final values = HomeLiveTimes(dateKey: '2026-07-26')
        ..monitoredSeconds = 110
        ..badPostureSeconds = 25;

      values.reconcile(
        const DailyStats(monitoredTimeSeconds: 108, badPostureSeconds: 24),
      );

      expect(values.monitoredSeconds, 108);
      expect(values.badPostureSeconds, 24);
    },
  );

  test('midnight resets current-day presentation values', () {
    final values = HomeLiveTimes(dateKey: '2026-12-31')
      ..monitoredSeconds = 100
      ..badPostureSeconds = 10
      ..deviceScreenTimeSeconds = 200;

    final changed = values.advance(
      now: DateTime(2027, 1, 1),
      monitoringActive: true,
      postureStatus: 'BAD',
      incrementDeviceScreenTime: true,
    );

    expect(changed, isTrue);
    expect(values.dateKey, '2027-01-01');
    expect(values.monitoredSeconds, 0);
    expect(values.badPostureSeconds, 0);
    expect(values.deviceScreenTimeSeconds, isNull);
  });

  test('presentation ticker starts once and cancels on disposal', () {
    late void Function() callback;
    late _FakeTimer timer;
    final ticker = PresentationTicker(
      timerFactory: (duration, onTick) {
        expect(duration, const Duration(seconds: 1));
        callback = onTick;
        timer = _FakeTimer();
        return timer;
      },
    );
    var ticks = 0;

    ticker.start(() => ticks++);
    ticker.start(() => ticks += 100);
    callback();

    expect(ticker.startCount, 1);
    expect(ticks, 1);
    ticker.dispose();
    expect(timer.cancelled, isTrue);
    expect(ticker.isRunning, isFalse);
  });
}
