import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/functions/posture_check.dart';
import 'package:postureguard/models/posture_thresholds.dart';

void main() {
  group('adaptive posture hysteresis', () {
    final thresholds = calculatePostureThresholds(90);

    test('good remains good above bad threshold and enters at threshold', () {
      final hysteresis = PostureHysteresis();
      expect(hysteresis.update(80, thresholds), isFalse);
      expect(hysteresis.update(63.1, thresholds), isFalse);
      expect(hysteresis.update(63, thresholds), isTrue);
    });

    test('bad remains bad until reaching recovery threshold', () {
      final hysteresis = PostureHysteresis();
      expect(hysteresis.update(60, thresholds), isTrue);
      expect(hysteresis.update(69, thresholds), isTrue);
      expect(hysteresis.update(70.19, thresholds), isTrue);
      expect(hysteresis.update(70.2, thresholds), isFalse);
    });

    test('fluctuations between thresholds do not toggle repeatedly', () {
      final hysteresis = PostureHysteresis();
      expect(hysteresis.update(62, thresholds), isTrue);
      expect(hysteresis.update(65, thresholds), isTrue);
      expect(hysteresis.update(64, thresholds), isTrue);
      expect(hysteresis.update(66, thresholds), isTrue);
      expect(hysteresis.update(71, thresholds), isFalse);
      expect(hysteresis.update(66, thresholds), isFalse);
    });

    test('raising the phone above neutral never causes bad posture', () {
      final hysteresis = PostureHysteresis();
      expect(hysteresis.update(90, thresholds), isFalse);
      expect(hysteresis.update(90, thresholds), isFalse);
    });

    test('invalid samples preserve the previous classification', () {
      final hysteresis = PostureHysteresis();
      expect(hysteresis.update(60, thresholds), isTrue);
      expect(hysteresis.update(double.nan, thresholds), isTrue);
      expect(hysteresis.update(double.infinity, thresholds), isTrue);
    });
  });

  test('phone-angle filter ignores invalid samples and resets stale state', () {
    final filter = PhoneAngleFilter();
    expect(filter.add(80), 80);
    expect(filter.add(double.nan), 80);
    expect(filter.add(double.infinity), 80);
    filter.reset();
    expect(filter.value, isNull);
    expect(filter.add(60), 60);
  });

  test('calibration accepts a realistic mid-range viewing angle', () {
    expect(isValidCalibrationPhoneAngle(30), isTrue);
    expect(stableCalibrationAngle([30, 31, 30, 30, 31]), closeTo(30.333, 0.01));
  });

  test(
    'posture becomes bad when the phone is tilted too far below neutral',
    () {
      final thresholds = calculatePostureThresholds(45);
      final hysteresis = PostureHysteresis();
      expect(hysteresis.update(20, thresholds), isTrue);
      expect(hysteresis.update(40, thresholds), isFalse);
    },
  );

  test('sensor angle is normalized and does not invert with rotation', () {
    final portrait = phoneAngleFromAccelerometer(x: 0, y: 5, z: 5);
    final landscape = phoneAngleFromAccelerometer(x: 5, y: 0, z: 5);
    final upsideDownZ = phoneAngleFromAccelerometer(x: 0, y: 5, z: -5);
    expect(portrait, closeTo(45, 0.001));
    expect(landscape, closeTo(portrait!, 0.001));
    expect(upsideDownZ, closeTo(portrait, 0.001));
    expect(phoneAngleFromAccelerometer(x: 0, y: 0, z: 1), closeTo(0, 0.001));
    expect(phoneAngleFromAccelerometer(x: 1, y: 0, z: 0), closeTo(90, 0.001));
    expect(phoneAngleFromAccelerometer(x: double.nan, y: 0, z: 1), isNull);
    expect(phoneAngleFromAccelerometer(x: 0, y: 0, z: 0), isNull);
  });

  test('posture classification consumes a platform-neutral angle', () {
    final normalizedAngle = phoneAngleFromAccelerometer(x: 0, y: 5, z: 5);
    final thresholds = calculatePostureThresholds(90);
    final hysteresis = PostureHysteresis();

    expect(normalizedAngle, closeTo(45, 0.001));
    expect(hysteresis.update(normalizedAngle!, thresholds), isTrue);
  });

  test(
    'stable calibration accepts reasonable angles and rejects noisy or invalid samples',
    () {
      expect(stableCalibrationAngle([70, 71, 69, 70, 70]), closeTo(70, 0.01));
      expect(
        stableCalibrationAngle([30, 31, 30, 30, 31]),
        closeTo(30.333, 0.01),
      );
      expect(stableCalibrationAngle([60, 70, 80]), isNull);
      expect(stableCalibrationAngle([double.nan, 70]), isNull);
    },
  );

  test('alert scheduler repeats at frequency and resets on good posture', () {
    final scheduler = PostureAlertScheduler();
    final start = DateTime(2026, 1, 1, 12);

    expect(
      scheduler.isDue(
        now: start,
        postureIsBad: true,
        alertsEnabled: true,
        frequencySeconds: 30,
      ),
      isTrue,
    );
    scheduler.markAlertSent(start);
    expect(
      scheduler.isDue(
        now: start.add(const Duration(seconds: 29)),
        postureIsBad: true,
        alertsEnabled: true,
        frequencySeconds: 30,
      ),
      isFalse,
    );
    expect(
      scheduler.isDue(
        now: start.add(const Duration(seconds: 30)),
        postureIsBad: true,
        alertsEnabled: true,
        frequencySeconds: 30,
      ),
      isTrue,
    );
    scheduler.reset();
    expect(scheduler.lastAlert, isNull);
  });

  test('disabled, locked, and temporarily muted alerts stay suppressed', () {
    final scheduler = PostureAlertScheduler();
    final now = DateTime(2026, 7, 26, 12);
    bool due({
      bool alertsEnabled = true,
      bool screenInteractive = true,
      bool temporarilyMuted = false,
    }) => scheduler.isDue(
      now: now,
      postureIsBad: true,
      alertsEnabled: alertsEnabled,
      frequencySeconds: 30,
      screenInteractive: screenInteractive,
      temporarilyMuted: temporarilyMuted,
    );

    expect(due(alertsEnabled: false), isFalse);
    expect(due(screenInteractive: false), isFalse);
    expect(due(temporarilyMuted: true), isFalse);
    expect(due(), isTrue);
  });

  test(
    'reset requires a new first alert rather than retaining repeat state',
    () {
      final scheduler = PostureAlertScheduler();
      final first = DateTime(2026, 7, 26, 12);
      scheduler.markAlertSent(first);
      expect(
        scheduler.isDue(
          now: first.add(const Duration(seconds: 5)),
          postureIsBad: true,
          alertsEnabled: true,
          frequencySeconds: 30,
        ),
        isFalse,
      );
      scheduler.reset();
      expect(
        scheduler.isDue(
          now: first.add(const Duration(seconds: 5)),
          postureIsBad: true,
          alertsEnabled: true,
          frequencySeconds: 30,
        ),
        isTrue,
      );
    },
  );
}
