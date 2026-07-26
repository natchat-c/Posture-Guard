import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/models/statistics_live_presentation.dart';
import 'package:postureguard/models/statistics_summary.dart';
import 'package:postureguard/services/statistics_repository.dart';

void main() {
  test('today and every aggregate containing today advance live', () {
    final live = StatisticsLivePresentation(dateKey: '2026-07-26')
      ..reconcile({
        '2026-07-25': const DailyStats(
          monitoredTimeSeconds: 100,
          badPostureSeconds: 20,
        ),
        '2026-07-26': const DailyStats(
          monitoredTimeSeconds: 10,
          badPostureSeconds: 2,
          deviceScreenTimeSeconds: 20,
        ),
      });

    live.advance(
      now: DateTime(2026, 7, 26, 12),
      trackingActive: true,
      screenInteractive: true,
      postureStatus: 'BAD',
      incrementDeviceScreenTime: true,
    );
    live.recordAlertSent();
    final summary = StatisticsSummary.calculate(
      records: live.records,
      now: DateTime(2026, 7, 26, 12),
      todayDeviceScreenTimeOverride: live.deviceScreenTimeSeconds,
    );

    expect(summary.today.monitoredTimeSeconds, 11);
    expect(summary.today.badPostureSeconds, 3);
    expect(summary.todayDeviceScreenTimeSeconds, 21);
    expect(summary.today.alertsSentCount, 1);
    expect(summary.pastSeven.totalMonitoredSeconds, 111);
    expect(summary.pastSeven.totalBadSeconds, 23);
    expect(summary.allTime.totalMonitoredSeconds, 111);
    expect(
      summary.scoresForPastSevenDays(live.records).last,
      closeTo(72.7, 0.1),
    );
  });

  test('good and bad presentation seconds follow the current posture', () {
    final live = StatisticsLivePresentation(dateKey: '2026-07-26')
      ..reconcile({
        '2026-07-26': const DailyStats(
          monitoredTimeSeconds: 10,
          badPostureSeconds: 2,
        ),
      });

    live.advance(
      now: DateTime(2026, 7, 26, 12),
      trackingActive: true,
      screenInteractive: true,
      postureStatus: 'GOOD',
      incrementDeviceScreenTime: false,
    );
    expect(live.records['2026-07-26']!.goodPostureSeconds, 9);
    expect(live.records['2026-07-26']!.badPostureSeconds, 2);

    live.advance(
      now: DateTime(2026, 7, 26, 12, 0, 1),
      trackingActive: true,
      screenInteractive: true,
      postureStatus: 'BAD',
      incrementDeviceScreenTime: false,
    );
    expect(live.records['2026-07-26']!.badPostureSeconds, 3);
  });

  test('locked screen freezes all monitored posture values', () {
    final live = StatisticsLivePresentation(dateKey: '2026-07-26')
      ..monitoredSeconds = 50
      ..badPostureSeconds = 10
      ..deviceScreenTimeSeconds = 100;

    live.advance(
      now: DateTime(2026, 7, 26, 12),
      trackingActive: true,
      screenInteractive: false,
      postureStatus: 'BAD',
      incrementDeviceScreenTime: true,
    );

    expect(live.monitoredSeconds, 50);
    expect(live.badPostureSeconds, 10);
    expect(live.deviceScreenTimeSeconds, 100);
  });

  test(
    'authoritative snapshots reconcile without rolling display backward',
    () {
      final live = StatisticsLivePresentation(dateKey: '2026-07-26')
        ..monitoredSeconds = 105
        ..badPostureSeconds = 20;

      live.reconcile({
        '2026-07-26': const DailyStats(
          monitoredTimeSeconds: 102,
          badPostureSeconds: 19,
          alertsSentCount: 1,
        ),
      });

      expect(live.monitoredSeconds, 105);
      expect(live.badPostureSeconds, 20);
      expect(live.records['2026-07-26']!.alertsSentCount, 1);
    },
  );

  test('midnight resets live day and excludes yesterday presentation', () {
    final live = StatisticsLivePresentation(dateKey: '2026-12-31')
      ..monitoredSeconds = 100
      ..badPostureSeconds = 20
      ..deviceScreenTimeSeconds = 200;

    final changed = live.advance(
      now: DateTime(2027, 1, 1),
      trackingActive: true,
      screenInteractive: true,
      postureStatus: 'BAD',
      incrementDeviceScreenTime: true,
    );

    expect(changed, isTrue);
    expect(live.dateKey, '2027-01-01');
    expect(live.monitoredSeconds, 0);
    expect(live.badPostureSeconds, 0);
    expect(live.deviceScreenTimeSeconds, isNull);
  });
}
