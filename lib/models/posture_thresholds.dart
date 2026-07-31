import 'dart:math' as math;

const double badAngleRatio = 0.70;
const double goodAngleRatio = 0.78;
const double minimumBadAngleDegrees = 35.0;
const double hysteresisMinimumDegrees = 5.0;
const double minimumCalibrationAngleDegrees = 0.0;
const double minimumSensorAngleDegrees = 0.0;
const double maximumSensorAngleDegrees = 90.0;

class PostureThresholds {
  const PostureThresholds({
    required this.badEnterAngle,
    required this.goodExitAngle,
  });

  final double badEnterAngle;
  final double goodExitAngle;
}

bool isValidSensorPhoneAngle(double angle) {
  return angle.isFinite &&
      angle >= minimumSensorAngleDegrees &&
      angle <= maximumSensorAngleDegrees;
}

bool isValidCalibrationPhoneAngle(double angle) {
  return isValidSensorPhoneAngle(angle) &&
      angle >= minimumCalibrationAngleDegrees;
}

PostureThresholds calculatePostureThresholds(double neutralAngle) {
  if (!isValidCalibrationPhoneAngle(neutralAngle)) {
    throw ArgumentError.value(
      neutralAngle,
      'neutralAngle',
      'Calibration must be finite and between '
          '$minimumCalibrationAngleDegrees and $maximumSensorAngleDegrees degrees.',
    );
  }

  final badEnterAngle = _normalizedAngle(
    math
        .max(neutralAngle * badAngleRatio, minimumBadAngleDegrees)
        .clamp(minimumSensorAngleDegrees, maximumSensorAngleDegrees)
        .toDouble(),
  );
  final goodExitAngle = _normalizedAngle(
    math
        .max(
          neutralAngle * goodAngleRatio,
          badEnterAngle + hysteresisMinimumDegrees,
        )
        .clamp(badEnterAngle + double.minPositive, maximumSensorAngleDegrees)
        .toDouble(),
  );
  return PostureThresholds(
    badEnterAngle: badEnterAngle,
    goodExitAngle: goodExitAngle,
  );
}

double _normalizedAngle(double angle) {
  return (angle * 1000000).round() / 1000000;
}
