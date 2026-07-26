import 'dart:math';

import 'package:firebase_database/firebase_database.dart';

String postureDateKey([DateTime? date]) {
  final value = date ?? DateTime.now();
  final year = value.year.toString();
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

class DailyStats {
  const DailyStats({
    int? monitoredTimeSeconds,
    int? badPostureSeconds,
    int? goodPostureSeconds,
    this.deviceScreenTimeSeconds,
    this.badDetectionCount = 0,
    this.goodDetectionCount = 0,
    this.alertsSentCount = 0,
    this.cameraUnavailableCount = 0,
    this.movementPausedCount = 0,
    int? totalScreenTime,
    int? totalBadPostureTime,
  }) : monitoredTimeSeconds = monitoredTimeSeconds ?? totalScreenTime ?? 0,
       badPostureSeconds = badPostureSeconds ?? totalBadPostureTime ?? 0,
       goodPostureSeconds =
           goodPostureSeconds ??
           ((monitoredTimeSeconds ?? totalScreenTime ?? 0) -
               (badPostureSeconds ?? totalBadPostureTime ?? 0));

  // Legacy totalScreenTimeSeconds means time monitored by Posture Guard. It is
  // intentionally not redefined as Android device screen time.
  final int monitoredTimeSeconds;
  final int badPostureSeconds;
  final int goodPostureSeconds;
  final int? deviceScreenTimeSeconds;
  final int badDetectionCount;
  final int goodDetectionCount;
  final int alertsSentCount;
  final int cameraUnavailableCount;
  final int movementPausedCount;

  int get totalScreenTime => monitoredTimeSeconds;

  int get totalBadPostureTime => badPostureSeconds;

  bool get hasTrackedPosture => monitoredTimeSeconds > 0;

  double get dailyScore {
    if (monitoredTimeSeconds <= 0) return 100;
    return (100 * (1 - badPostureSeconds / monitoredTimeSeconds)).clamp(0, 100);
  }

  factory DailyStats.fromValue(Object? value) {
    if (value is! Map) return const DailyStats();
    final data = Map<dynamic, dynamic>.from(value);
    final monitored =
        (data['monitoredTimeSeconds'] as num?)?.toInt() ??
        (data['totalScreenTimeSeconds'] as num?)?.toInt() ??
        0;
    final bad =
        (data['badPostureSeconds'] as num?)?.toInt() ??
        (data['totalBadPostureSeconds'] as num?)?.toInt() ??
        0;
    final rawDeviceScreenTime = data['deviceScreenTimeSeconds'];
    final safeMonitored = max(0, monitored);
    final safeBad = max(0, min(safeMonitored, bad));
    final rawGood = (data['goodPostureSeconds'] as num?)?.toInt();
    final safeGood = rawGood != null && rawGood >= 0 && rawGood <= safeMonitored
        ? rawGood
        : safeMonitored - safeBad;
    return DailyStats(
      monitoredTimeSeconds: safeMonitored,
      badPostureSeconds: safeBad,
      goodPostureSeconds: safeGood,
      deviceScreenTimeSeconds: rawDeviceScreenTime is num
          ? max(0, rawDeviceScreenTime.toInt())
          : null,
      badDetectionCount: (data['badDetectionCount'] as num?)?.toInt() ?? 0,
      goodDetectionCount: (data['goodDetectionCount'] as num?)?.toInt() ?? 0,
      alertsSentCount: (data['alertsSentCount'] as num?)?.toInt() ?? 0,
      cameraUnavailableCount:
          (data['cameraUnavailableCount'] as num?)?.toInt() ?? 0,
      movementPausedCount: (data['movementPausedCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class StatsDelta {
  const StatsDelta({
    this.screenSeconds = 0,
    this.badSeconds = 0,
    this.badDetections = 0,
    this.goodDetections = 0,
    this.alertsSent = 0,
    this.cameraUnavailable = 0,
    this.movementPaused = 0,
  });

  final int screenSeconds;
  final int badSeconds;
  final int badDetections;
  final int goodDetections;
  final int alertsSent;
  final int cameraUnavailable;
  final int movementPaused;

  bool get isEmpty {
    return screenSeconds == 0 &&
        badSeconds == 0 &&
        badDetections == 0 &&
        goodDetections == 0 &&
        alertsSent == 0 &&
        cameraUnavailable == 0 &&
        movementPaused == 0;
  }
}

class StatisticsRepository {
  StatisticsRepository({FirebaseDatabase? database})
    : _database = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _database;

  DatabaseReference referenceFor(String dateKey) {
    return _database.ref('users/demo_user/daily_stats/$dateKey');
  }

  DatabaseReference get _allDailyStatsReference {
    return _database.ref('users/demo_user/daily_stats');
  }

  Stream<DailyStats> watch(String dateKey) {
    return referenceFor(
      dateKey,
    ).onValue.map((event) => DailyStats.fromValue(event.snapshot.value));
  }

  Future<DailyStats> load(String dateKey) async {
    final snapshot = await referenceFor(dateKey).get();
    return DailyStats.fromValue(snapshot.value);
  }

  Stream<Map<String, DailyStats>> watchAll() {
    return _allDailyStatsReference.onValue.map(
      (event) => _recordsFromValue(event.snapshot.value),
    );
  }

  Future<Map<String, DailyStats>> loadAll() async {
    final snapshot = await _allDailyStatsReference.get();
    return _recordsFromValue(snapshot.value);
  }

  Map<String, DailyStats> _recordsFromValue(Object? value) {
    if (value is! Map) return const {};
    final map = Map<dynamic, dynamic>.from(value);
    if (map.containsKey('totalScreenTimeSeconds') ||
        map.containsKey('monitoredTimeSeconds')) {
      final dateKey = map['date']?.toString() ?? postureDateKey();
      return {dateKey: DailyStats.fromValue(map)};
    }

    final records = <String, DailyStats>{};
    for (final entry in map.entries) {
      if (entry.value is! Map) continue;
      records[entry.key.toString()] = DailyStats.fromValue(entry.value);
    }
    return records;
  }

  Future<void> saveDeviceScreenTime(
    String dateKey,
    int deviceScreenTimeSeconds,
  ) async {
    await referenceFor(dateKey).update({
      'date': dateKey,
      'deviceScreenTimeSeconds': max(0, deviceScreenTimeSeconds),
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> addDelta(String dateKey, StatsDelta delta) async {
    if (delta.isEmpty) return;

    final result = await referenceFor(dateKey).runTransaction((currentValue) {
      final data = currentValue is Map
          ? Map<String, Object?>.fromEntries(
              currentValue.entries.map(
                (entry) => MapEntry(entry.key.toString(), entry.value),
              ),
            )
          : <String, Object?>{};

      final totalScreen = max(
        0,
        ((data['monitoredTimeSeconds'] as num?)?.toInt() ??
                (data['totalScreenTimeSeconds'] as num?)?.toInt() ??
                0) +
            delta.screenSeconds,
      );
      final totalBad = min(
        totalScreen,
        max(
          0,
          ((data['badPostureSeconds'] as num?)?.toInt() ??
                  (data['totalBadPostureSeconds'] as num?)?.toInt() ??
                  0) +
              delta.badSeconds,
        ),
      );
      final good = max(0, totalScreen - totalBad);
      final score = totalScreen == 0
          ? 100
          : (100 * (1 - totalBad / totalScreen)).clamp(0, 100).round();

      data
        ..['date'] = dateKey
        ..['updatedAt'] = ServerValue.timestamp
        ..['monitoredTimeSeconds'] = totalScreen
        ..['totalScreenTimeSeconds'] = totalScreen
        ..['badPostureSeconds'] = totalBad
        ..['totalBadPostureSeconds'] = totalBad
        ..['goodPostureSeconds'] = good
        ..['score'] = score
        ..['scorePercent'] = score
        ..['badDetectionCount'] =
            ((data['badDetectionCount'] as num?)?.toInt() ?? 0) +
            delta.badDetections
        ..['goodDetectionCount'] =
            ((data['goodDetectionCount'] as num?)?.toInt() ?? 0) +
            delta.goodDetections
        ..['alertsSentCount'] =
            ((data['alertsSentCount'] as num?)?.toInt() ?? 0) + delta.alertsSent
        ..['cameraUnavailableCount'] =
            ((data['cameraUnavailableCount'] as num?)?.toInt() ?? 0) +
            delta.cameraUnavailable
        ..['movementPausedCount'] =
            ((data['movementPausedCount'] as num?)?.toInt() ?? 0) +
            delta.movementPaused;

      data.putIfAbsent('coinsEarned', () => 0);
      data.putIfAbsent('coinsAwarded', () => false);
      return Transaction.success(data);
    });

    if (!result.committed) {
      throw StateError('Daily statistics transaction was not committed.');
    }
  }
}
