import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/models/app_settings.dart';

void main() {
  group('AppSettings', () {
    test('uses 30 seconds as the new-user frequency default', () {
      expect(AppSettings.defaults.alertFrequencySeconds, 30);
    });

    test('preserves valid existing Firebase values', () {
      final settings = AppSettings.fromMap({
        'alertDelaySeconds': 30,
        'alertFrequencySeconds': 600,
        'alertsEnabled': false,
        'detectionMode': 'phone_orientation_camera',
      });

      expect(settings.alertDelaySeconds, 30);
      expect(settings.alertFrequencySeconds, 600);
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
}
