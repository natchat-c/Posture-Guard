import 'dart:math';

import '../services/statistics_repository.dart';

const int bestDayMinimumMonitoredSeconds = 10 * 60;
const double meaningfulTrendThresholdPoints = 0.5;

List<DateTime> rollingLocalDates(DateTime now, {int count = 7}) {
  final today = DateTime(now.year, now.month, now.day);
  return List<DateTime>.generate(
    count,
    (index) =>
        DateTime(today.year, today.month, today.day - (count - 1 - index)),
    growable: false,
  );
}

String formatCompactDuration(int seconds) {
  final safeSeconds = max(0, seconds);
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  final remainingSeconds = safeSeconds % 60;
  if (hours > 0) {
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }
  if (minutes > 0) {
    return remainingSeconds == 0
        ? '${minutes}m'
        : '${minutes}m ${remainingSeconds}s';
  }
  return '${remainingSeconds}s';
}

class PeriodStatistics {
  const PeriodStatistics({
    required this.days,
    required this.trackedDays,
    required this.totalMonitoredSeconds,
    required this.totalGoodSeconds,
    required this.totalBadSeconds,
    required this.alertsSent,
    required this.averageDailyScore,
    required this.weightedScore,
  });

  final List<DateTime> days;
  final int trackedDays;
  final int totalMonitoredSeconds;
  final int totalGoodSeconds;
  final int totalBadSeconds;
  final int alertsSent;
  final double? averageDailyScore;
  final double? weightedScore;

  double? get averageMonitoredSecondsPerTrackedDay {
    if (trackedDays == 0) return null;
    return totalMonitoredSeconds / trackedDays;
  }
}

class BestRecordedDay {
  const BestRecordedDay({
    required this.date,
    required this.score,
    required this.monitoredSeconds,
  });

  final DateTime date;
  final double score;
  final int monitoredSeconds;
}

class AllTimeStatistics {
  const AllTimeStatistics({
    required this.daysTracked,
    required this.totalMonitoredSeconds,
    required this.totalGoodSeconds,
    required this.totalBadSeconds,
    required this.weightedScore,
    required this.bestDay,
  });

  final int daysTracked;
  final int totalMonitoredSeconds;
  final int totalGoodSeconds;
  final int totalBadSeconds;
  final double? weightedScore;
  final BestRecordedDay? bestDay;
}

class DailyScorePoint {
  const DailyScorePoint({
    required this.date,
    required this.score,
    required this.isToday,
  });

  final DateTime date;
  final double? score;
  final bool isToday;

  bool get hasData => score != null;
}

enum ScoreTrend { improvement, decline, unchanged, insufficientData }

class StatisticsSummary {
  const StatisticsSummary({
    required this.today,
    required this.todayDeviceScreenTimeSeconds,
    required this.pastSevenDays,
    required this.previousSevenDays,
    required this.pastSeven,
    required this.allTime,
    required this.trend,
    required this.trendPoints,
  });

  final DailyStats today;
  final int? todayDeviceScreenTimeSeconds;
  final List<DateTime> pastSevenDays;
  final List<DateTime> previousSevenDays;
  final PeriodStatistics pastSeven;
  final AllTimeStatistics allTime;
  final ScoreTrend trend;
  final double? trendPoints;

  factory StatisticsSummary.calculate({
    required Map<String, DailyStats> records,
    DateTime? now,
    int? todayDeviceScreenTimeOverride,
  }) {
    final current = now ?? DateTime.now();
    final pastSevenDays = rollingLocalDates(current);
    final previousEnd = DateTime(
      pastSevenDays.first.year,
      pastSevenDays.first.month,
      pastSevenDays.first.day - 1,
    );
    final previousSevenDays = rollingLocalDates(previousEnd);
    final past = _period(records, pastSevenDays);
    final previous = _period(records, previousSevenDays);
    final today = records[postureDateKey(current)] ?? const DailyStats();
    final trendPoints =
        past.weightedScore == null || previous.weightedScore == null
        ? null
        : past.weightedScore! - previous.weightedScore!;
    final trend = trendPoints == null
        ? ScoreTrend.insufficientData
        : trendPoints.abs() < meaningfulTrendThresholdPoints
        ? ScoreTrend.unchanged
        : trendPoints > 0
        ? ScoreTrend.improvement
        : ScoreTrend.decline;

    return StatisticsSummary(
      today: today,
      todayDeviceScreenTimeSeconds:
          todayDeviceScreenTimeOverride ?? today.deviceScreenTimeSeconds,
      pastSevenDays: pastSevenDays,
      previousSevenDays: previousSevenDays,
      pastSeven: past,
      allTime: _allTime(records),
      trend: trend,
      trendPoints: trendPoints,
    );
  }

