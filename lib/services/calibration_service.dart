import 'package:sensors_plus/sensors_plus.dart';

import '../functions/posture_check.dart';
import '../models/calibration.dart';
import '../models/posture_thresholds.dart';
import 'monitoring_service.dart';
import 'preferences_service.dart';

class CalibrationOperationResult {
  const CalibrationOperationResult({required this.success, this.calibration});

  final bool success;
  final Calibration? calibration;
}

class PostureCalibrationService {
  PostureCalibrationService({
    CalibrationRepository? repository,
    Future<double?> Function()? readAngle,
  }) : _repository = repository ?? CalibrationRepository(),
       _readAngle = readAngle ?? _readStableAngle;

  final CalibrationRepository _repository;
  final Future<double?> Function() _readAngle;

  Future<CalibrationOperationResult> calibrate() async {
    final angle = await _readAngle();
    if (angle == null || !isValidCalibrationPhoneAngle(angle)) {
      return const CalibrationOperationResult(success: false);
    }

    final calibration = Calibration(neutralPhoneAngle: angle);
    try {
      final saved = await _repository.save(calibration);
      if (!saved.savedLocally) {
        return const CalibrationOperationResult(success: false);
      }
      MonitoringService.updateCalibration(calibration);
      return CalibrationOperationResult(
        success: true,
        calibration: calibration,
      );
    } catch (_) {
      return const CalibrationOperationResult(success: false);
    }
  }

  static Future<double?> _readStableAngle() async {
    final filter = PhoneAngleFilter();
    final samples = <double>[];
    try {
      await for (final event
          in accelerometerEventStream()
              .take(10)
              .timeout(const Duration(seconds: 4))) {
        final rawAngle = phoneAngleFromAccelerometer(
          x: event.x,
          y: event.y,
          z: event.z,
        );
        if (rawAngle == null) continue;
        final smoothed = filter.add(rawAngle);
        if (smoothed != null) samples.add(smoothed);
      }
      return stablePhoneAngle(samples);
    } catch (_) {
      return null;
    }
  }
}
