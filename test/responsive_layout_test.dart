import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/l10n/app_localizations.dart';
import 'package:postureguard/models/app_settings.dart';
import 'package:postureguard/pages/customize_page.dart';
import 'package:postureguard/pages/home_page.dart';
import 'package:postureguard/pages/language_selection_page.dart';
import 'package:postureguard/pages/settings_page.dart';
import 'package:postureguard/pages/shop_page.dart';
import 'package:postureguard/pages/statistics_page.dart';
import 'package:postureguard/pages/tutorial_page.dart';
import 'package:postureguard/services/alert_mute_service.dart';
import 'package:postureguard/services/device_screen_time_service.dart';
import 'package:postureguard/services/preferences_service.dart';
import 'package:postureguard/services/statistics_repository.dart';
import 'package:postureguard/widgets/coach_mark_overlay.dart';
import 'package:postureguard/widgets/no_stretch_scroll_behavior.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _targetSizes = <Size>[
  Size(320, 568),
  Size(360, 640),
  Size(360, 800),
  Size(390, 844),
  Size(412, 915),
  Size(430, 932),
];

const _locales = <Locale>[Locale('en'), Locale('th')];

class _MemorySettingsStore implements SettingsStore {
  _MemorySettingsStore(this.settings);

  AppSettings settings;

  @override
  Future<SettingsLoadResult> load() async {
    return SettingsLoadResult(settings: settings);
  }

  @override
  Future<SettingsSaveResult> save(AppSettings value) async {
    settings = value;
    return const SettingsSaveResult(savedLocally: true, savedToFirebase: true);
  }
}

class _NoScreenTimeProvider extends DeviceScreenTimeProvider {
  @override
  Future<bool> isSupported() async => false;

  @override
  Future<bool> hasUsageAccess() async => false;

  @override
  Future<bool> openUsageAccessSettings() async => false;

  @override
  Future<int?> getScreenTimeSeconds({
    required DateTime start,
    required DateTime end,
  }) async => null;
}

class _MemoryMuteStore implements AlertMuteStore {
  int? value;

  @override
  Future<int?> readMutedUntilEpochMs() async => value;

  @override
  Future<void> writeMutedUntilEpochMs(int? epochMs) async => value = epochMs;
}

Widget _testApp({
  required Widget home,
  required Locale locale,
  double textScale = 1,
  EdgeInsets systemPadding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    scrollBehavior: const NoStretchScrollBehavior(),
    builder: (context, child) {
      final mediaQuery = MediaQuery.of(context);
      return MediaQuery(
        data: mediaQuery.copyWith(
          textScaler: TextScaler.linear(textScale),
          padding: systemPadding,
          viewPadding: systemPadding,
          viewInsets: viewInsets,
        ),
        child: child!,
      );
    },
    home: home,
  );
}

Future<void> _pumpAt(
  WidgetTester tester, {
  required Size size,
  required Locale locale,
  required Widget home,
  double textScale = 1,
  EdgeInsets systemPadding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    _testApp(
      home: home,
      locale: locale,
      textScale: textScale,
      systemPadding: systemPadding,
      viewInsets: viewInsets,
    ),
  );
  await tester.pumpAndSettle();
  expect(
    tester.takeException(),
    isNull,
    reason:
        '${home.runtimeType} overflowed at '
        '${size.width}x${size.height}, ${locale.languageCode}, $textScale x',
  );
}

void _expectInsideViewport(
  WidgetTester tester,
  Finder finder,
  Size size, {
  EdgeInsets insets = EdgeInsets.zero,
}) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(insets.left - 0.1));
  expect(rect.top, greaterThanOrEqualTo(insets.top - 0.1));
  expect(rect.right, lessThanOrEqualTo(size.width - insets.right + 0.1));
  expect(rect.bottom, lessThanOrEqualTo(size.height - insets.bottom + 0.1));
}

