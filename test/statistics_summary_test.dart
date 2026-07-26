import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/models/statistics_summary.dart';
import 'package:postureguard/services/statistics_repository.dart';

void main() {
  group('rollingLocalDates', () {
    test('uses the latest seven local dates ending today', () {
      final dates = rollingLocalDates(DateTime(2026, 7, 30, 23, 59));

      expect(dates.length, 7);
      expect(dates.first, DateTime(2026, 7, 24));
      expect(dates.last, DateTime(2026, 7, 30));
      expect(dates, orderedEquals([...dates]..sort()));
    });

    test('works on Sunday and across month boundaries', () {
      final dates = rollingLocalDates(DateTime(2026, 3, 1));

      expect(dates.first, DateTime(2026, 2, 23));
      expect(dates.last.weekday, DateTime.sunday);
      expect(dates.last, DateTime(2026, 3, 1));
    });

    test('crosses year and leap-year boundaries with calendar dates', () {
      final yearBoundary = rollingLocalDates(DateTime(2027, 1, 2));
      final leapBoundary = rollingLocalDates(DateTime(2028, 3, 2));

      expect(yearBoundary.first, DateTime(2026, 12, 27));
      expect(yearBoundary.last, DateTime(2027, 1, 2));
      expect(leapBoundary, contains(DateTime(2028, 2, 29)));
      expect(leapBoundary.length, 7);
    });

    test(
      'calendar construction remains exactly seven dates around DST dates',
      () {
        final dates = rollingLocalDates(DateTime(2026, 3, 10));

        expect(dates.map(postureDateKey).toSet().length, 7);
        expect(dates.first, DateTime(2026, 3, 4));
        expect(dates.last, DateTime(2026, 3, 10));
      },
    );
  });

  test('legacy monitored fields stay separate from nullable device time', () {
    final legacy = DailyStats.fromValue({
      'totalScreenTimeSeconds': 600,
      'totalBadPostureSeconds': 120,
      'scorePercent': 80,
    });

    expect(legacy.monitoredTimeSeconds, 600);
    expect(legacy.goodPostureSeconds, 480);
    expect(legacy.badPostureSeconds, 120);
    expect(legacy.deviceScreenTimeSeconds, isNull);
    expect(legacy.dailyScore, 80);
  });

  test(
    'calculates today, seven-day, all-time, best-day, and trend summaries',
    () {
      final records = <String, DailyStats>{
        '2026-01-15': const DailyStats(
          monitoredTimeSeconds: 600,
          badPostureSeconds: 60,
          deviceScreenTimeSeconds: 1500,
          alertsSentCount: 2,
        ),
        '2026-01-14': const DailyStats(
          monitoredTimeSeconds: 300,
          badPostureSeconds: 60,
          alertsSentCount: 1,
        ),
        '2026-01-08': const DailyStats(
          monitoredTimeSeconds: 600,
          badPostureSeconds: 300,
        ),
        '2026-01-01': const DailyStats(
          monitoredTimeSeconds: 599,
          badPostureSeconds: 0,
        ),
      };

      final summary = StatisticsSummary.calculate(
        records: records,
        now: DateTime(2026, 1, 15, 12),
      );

      expect(summary.todayDeviceScreenTimeSeconds, 1500);
      expect(summary.pastSevenDays.first, DateTime(2026, 1, 9));
      expect(summary.pastSeven.trackedDays, 2);
      expect(summary.pastSeven.totalMonitoredSeconds, 900);
      expect(summary.pastSeven.totalGoodSeconds, 780);
      expect(summary.pastSeven.totalBadSeconds, 120);
      expect(summary.pastSeven.alertsSent, 3);
      expect(summary.pastSeven.averageDailyScore, closeTo(85, 0.001));
      expect(
        summary.pastSeven.averageMonitoredSecondsPerTrackedDay,
        closeTo(450, 0.001),
      );
      expect(summary.pastSeven.weightedScore, closeTo(86.666, 0.01));

      expect(summary.allTime.daysTracked, 4);
      expect(summary.allTime.totalMonitoredSeconds, 2099);
      expect(summary.allTime.weightedScore, closeTo(79.99, 0.01));
      expect(summary.allTime.bestDay?.date, DateTime(2026, 1, 15));
      expect(summary.allTime.bestDay?.score, 90);
      expect(summary.trend, ScoreTrend.improvement);
      expect(summary.trendPoints, closeTo(36.666, 0.01));
    },
  );

  test('missing days are charted as zero but excluded from averages', () {
    final records = {
      '2026-07-26': const DailyStats(
        monitoredTimeSeconds: 60,
        badPostureSeconds: 0,
      ),
    };
    final summary = StatisticsSummary.calculate(
      records: records,
      now: DateTime(2026, 7, 26),
    );

    expect(summary.scoresForPastSevenDays(records), [0, 0, 0, 0, 0, 0, 100]);
    expect(summary.pastSeven.trackedDays, 1);
    expect(summary.pastSeven.averageDailyScore, 100);
    expect(summary.allTime.bestDay, isNull);
    expect(summary.trend, ScoreTrend.insufficientData);
  });

  test('device screen-time override never changes posture score', () {
    final records = {
      '2026-07-26': const DailyStats(
        monitoredTimeSeconds: 100,
        badPostureSeconds: 20,
      ),
    };

    final summary = StatisticsSummary.calculate(
      records: records,
      now: DateTime(2026, 7, 26),
      todayDeviceScreenTimeOverride: 10000,
    );

    expect(summary.todayDeviceScreenTimeSeconds, 10000);
    expect(summary.today.dailyScore, 80);
    expect(summary.pastSeven.weightedScore, 80);
  });
}
