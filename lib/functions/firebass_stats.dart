import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../services/user_database_paths.dart';

String getTodayKey() {
  final now = DateTime.now();

  final year = now.year.toString();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');

  return '$year-$month-$day';
}

Future<DatabaseReference> getTodayStatsRef({
  UserDatabaseReferenceFactory? referenceFactory,
}) {
  return (referenceFactory ?? UserDatabaseReferenceFactory()).dailyStats(
    getTodayKey(),
  );
}

double calculateDailyScore({
  required int totalScreenTime,
  required int totalBadPostureTime,
}) {
  if (totalScreenTime == 0) return 100.0;

  final score = 100 * (1 - (totalBadPostureTime / totalScreenTime));

  return score.clamp(0.0, 100.0);
}

Future<Map<String, int>?> loadTodayStats() async {
  try {
    final reference = await getTodayStatsRef();
    final snapshot = await reference.get();

    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    final data = Map<dynamic, dynamic>.from(snapshot.value as Map);

    return {
      'totalScreenTime': (data['totalScreenTimeSeconds'] as num?)?.toInt() ?? 0,
      'totalBadPostureTime':
          (data['totalBadPostureSeconds'] as num?)?.toInt() ?? 0,
    };
  } catch (e) {
    debugPrint('Load Firebase error: $e');
    return null;
  }
}

Future<void> saveTodayStats({
  required int totalScreenTime,
  required int totalBadPostureTime,
}) async {
  try {
    final goodPostureTime = max(
      0,
      totalScreenTime - totalBadPostureTime,
    ).toInt();

    final dailyScore = calculateDailyScore(
      totalScreenTime: totalScreenTime,
      totalBadPostureTime: totalBadPostureTime,
    );

    final reference = await getTodayStatsRef();
    await reference.update({
      'date': getTodayKey(),
      'updatedAt': ServerValue.timestamp,
      // Legacy totalScreenTimeSeconds remains monitored posture time.
      'monitoredTimeSeconds': totalScreenTime,
      'totalScreenTimeSeconds': totalScreenTime,
      'badPostureSeconds': totalBadPostureTime,
      'totalBadPostureSeconds': totalBadPostureTime,
      'goodPostureSeconds': goodPostureTime,
      'score': dailyScore.round(),
      'scorePercent': dailyScore.round(),
    });
  } catch (e) {
    debugPrint('Save Firebase error: $e');
  }
}