  List<double> scoresForPastSevenDays(Map<String, DailyStats> records) {
    return pastSevenDays
        .map((day) {
          final stats = records[postureDateKey(day)];
          return stats == null || !stats.hasTrackedPosture
              ? 0.0
              : stats.dailyScore;
        })
        .toList(growable: false);
  }

  List<DailyScorePoint> scorePointsForPastSevenDays(
    Map<String, DailyStats> records,
  ) {
    final today = pastSevenDays.last;
    return pastSevenDays
        .map((day) {
          final stats = records[postureDateKey(day)];
          return DailyScorePoint(
            date: day,
            score: stats == null || !stats.hasTrackedPosture
                ? null
                : stats.dailyScore.clamp(0, 100).toDouble(),
            isToday: day == today,
          );
        })
        .toList(growable: false);
  }

  static PeriodStatistics _period(
    Map<String, DailyStats> records,
    List<DateTime> days,
  ) {
    final tracked = days
        .map((day) => records[postureDateKey(day)])
        .whereType<DailyStats>()
        .where((stats) => stats.hasTrackedPosture)
        .toList();
    final totalMonitored = tracked.fold<int>(
      0,
      (sum, stats) => sum + stats.monitoredTimeSeconds,
    );
    final totalBad = tracked.fold<int>(
      0,
      (sum, stats) => sum + stats.badPostureSeconds,
    );
    final totalGood = max(0, totalMonitored - totalBad);
    return PeriodStatistics(
      days: days,
      trackedDays: tracked.length,
      totalMonitoredSeconds: totalMonitored,
      totalGoodSeconds: totalGood,
      totalBadSeconds: totalBad,
      alertsSent: tracked.fold<int>(
        0,
        (sum, stats) => sum + stats.alertsSentCount,
      ),
      averageDailyScore: tracked.isEmpty
          ? null
          : tracked.fold<double>(0, (sum, stats) => sum + stats.dailyScore) /
                tracked.length,
      weightedScore: totalMonitored == 0
          ? null
          : 100 * totalGood / totalMonitored,
    );
  }

  static AllTimeStatistics _allTime(Map<String, DailyStats> records) {
    final tracked = records.entries
        .where((entry) => entry.value.hasTrackedPosture)
        .toList();
    final totalMonitored = tracked.fold<int>(
      0,
      (sum, entry) => sum + entry.value.monitoredTimeSeconds,
    );
    final totalBad = tracked.fold<int>(
      0,
      (sum, entry) => sum + entry.value.badPostureSeconds,
    );
    final totalGood = max(0, totalMonitored - totalBad);
    BestRecordedDay? bestDay;
    for (final entry in tracked) {
      final stats = entry.value;
      if (stats.monitoredTimeSeconds < bestDayMinimumMonitoredSeconds) {
        continue;
      }
      final date = DateTime.tryParse(entry.key);
      if (date == null) continue;
      if (bestDay == null || stats.dailyScore > bestDay.score) {
        bestDay = BestRecordedDay(
          date: date,
          score: stats.dailyScore,
          monitoredSeconds: stats.monitoredTimeSeconds,
        );
      }
    }

    return AllTimeStatistics(
      daysTracked: tracked.length,
      totalMonitoredSeconds: totalMonitored,
      totalGoodSeconds: totalGood,
      totalBadSeconds: totalBad,
      weightedScore: totalMonitored == 0
          ? null
          : 100 * totalGood / totalMonitored,
      bestDay: bestDay,
    );
  }
}
