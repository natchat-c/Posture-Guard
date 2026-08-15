import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/l10n/app_localizations.dart';
import 'package:postureguard/l10n/app_localizations_en.dart';
import 'package:postureguard/l10n/app_localizations_th.dart';
import 'package:postureguard/l10n/locale_controller.dart';
import 'package:postureguard/main.dart';
import 'package:postureguard/models/app_settings.dart';
import 'package:postureguard/pages/settings_page.dart';
import 'package:postureguard/services/device_screen_time_service.dart';
import 'package:postureguard/services/notification_service.dart';
import 'package:postureguard/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _LocalSettingsStore implements SettingsStore {
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

Widget _localizedSettingsApp(
  LocaleController controller,
  _LocalSettingsStore store,
) {
  return AnimatedBuilder(
    animation: controller,
    builder: (context, _) => LocaleScope(
      controller: controller,
      child: MaterialApp(
        locale: controller.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Settings(
          store: store,
          onCalibrateNeutral: () async => true,
          loadMonitoringState: () async => true,
          screenTimeProvider: const _UnsupportedScreenTime(),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'English and Thai catalogs load while the product name stays English',
    () {
      final english = AppLocalizationsEn();
      final thai = AppLocalizationsTh();

      expect(english.settings, 'Settings');
      expect(thai.settings, 'การตั้งค่า');
      expect(english.appTitle, 'Posture Guard');
      expect(thai.appTitle, 'Posture Guard');
      expect(english.cameraAndPrivacy, 'Privacy & PDPA');
      expect(thai.cameraAndPrivacy, 'ความเป็นส่วนตัวและ PDPA');
      expect(english.cameraExplanationTitle, 'Camera assistance');
      expect(thai.cameraExplanationTitle, 'การช่วยตรวจท่าด้วยกล้อง');
    },
  );

  test('selected language persists and restores device-locally', () async {
    final preferences = LanguagePreferences(
      preferences: SharedPreferencesAsync(),
    );
    expect(await preferences.load(), isNull);
    await preferences.save('th');

    final restored = LanguagePreferences(preferences: SharedPreferencesAsync());
    expect(await restored.load(), 'th');
  });

  testWidgets('saved Thai opens privacy then the first tutorial in Thai', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          PreferenceKeys.selectedLanguageCode: 'th',
        });

    await tester.pumpWidget(const MyApp(initialTutorialCompleted: false));
    await tester.pumpAndSettle();

    expect(find.text('เลือกภาษา'), findsNothing);
    expect(
      find.byKey(const Key('privacyNoticeSensorsOnlyButton')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('privacyNoticeSensorsOnlyButton')));
    await tester.pumpAndSettle();
    expect(find.text('ยินดีต้อนรับสู่ Posture Guard'), findsOneWidget);
  });

  testWidgets(
    'Settings changes language immediately without changing settings',
    (tester) async {
      final store = _LocalSettingsStore();
      final controller = LocaleController(initialCode: 'en');
      addTearDown(controller.dispose);
      final original = store.settings;

      await tester.pumpWidget(_localizedSettingsApp(controller, store));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);

      await tester.tap(find.byKey(const Key('languageSelector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ไทย').last);
      await tester.pumpAndSettle();

      expect(find.text('การตั้งค่า'), findsOneWidget);
      expect(controller.selectedLanguageCode, 'th');
      expect(store.settings, original);
    },
  );

  test('Thai notification labels keep stable action identifiers', () {
    final actions = PostureNotificationService.postureAlertActionsForLanguage(
      'th',
    );
    expect(actions[0].id, PostureNotificationService.mute15MinutesActionId);
    expect(actions[1].id, PostureNotificationService.mute1HourActionId);
    expect(actions[0].title, 'ปิด 15 นาที');
    expect(actions[1].title, 'ปิด 1 ชั่วโมง');
  });

  test('English and Thai notification payloads are short and exact', () {
    final english = PostureNotificationService.contentForLanguage('en');
    final thai = PostureNotificationService.contentForLanguage('th');

    expect(english.title, 'Check your posture');
    expect(english.body, 'Adjust your position.');
    expect(english.mute15MinutesLabel, 'Mute 15 min');
    expect(english.mute1HourLabel, 'Mute 1 hour');
    expect(thai.title, 'เช็กท่าทาง');
    expect(thai.body, 'ลองปรับท่าทาง');
    expect(thai.mute15MinutesLabel, 'ปิด 15 นาที');
    expect(thai.mute1HourLabel, 'ปิด 1 ชั่วโมง');
  });

  test('background payload reloads the latest saved language', () async {
    final preferences = LanguagePreferences(
      preferences: SharedPreferencesAsync(),
    );
    await preferences.save('en');
    final english = await PostureNotificationService.loadContent(
      languagePreferences: preferences,
    );

    await preferences.save('th');
    final thai = await PostureNotificationService.loadContent(
      languagePreferences: preferences,
    );

    expect(english.title, 'Check your posture');
    expect(thai.title, 'เช็กท่าทาง');
    expect(thai.body, 'ลองปรับท่าทาง');
  });

  test('language changes retain one stable notification channel', () {
    final english = PostureNotificationService.contentForLanguage('en');
    final thai = PostureNotificationService.contentForLanguage('th');

    expect(english.channelId, PostureNotificationService.postureAlertChannelId);
    expect(thai.channelId, english.channelId);
  });

  test('foreground notification wording is localized and compact', () {
    expect(
      PostureNotificationService.foregroundTextForLanguage(
        languageCode: 'en',
        screenInteractive: true,
      ),
      (title: 'Posture Guard is active', body: 'Monitoring posture'),
    );
    expect(
      PostureNotificationService.foregroundTextForLanguage(
        languageCode: 'th',
        screenInteractive: false,
      ),
      (title: 'Posture Guard กำลังทำงาน', body: 'หยุดชั่วคราวขณะปิดหน้าจอ'),
    );
  });
}
