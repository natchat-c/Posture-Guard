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
    this.totalScreenTime = 0,
    this.totalBadPostureTime = 0,
    this.badDetectionCount = 0,
    this.goodDetectionCount = 0,
    this.alertsSentCount = 0,
    this.cameraUnavailableCount = 0,
    this.movementPausedCount = 0,
  });

  final int totalScreenTime;
  final int totalBadPostureTime;
  final int badDetectionCount;
  final int goodDetectionCount;
  final int alertsSentCount;
  final int cameraUnavailableCount;
  final int movementPausedCount;

  double get dailyScore {
    if (totalScreenTime <= 0) return 100;
    return (100 * (1 - totalBadPostureTime / totalScreenTime)).clamp(0, 100);
  }

  factory DailyStats.fromValue(Object? value) {
    if (value is! Map) return const DailyStats();
    final data = Map<dynamic, dynamic>.from(value);
    return DailyStats(
      totalScreenTime: (data['totalScreenTimeSeconds'] as num?)?.toInt() ?? 0,
      totalBadPostureTime:
          (data['totalBadPostureSeconds'] as num?)?.toInt() ?? 0,
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

  Stream<DailyStats> watch(String dateKey) {
    return referenceFor(
      dateKey,
    ).onValue.map((event) => DailyStats.fromValue(event.snapshot.value));
  }

  Future<DailyStats> load(String dateKey) async {
    final snapshot = await referenceFor(dateKey).get();
    return DailyStats.fromValue(snapshot.value);
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
        ((data['totalScreenTimeSeconds'] as num?)?.toInt() ?? 0) +
            delta.screenSeconds,
      );
      final totalBad = min(
        totalScreen,
        max(
          0,
          ((data['totalBadPostureSeconds'] as num?)?.toInt() ?? 0) +
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
        ..['totalScreenTimeSeconds'] = totalScreen
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
