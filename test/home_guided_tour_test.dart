import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/l10n/app_localizations.dart';
import 'package:postureguard/models/app_settings.dart';
import 'package:postureguard/pages/home_page.dart';
import 'package:postureguard/services/device_screen_time_service.dart';
import 'package:postureguard/services/preferences_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _TourSettingsStore implements SettingsStore {
  AppSettings settings = AppSettings.defaults;

  @override
  Future<SettingsLoadResult> load() async =>
      SettingsLoadResult(settings: settings);

  @override
  Future<SettingsSaveResult> save(AppSettings value) async {
    settings = value;
    return const SettingsSaveResult(savedLocally: true, savedToFirebase: true);
  }
}

class _UnsupportedScreenTime extends DeviceScreenTimeProvider {
  const _UnsupportedScreenTime();

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

Widget _homeApp({Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: MyHomePage(
      testMode: true,
      showTourOnStart: true,
      settingsStore: _TourSettingsStore(),
      screenTimeProvider: const _UnsupportedScreenTime(),
    ),
  );
}

Future<void> _tapTourNext(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('settingsTourNextButton')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('guided sequence uses the real Home and Settings controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_homeApp());
    await tester.pumpAndSettle();

    final home = find.byKey(const Key('homeLayout'));
    expect(home, findsOneWidget);
    expect(
      find.descendant(of: home, matching: find.byType(Scrollable)),
      findsNothing,
    );
    expect(find.text('Open Settings'), findsOneWidget);
    expect(find.byKey(const Key('homeTourNextButton')), findsNothing);

    await tester.tap(find.byKey(const Key('homeSettingsButton')));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Turn posture tracking on or off.'), findsOneWidget);

    await _tapTourNext(tester);
    expect(
      find.text('Choose whether you want posture reminders.'),
      findsOneWidget,
    );
    await _tapTourNext(tester);
    expect(
      find.text('Choose how long Posture Guard waits before reminding you.'),
      findsOneWidget,
    );
    await _tapTourNext(tester);
    expect(find.text('Choose how often reminders repeat.'), findsOneWidget);
    await _tapTourNext(tester);
    expect(
      find.text('Set the phone position you normally use.'),
      findsOneWidget,
    );
    await _tapTourNext(tester);
    expect(find.text('Change between English and Thai.'), findsOneWidget);
    await _tapTourNext(tester);

    expect(find.text('Earn coins'), findsOneWidget);
    expect(find.byKey(const Key('homeCoinBalance')), findsOneWidget);
    await tester.tap(find.byKey(const Key('homeTourNextButton')));
    await tester.pumpAndSettle();

    expect(find.text('Need help again?'), findsOneWidget);
    expect(find.byKey(const Key('homeHelpButton')), findsOneWidget);
    await tester.tap(find.byKey(const Key('homeTourNextButton')));
    await tester.pumpAndSettle();
    expect(find.text("You're ready"), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back and Skip do not change settings or create overlays', (
    tester,
  ) async {
    await tester.pumpWidget(_homeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('homeTourBackButton')));
    await tester.pumpAndSettle();
    expect(find.text('Know your posture'), findsOneWidget);

    await tester.tap(find.byKey(const Key('homeTourSkipButton')));
    await tester.pumpAndSettle();
    expect(find.text('Know your posture'), findsNothing);

    await tester.tap(find.byKey(const Key('homeHelpButton')));
    await tester.pumpAndSettle();
    expect(find.text('Know your posture'), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Thai coach marks fit a phone-sized viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.25;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_homeApp(locale: const Locale('th')));
    await tester.pumpAndSettle();

    expect(find.text('เปิดการตั้งค่า'), findsOneWidget);
    expect(find.text('ไว้ทีหลัง'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
