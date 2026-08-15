import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/models/app_settings.dart';
import 'package:postureguard/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('AppSettings', () {
    test('new users enable monitoring and alerts by default', () {
      expect(AppSettings.defaults.monitoringEnabled, isTrue);
      expect(AppSettings.defaults.alertsEnabled, isTrue);
      expect(AppSettings.defaults.alertDelaySeconds, 10);
      expect(AppSettings.defaults.alertFrequencySeconds, 30);
    });

    test('preserves valid existing Firebase values', () {
      final settings = AppSettings.fromMap({
        'alertDelaySeconds': 30,
        'alertFrequencySeconds': 600,
        'monitoringEnabled': false,
        'alertsEnabled': false,
        'detectionMode': 'phone_orientation_camera',
      });

      expect(settings.alertDelaySeconds, 30);
      expect(settings.alertFrequencySeconds, 600);
      expect(settings.monitoringEnabled, isFalse);
      expect(settings.alertsEnabled, isFalse);
    });

    test('missing Boolean fields use enabled migration defaults', () {
      final settings = AppSettings.fromMap({
        'alertDelaySeconds': 30,
        'alertFrequencySeconds': 60,
      });

      expect(settings.monitoringEnabled, isTrue);
      expect(settings.alertsEnabled, isTrue);
    });

    test('missing cloud fields preserve explicit local false values', () {
      final local = AppSettings.defaults.copyWith(
        monitoringEnabled: false,
        alertsEnabled: false,
      );
      final settings = AppSettings.fromMap(const {}, fallback: local);

      expect(settings.monitoringEnabled, isFalse);
      expect(settings.alertsEnabled, isFalse);
    });

    test('replaces malformed values with safe fallbacks', () {
      final settings = AppSettings.fromMap({
        'alertDelaySeconds': 0,
        'alertFrequencySeconds': -10,
        'alertsEnabled': 'yes',
      });

      expect(settings, AppSettings.defaults);
    });

    test('validates sensible custom ranges', () {
      expect(AppSettings.isValidAlertDelay(5), isTrue);
      expect(AppSettings.isValidAlertDelay(4), isFalse);
      expect(AppSettings.isValidAlertDelay(301), isFalse);
      expect(AppSettings.isValidAlertFrequency(5), isTrue);
      expect(AppSettings.isValidAlertFrequency(0), isFalse);
      expect(AppSettings.isValidAlertFrequency(3601), isFalse);
    });
  });

  test('cached explicit false values survive local loading', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          PreferenceKeys.hasCachedSettings: true,
          PreferenceKeys.monitoringEnabled: false,
          PreferenceKeys.alertDelaySeconds: 10,
          PreferenceKeys.alertFrequencySeconds: 30,
          PreferenceKeys.alertsEnabled: false,
        });

    final settings = await SettingsRepository.loadCachedSettings(
      SharedPreferencesAsync(),
    );

    expect(settings?.monitoringEnabled, isFalse);
    expect(settings?.alertsEnabled, isFalse);
  });
}
