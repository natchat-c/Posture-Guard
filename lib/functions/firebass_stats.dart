import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

String getTodayKey() {
  final now = DateTime.now();

  final year = now.year.toString();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');

  return '$year-$month-$day';
}

DatabaseReference getTodayStatsRef() {
  return FirebaseDatabase.instance.ref(
    'users/demo_user/daily_stats/${getTodayKey()}',
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
    final snapshot = await getTodayStatsRef().get();

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

    await getTodayStatsRef().set({
      'date': getTodayKey(),
      'updatedAt': ServerValue.timestamp,
      'totalScreenTimeSeconds': totalScreenTime,
      'totalBadPostureSeconds': totalBadPostureTime,
      'goodPostureSeconds': goodPostureTime,
      'score': dailyScore.round(),
      'scorePercent': dailyScore.round(),
    });
  } catch (e) {
    debugPrint('Save Firebase error: $e');
  }
}
