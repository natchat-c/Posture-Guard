import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/models/calibration.dart';
import 'package:postureguard/models/posture_thresholds.dart';
import 'package:postureguard/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('latest valid calibration survives repository reconstruction', () async {
    final preferences = SharedPreferencesAsync();
    const first = Calibration(neutralPhoneAngle: 90);
    const latest = Calibration(neutralPhoneAngle: 60, neutralHeadX: 4);
    await CalibrationRepository.cacheCalibration(
      preferences,
      first,
      updatedAtEpochMs: 100,
    );
    await CalibrationRepository.cacheCalibration(
      preferences,
      latest,
      updatedAtEpochMs: 200,
    );

    final restored = await CalibrationRepository.loadCachedCalibration(
      SharedPreferencesAsync(),
    );

    expect(restored?.neutralPhoneAngle, 60);
    expect(restored?.neutralHeadX, 4);
    expect(
      await preferences.getInt(PreferenceKeys.calibrationUpdatedAtEpochMs),
      200,
    );
    expect(
      calculatePostureThresholds(restored!.neutralPhoneAngle).badEnterAngle,
      42,
    );
  });

  test(
    'invalid recalibration candidate does not replace valid cached value',
    () async {
      final preferences = SharedPreferencesAsync();
      const previous = Calibration(neutralPhoneAngle: 72);
      await CalibrationRepository.cacheCalibration(
        preferences,
        previous,
        updatedAtEpochMs: 100,
      );
      const invalidCandidate = Calibration(neutralPhoneAngle: -1);

      expect(invalidCandidate.isValid, isFalse);
      final restored = await CalibrationRepository.loadCachedCalibration(
        preferences,
      );
      expect(restored?.neutralPhoneAngle, 72);
    },
  );

  test(
    'legacy valid calibration fields remain readable without revision',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            PreferenceKeys.hasCalibration: true,
            PreferenceKeys.neutralPhoneAngle: 75.0,
            PreferenceKeys.neutralHeadX: -2.0,
          });

      final restored = await CalibrationRepository.loadCachedCalibration(
        SharedPreferencesAsync(),
      );

      expect(restored?.neutralPhoneAngle, 75);
      expect(restored?.neutralHeadX, -2);
    },
  );

  test('NaN, infinity, and below-minimum calibrations are invalid', () {
    for (final angle in [
      -0.1,
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(Calibration(neutralPhoneAngle: angle).isValid, isFalse);
    }
  });

  test('Firebase failure retains the newly saved local calibration', () async {
    final preferences = SharedPreferencesAsync();
    final repository = CalibrationRepository(
      preferences: preferences,
      remoteUpdater: (_) async => throw StateError('offline'),
    );

    final result = await repository.save(
      const Calibration(neutralPhoneAngle: 68),
    );
    final cached = await CalibrationRepository.loadCachedCalibration(
      preferences,
    );

    expect(result.savedLocally, isTrue);
    expect(result.savedToFirebase, isFalse);
    expect(cached?.neutralPhoneAngle, 68);
    expect(
      await preferences.getBool(PreferenceKeys.calibrationPendingSync),
      isTrue,
    );
  });

  test(
    'late old Firebase value cannot overwrite newer recalibration',
    () async {
      final preferences = SharedPreferencesAsync();
      await CalibrationRepository.cacheCalibration(
        preferences,
        const Calibration(neutralPhoneAngle: 80),
        updatedAtEpochMs: 100,
      );
      final oldRemote = Completer<Object?>();
      final loadingRepository = CalibrationRepository(
        preferences: preferences,
        remoteLoader: () => oldRemote.future,
      );

      final pendingLoad = loadingRepository.load();
      await Future<void>.delayed(Duration.zero);
      final savingRepository = CalibrationRepository(
        preferences: preferences,
        remoteUpdater: (_) async {},
      );
      await savingRepository.save(const Calibration(neutralPhoneAngle: 60));
      oldRemote.complete({
        'neutralPhoneAngle': 80.0,
        'calibrationUpdatedAtEpochMs': 100,
      });

      final result = await pendingLoad;
      final cached = await CalibrationRepository.loadCachedCalibration(
        preferences,
      );
      expect(result.calibration?.neutralPhoneAngle, 60);
      expect(cached?.neutralPhoneAngle, 60);
    },
  );
}
