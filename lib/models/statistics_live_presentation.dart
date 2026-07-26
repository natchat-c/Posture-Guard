import 'dart:math';

import '../services/statistics_repository.dart';

class StatisticsLivePresentation {
  StatisticsLivePresentation({required this.dateKey});

  String dateKey;
  Map<String, DailyStats> _records = const {};
  int monitoredSeconds = 0;
  int badPostureSeconds = 0;
  int? deviceScreenTimeSeconds;
  int alertsSent = 0;

  Map<String, DailyStats> get records {
    final result = Map<String, DailyStats>.from(_records);
    final authoritative = result[dateKey] ?? const DailyStats();
    result[dateKey] = DailyStats(
      monitoredTimeSeconds: monitoredSeconds,
      badPostureSeconds: badPostureSeconds,
      goodPostureSeconds: max(0, monitoredSeconds - badPostureSeconds),
      deviceScreenTimeSeconds: deviceScreenTimeSeconds,
      badDetectionCount: authoritative.badDetectionCount,
      goodDetectionCount: authoritative.goodDetectionCount,
      alertsSentCount: max(alertsSent, authoritative.alertsSentCount),
      cameraUnavailableCount: authoritative.cameraUnavailableCount,
      movementPausedCount: authoritative.movementPausedCount,
    );
    return result;
  }

  void reconcile(Map<String, DailyStats> records) {
    _records = records;
    final today = records[dateKey] ?? const DailyStats();
    monitoredSeconds = max(monitoredSeconds, today.monitoredTimeSeconds);
    badPostureSeconds = max(badPostureSeconds, today.badPostureSeconds);
    alertsSent = max(alertsSent, today.alertsSentCount);
    if (today.deviceScreenTimeSeconds != null) {
      deviceScreenTimeSeconds = max(
        deviceScreenTimeSeconds ?? 0,
        today.deviceScreenTimeSeconds!,
      );
    }
  }

  void reconcileDeviceScreenTime(int seconds) {
    deviceScreenTimeSeconds = max(
      deviceScreenTimeSeconds ?? 0,
      max(0, seconds),
    );
  }

  void recordAlertSent() {
    alertsSent++;
  }

  bool advance({
    required DateTime now,
    required bool trackingActive,
    required bool screenInteractive,
    required String postureStatus,
    required bool incrementDeviceScreenTime,
  }) {
    final nextDateKey = postureDateKey(now);
    if (nextDateKey != dateKey) {
      dateKey = nextDateKey;
      monitoredSeconds = 0;
      badPostureSeconds = 0;
      deviceScreenTimeSeconds = null;
      alertsSent = 0;
      return true;
    }

    if (trackingActive && screenInteractive) {
      monitoredSeconds++;
      if (postureStatus == 'BAD') badPostureSeconds++;
    }
    if (incrementDeviceScreenTime &&
        screenInteractive &&
        deviceScreenTimeSeconds != null) {
      deviceScreenTimeSeconds = deviceScreenTimeSeconds! + 1;
    }
    return false;
  }
}
