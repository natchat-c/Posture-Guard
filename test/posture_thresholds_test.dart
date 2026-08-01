import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/models/posture_thresholds.dart';

void main() {
  test('neutral 90 uses percentage thresholds', () {
    final thresholds = calculatePostureThresholds(90);
    expect(thresholds.badEnterAngle, closeTo(63, 0.001));
    expect(thresholds.goodExitAngle, closeTo(70.2, 0.001));
  });

  test('neutral 60 preserves the minimum hysteresis gap', () {
    final thresholds = calculatePostureThresholds(60);
    expect(thresholds.badEnterAngle, closeTo(42, 0.001));
    expect(thresholds.goodExitAngle, closeTo(47, 0.001));
  });

  test('neutral 50 uses absolute floor and five-degree recovery gap', () {
    final thresholds = calculatePostureThresholds(50);
    expect(thresholds.badEnterAngle, 35);
    expect(thresholds.goodExitAngle, 40);
  });

  test('valid calibrations always produce safe bounded hysteresis', () {
    for (
      var neutral = minimumCalibrationAngleDegrees;
      neutral <= maximumSensorAngleDegrees;
      neutral += 0.25
    ) {
      final thresholds = calculatePostureThresholds(neutral);
      expect(thresholds.badEnterAngle, greaterThanOrEqualTo(35));
      expect(thresholds.goodExitAngle, greaterThan(thresholds.badEnterAngle));
      expect(thresholds.badEnterAngle, inInclusiveRange(0, 90));
      expect(thresholds.goodExitAngle, inInclusiveRange(0, 90));
    }
  });

  test('out-of-range, NaN, and infinite neutral angles are rejected', () {
    for (final value in [
      -1.0,
      90.1,
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(() => calculatePostureThresholds(value), throwsArgumentError);
    }
  });
}
