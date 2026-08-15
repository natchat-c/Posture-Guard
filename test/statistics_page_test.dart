import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/l10n/app_localizations.dart';
import 'package:postureguard/pages/statistics_page.dart';
import 'package:postureguard/services/device_screen_time_service.dart';
import 'package:postureguard/services/statistics_repository.dart';

class _ScreenTimeProvider extends DeviceScreenTimeProvider {
  const _ScreenTimeProvider({required this.available, this.seconds});

  final bool available;
  final int? seconds;

  @override
  Future<bool> isSupported() async => available;

  @override
  Future<bool> hasUsageAccess() async => available;

  @override
  Future<bool> openUsageAccessSettings() async => available;

  @override
  Future<int?> getScreenTimeSeconds({
    required DateTime start,
    required DateTime end,
  }) async => seconds;
}

const _today = DailyStats(
  monitoredTimeSeconds: 3600,
  badPostureSeconds: 900,
  alertsSentCount: 3,
);

Map<String, DailyStats> _records({DailyStats today = _today}) => {
  '2026-08-08': const DailyStats(
    monitoredTimeSeconds: 1000,
    badPostureSeconds: 500,
  ),
  '2026-08-14': const DailyStats(
    monitoredTimeSeconds: 600,
    badPostureSeconds: 60,
    alertsSentCount: 1,
  ),
  '2026-08-15': today,
};

Widget _app({
  required Map<String, DailyStats> records,
  DeviceScreenTimeProvider provider = const _ScreenTimeProvider(
    available: false,
  ),
}) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Statistics(
      recordsStream: Stream.value(records),
      screenTimeProvider: provider,
      clock: () => DateTime(2026, 8, 15, 12),
    ),
  );
}

Finder _within(Key sectionKey, String text) {
  return find.descendant(of: find.byKey(sectionKey), matching: find.text(text));
}

void main() {
  testWidgets(
    'Today shows score, balance, durations, alerts, and screen time',
    (tester) async {
      await tester.pumpWidget(
        _app(
          records: _records(),
          provider: const _ScreenTimeProvider(available: true, seconds: 7200),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('75%'), findsNWidgets(2));
      expect(
        find.byKey(const Key('statisticsTodayDescription')),
        findsOneWidget,
      );
      expect(find.text('Good'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('statisticsGoodPercent')))
            .data,
        '75%',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('statisticsBadPercent'))).data,
        '25%',
      );
      expect(
        _within(const Key('statisticsTodaySummary'), '2h 0m'),
        findsOneWidget,
      );
      expect(
        _within(const Key('statisticsTodaySummary'), '1h 0m'),
        findsOneWidget,
      );
      expect(
        _within(const Key('statisticsTodaySummary'), '45m 0s'),
        findsOneWidget,
      );
      expect(
        _within(const Key('statisticsTodaySummary'), '15m 0s'),
        findsOneWidget,
      );
      expect(_within(const Key('statisticsTodaySummary'), '3'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'unavailable device screen time falls back to monitored metrics',
    (tester) async {
      await tester.pumpWidget(_app(records: _records()));
      await tester.pumpAndSettle();

      final todaySummary = find.byKey(const Key('statisticsTodaySummary'));
      expect(
        find.descendant(of: todaySummary, matching: find.text('Screen time')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: todaySummary,
          matching: find.text('Monitored time'),
        ),
        findsOneWidget,
      );
      expect(
        _within(const Key('statisticsTodaySummary'), '1h 0m'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('zero monitored time uses intentional empty states', (
    tester,
  ) async {
    await tester.pumpWidget(_app(records: const <String, DailyStats>{}));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsOneWidget);
    expect(
      find.byKey(const Key('statisticsTodayBalanceEmpty')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('statisticsEmptyTitle')), findsOneWidget);
    expect(find.byKey(const Key('statisticsScoreChart')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('seven-day chart is fixed to 0–100 with seven distinct days', (
    tester,
  ) async {
    await tester.pumpWidget(_app(records: _records()));
    await tester.pumpAndSettle();

    final chart = tester.widget<BarChart>(
      find.byKey(const Key('statisticsSevenDayBarChart')),
    );
    expect(chart.data.minY, 0);
    expect(chart.data.maxY, 100);
    expect(chart.data.barGroups, hasLength(7));
    expect(chart.data.barGroups[0].barRods.single.color, Colors.transparent);
    expect(chart.data.barGroups.last.barRods.single.toY, 75);
    expect(
      chart.data.barGroups.last.barRods.single.color,
      Theme.of(
        tester.element(find.byKey(const Key('statisticsSevenDayBarChart'))),
      ).colorScheme.primary,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'All Time displays existing weighted totals and qualifying best day',
    (tester) async {
      await tester.pumpWidget(_app(records: _records()));
      await tester.pumpAndSettle();

      const section = Key('statisticsAllTimeSummary');
      expect(_within(section, '3'), findsOneWidget);
      expect(_within(section, '72%'), findsOneWidget);
      expect(_within(section, '1h 26m'), findsOneWidget);
      expect(_within(section, '1h 2m'), findsOneWidget);
      expect(_within(section, '24m 20s'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(section),
          matching: find.textContaining('90% ·'),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