Settings _settings({AppSettings settings = AppSettings.defaults}) {
  return Settings(
    store: _MemorySettingsStore(settings),
    onCalibrateNeutral: () async => true,
    screenTimeProvider: _NoScreenTimeProvider(),
    alertMuteController: AlertMuteController(
      store: _MemoryMuteStore(),
      clock: () => DateTime(2026, 8, 1, 12),
    ),
    loadNotificationPermission: () async => NotificationPermission.denied,
    requestNotificationPermission: () async => NotificationPermission.denied,
  );
}

Statistics _statistics() {
  return Statistics(
    recordsStream: Stream.value(const <String, DailyStats>{
      '2026-07-29': DailyStats(
        monitoredTimeSeconds: 1800,
        badPostureSeconds: 360,
        alertsSentCount: 1,
      ),
      '2026-08-01': DailyStats(
        monitoredTimeSeconds: 3600,
        badPostureSeconds: 900,
        alertsSentCount: 3,
      ),
    }),
    screenTimeProvider: _NoScreenTimeProvider(),
    clock: () => DateTime(2026, 8, 1, 12),
  );
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('Home fits every target viewport, locale, and posture state', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in _targetSizes) {
      for (final locale in _locales) {
        for (final scenario in const [
          (status: 'GOOD', monitoringActive: true),
          (status: 'WARNING', monitoringActive: true),
          (status: 'BAD', monitoringActive: true),
          (status: 'OFF', monitoringActive: false),
        ]) {
          await _pumpAt(
            tester,
            size: size,
            locale: locale,
            home: MyHomePage(
              key: ValueKey(
                '${size.width}-${locale.languageCode}-${scenario.status}',
              ),
              testMode: true,
              initialPostureStatus: scenario.status,
              initialMonitoringActive: scenario.monitoringActive,
            ),
          );

          final home = find.byKey(const Key('homeLayout'));
          expect(home, findsOneWidget);
          expect(
            find.descendant(of: home, matching: find.byType(Scrollable)),
            findsNothing,
          );
          expect(find.byKey(const Key('homeCoinBalance')), findsOneWidget);
          expect(find.byKey(const Key('homeHelpButton')), findsOneWidget);
          expect(find.byKey(const Key('homeSettingsButton')), findsOneWidget);
          expect(find.byKey(const Key('homeCustomizeButton')), findsOneWidget);
          expect(find.byKey(const Key('homeStatisticsButton')), findsOneWidget);

          final statusText = tester.widget<Text>(
            find.byKey(const Key('homePostureStatus')),
          );
          expect(statusText.style?.fontSize, lessThanOrEqualTo(40));
          expect(statusText.style?.fontSize, greaterThanOrEqualTo(32));
          if (!scenario.monitoringActive) {
            expect(
              statusText.data,
              locale.languageCode == 'th'
                  ? 'ปิดการตรวจท่าทางแล้ว'
                  : 'Monitoring is off',
            );
          }

          final topRect = tester.getRect(
            find.byKey(const Key('homeTopControls')),
          );
          final bottomRect = tester.getRect(
            find.byKey(const Key('homeBottomActions')),
          );
          expect(topRect.center.dy, lessThan(size.height / 2));
          expect(bottomRect.center.dy, greaterThan(size.height / 2));
          _expectInsideViewport(
            tester,
            find.byKey(const Key('homeBottomActions')),
            size,
          );

          final artwork = tester.getRect(
            find.byKey(const Key('homeCharacterArtwork')),
          );
          expect(artwork.width, greaterThan(24));
          expect(artwork.width / artwork.height, closeTo(765 / 611, 0.02));
          expect(artwork.height, lessThanOrEqualTo(size.height * 0.42));
          expect(artwork.center.dx, closeTo(size.width / 2, 0.5));

          final headingRect = tester.getRect(
            find.byKey(const Key('homeStatusHeading')),
          );
          final statusRect = tester.getRect(
            find.byKey(const Key('homePostureStatus')),
          );
          final scoreRect = tester.getRect(find.byKey(const Key('homeScore')));
          final metricsRect = tester.getRect(
            find.byKey(const Key('homeTimeMetrics')),
          );
          expect(headingRect.bottom, lessThanOrEqualTo(statusRect.top));
          expect(statusRect.bottom, lessThanOrEqualTo(scoreRect.top));
          if (scenario.monitoringActive) {
            final helperRect = tester.getRect(
              find.byKey(const Key('homePostureHint')),
            );
            expect(scoreRect.bottom, lessThanOrEqualTo(helperRect.top));
            expect(helperRect.bottom, lessThanOrEqualTo(artwork.top));
            // The portrait layout combines up to 15 px of section spacing
            // with up to 15 px of intentional slime artwork offset.
            expect(artwork.top - helperRect.bottom, lessThanOrEqualTo(30));
          } else {
            expect(scoreRect.bottom, lessThanOrEqualTo(artwork.top));
            expect(artwork.top - scoreRect.bottom, lessThanOrEqualTo(30));
          }
          expect(artwork.bottom, lessThanOrEqualTo(metricsRect.top));
          // Home deliberately combines up to 30 px of responsive metric
          // offset with a maximum 12 px section gap.
          expect(metricsRect.top - artwork.bottom, inInclusiveRange(0, 42));

          final customizeRect = tester.getRect(
            find.byKey(const Key('homeCustomizeButton')),
          );
          final statisticsRect = tester.getRect(
            find.byKey(const Key('homeStatisticsButton')),
          );
          expect(customizeRect.height, closeTo(statisticsRect.height, 0.1));
          expect(
            customizeRect.center.dy,
            closeTo(statisticsRect.center.dy, 0.1),
          );
        }
      }
    }
  });

  testWidgets('Home preserves essential controls at larger text scales', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final scale in const [1.3, 1.5]) {
      for (final locale in _locales) {
        await _pumpAt(
          tester,
          size: const Size(320, 568),
          locale: locale,
          textScale: scale,
          systemPadding: const EdgeInsets.fromLTRB(0, 28, 0, 24),
          home: MyHomePage(
            key: ValueKey('$scale-${locale.languageCode}'),
            testMode: true,
            initialPostureStatus: 'WARNING',
          ),
        );
        _expectInsideViewport(
          tester,
          find.byKey(const Key('homeTopControls')),
          const Size(320, 568),
          insets: const EdgeInsets.only(top: 28),
        );
        _expectInsideViewport(
          tester,
          find.byKey(const Key('homeBottomActions')),
          const Size(320, 568),
          insets: const EdgeInsets.only(bottom: 24),
        );
        final artwork = tester.getRect(
          find.byKey(const Key('homeCharacterArtwork')),
        );
        expect(artwork.height, greaterThanOrEqualTo(80));
        final customize = tester.getRect(
          find.byKey(const Key('homeCustomizeButton')),
        );
        final statistics = tester.getRect(
          find.byKey(const Key('homeStatisticsButton')),
        );
        expect(customize.height, closeTo(statistics.height, 0.1));
      }
    }
  });

  testWidgets('persistent action pages fit the full size and locale matrix', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in _targetSizes) {
      for (final locale in _locales) {
        await _pumpAt(
          tester,
          size: size,
          locale: locale,
          home: const Customizes(),
        );
        expect(find.byKey(const Key('customizeScrollView')), findsOneWidget);
        _expectInsideViewport(
          tester,
          find.byKey(const Key('customizeBottomAction')),
          size,
        );
        final customizeArtwork = tester.getRect(
          find.byKey(const Key('customizeCharacterArtwork')),
        );
        expect(customizeArtwork.width, closeTo(customizeArtwork.height, 0.1));

        await _pumpAt(tester, size: size, locale: locale, home: const Shop());
        expect(find.byKey(const Key('shopScrollView')), findsOneWidget);
        _expectInsideViewport(
          tester,
          find.byKey(const Key('shopCoinBalance')),
          size,
        );
        expect(find.byKey(const Key('gachaBox-standard')), findsOneWidget);
        expect(find.byKey(const Key('gachaBox-premium')), findsOneWidget);
        expect(find.byKey(const Key('shopBuyButton')), findsNothing);

        await _pumpAt(
          tester,
          size: size,
          locale: locale,
          home: const Customizes(showGuidedTour: true),
        );
        _expectInsideViewport(
          tester,
          find.byKey(const Key('coachMarkCard')),
          size,
        );
        expect(find.byKey(const Key('customize-hat-list')), findsOneWidget);

        await _pumpAt(
          tester,
          size: size,
          locale: locale,
          home: const Shop(showGuidedTour: true),
        );
        _expectInsideViewport(
          tester,
          find.byKey(const Key('coachMarkCard')),
          size,
        );
        expect(find.byKey(const Key('odds-help-standard')), findsOneWidget);

        await _pumpAt(
          tester,
          size: size,
          locale: locale,
          home: LanguageSelectionPage(onLanguageSelected: (_) async {}),
        );
        expect(
          find.byKey(const Key('languageSelectionScrollView')),
          findsOneWidget,
        );
        _expectInsideViewport(
          tester,
          find.byKey(const Key('languageBottomAction')),
          size,
        );
      }
    }
  });

  testWidgets('gacha odds dialogs fit the portrait locale matrix', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in _targetSizes) {
      for (final locale in _locales) {
        await _pumpAt(tester, size: size, locale: locale, home: const Shop());
        for (final type in const ['standard', 'premium']) {
          final help = find.byKey(Key('odds-help-$type'));
          await tester.ensureVisible(help);
          await tester.pumpAndSettle();
          await tester.tap(help);
          await tester.pumpAndSettle();
          _expectInsideViewport(
            tester,
            find.byKey(Key('oddsDialog-$type')),
            size,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(Key('close-$type-odds')));
          await tester.pumpAndSettle();
        }
      }
    }
  });

  testWidgets('Settings and Statistics fit and scroll across the matrix', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in _targetSizes) {
      for (final locale in _locales) {
        await _pumpAt(tester, size: size, locale: locale, home: _settings());
        expect(find.byKey(const Key('settingsScrollView')), findsOneWidget);
        _expectInsideViewport(
          tester,
          find.byKey(const Key('settingsBottomAction')),
          size,
        );

        await _pumpAt(tester, size: size, locale: locale, home: _statistics());
        expect(find.byKey(const Key('statisticsScrollView')), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const Key('statisticsScoreChart')),
        );
        await tester.pumpAndSettle();
        _expectInsideViewport(
          tester,
          find.byKey(const Key('statisticsScoreChart')),
          size,
        );
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('Settings keyboard inset and narrow Statistics cards reflow', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAt(
      tester,
      size: const Size(320, 568),
      locale: const Locale('th'),
      textScale: 1.3,
      viewInsets: const EdgeInsets.only(bottom: 220),
      home: _settings(
        settings: const AppSettings(
          monitoringEnabled: true,
          alertDelaySeconds: 77,
          alertFrequencySeconds: 123,
          alertsEnabled: true,
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('customFrequencyField')));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('customFrequencyField'))).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const Key('settingsBottomAction'))).top,
      ),
    );
    expect(tester.takeException(), isNull);

    await _pumpAt(
      tester,
      size: const Size(320, 568),
      locale: const Locale('th'),
      textScale: 1.5,
      home: _statistics(),
    );
    final todayCard = find.byKey(const Key('statisticsTodaySummary'));
    expect(todayCard, findsOneWidget);
    expect(
      find.descendant(of: todayCard, matching: find.byType(Row)),
      findsNothing,
    );
    for (final key in const [
      Key('statisticsTodaySummary'),
      Key('statisticsSevenDaySummary'),
      Key('statisticsAllTimeSummary'),
    ]) {
      final section = find.byKey(key);
      expect(section, findsOneWidget);
      expect(
        find.descendant(of: section, matching: find.byType(Card)),
        findsNothing,
      );
    }
    expect(find.byKey(const Key('statisticsTodayScore')), findsOneWidget);
    expect(find.byKey(const Key('statisticsScoreChart')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const Key('statisticsScoreChart')),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('statisticsTrendComparison')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding and tutorial fit every target size and locale', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in _targetSizes) {
      for (final locale in _locales) {
        await _pumpAt(
          tester,
          size: size,
          locale: locale,
          textScale: size.width == 320 ? 1.5 : 1.3,
          home: const TutorialPage(),
        );
        expect(find.byKey(const Key('tutorialPageView')), findsOneWidget);
        expect(find.byKey(const Key('tutorialPageScroll0')), findsOneWidget);
        _expectInsideViewport(
          tester,
          find.byKey(const Key('tutorialBottomActions')),
          size,
        );
        _expectInsideViewport(
          tester,
          find.byKey(const Key('tutorialNextButton')),
          size,
        );
      }
    }
  });

  testWidgets('coach marks stay inside system insets above and below targets', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const size = Size(320, 568);
    const insets = EdgeInsets.fromLTRB(0, 28, 0, 24);

    for (final locale in _locales) {
      for (final target in const [
        Rect.fromLTWH(24, 64, 44, 44),
        Rect.fromLTWH(250, 468, 44, 44),
      ]) {
        await _pumpAt(
          tester,
          size: size,
          locale: locale,
          textScale: 1.5,
          systemPadding: insets,
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fromRect(
                  rect: target,
                  child: const ColoredBox(color: Colors.blue),
                ),
                Positioned.fill(
                  child: CoachMarkOverlay(
                    target: target,
                    title: locale.languageCode == 'th'
                        ? 'คำแนะนำการใช้งาน'
                        : 'How to use this control',
                    body: locale.languageCode == 'th'
                        ? 'ข้อความอธิบายที่ยาวขึ้นต้องเลื่อนอ่านได้โดยปุ่มยังมองเห็น'
                        : 'Longer explanatory copy can scroll while actions stay visible.',
                    currentStep: 1,
                    totalSteps: 5,
                    backLabel: locale.languageCode == 'th'
                        ? 'ย้อนกลับ'
                        : 'Back',
                    nextLabel: locale.languageCode == 'th' ? 'ถัดไป' : 'Next',
                    skipLabel: locale.languageCode == 'th' ? 'ข้าม' : 'Skip',
                    onBack: () {},
                    onNext: () {},
                    onSkip: () {},
                  ),
                ),
              ],
            ),
          ),
        );
        _expectInsideViewport(
          tester,
          find.byKey(const Key('coachMarkCard')),
          size,
          insets: insets,
        );
        _expectInsideViewport(
          tester,
          find.byKey(const Key('coachMarkActions')),
          size,
          insets: insets,
        );
      }
    }
  });

  testWidgets('current landscape support does not overflow or hide actions', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const size = Size(844, 390);

    for (final locale in _locales) {
      await _pumpAt(
        tester,
        size: size,
        locale: locale,
        home: MyHomePage(
          key: ValueKey('landscape-${locale.languageCode}'),
          testMode: true,
          initialPostureStatus: 'WARNING',
        ),
      );
      _expectInsideViewport(
        tester,
        find.byKey(const Key('homeBottomActions')),
        size,
      );

      for (final page in <Widget>[
        const Customizes(),
        const Shop(),
        LanguageSelectionPage(onLanguageSelected: (_) async {}),
        _settings(),
        _statistics(),
        const TutorialPage(),
      ]) {
        await _pumpAt(tester, size: size, locale: locale, home: page);
      }
    }
  });
}
