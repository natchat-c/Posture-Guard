import 'dart:async';

import '../services/statistics_repository.dart';

typedef PeriodicTimerFactory =
    Timer Function(Duration duration, void Function() callback);

class HomeLiveTimes {
  HomeLiveTimes({required this.dateKey});

  String dateKey;
  int monitoredSeconds = 0;
  int badPostureSeconds = 0;
  int? deviceScreenTimeSeconds;

  int get goodPostureSeconds {
    return (monitoredSeconds - badPostureSeconds)
        .clamp(0, monitoredSeconds)
        .toInt();
  }

  void reconcile(DailyStats stats) {
    monitoredSeconds = stats.monitoredTimeSeconds;
    badPostureSeconds = stats.badPostureSeconds;
    if (stats.deviceScreenTimeSeconds != null) {
      deviceScreenTimeSeconds = stats.deviceScreenTimeSeconds;
    }
  }

  void reconcileDeviceScreenTime(int seconds) {
    deviceScreenTimeSeconds = seconds < 0 ? 0 : seconds;
  }

  bool advance({
    required DateTime now,
    required bool monitoringActive,
    required String postureStatus,
    required bool incrementDeviceScreenTime,
  }) {
    final nextDateKey = postureDateKey(now);
    if (nextDateKey != dateKey) {
      dateKey = nextDateKey;
      monitoredSeconds = 0;
      badPostureSeconds = 0;
      deviceScreenTimeSeconds = null;
      return true;
    }

    if (monitoringActive) {
      monitoredSeconds++;
      if (postureStatus == 'BAD') badPostureSeconds++;
    }
    if (incrementDeviceScreenTime && deviceScreenTimeSeconds != null) {
      deviceScreenTimeSeconds = deviceScreenTimeSeconds! + 1;
    }
    return false;
  }
}

class PresentationTicker {
  PresentationTicker({PeriodicTimerFactory? timerFactory})
    : _timerFactory =
          timerFactory ??
          ((duration, callback) => Timer.periodic(duration, (_) => callback()));

  final PeriodicTimerFactory _timerFactory;
  Timer? _timer;
  int _startCount = 0;

  bool get isRunning => _timer?.isActive ?? false;

  int get startCount => _startCount;

  void start(void Function() onTick) {
    if (_timer != null) return;
    _startCount++;
    _timer = _timerFactory(const Duration(seconds: 1), onTick);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
