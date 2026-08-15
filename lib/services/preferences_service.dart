import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/calibration.dart';
import 'user_database_paths.dart';

class PreferenceKeys {
  const PreferenceKeys._();

  static const String hasCachedSettings = 'hasCachedSettings';
  static const String monitoringEnabled = 'monitoringEnabled';
  static const String alertDelaySeconds = 'alertDelaySeconds';
  static const String alertFrequencySeconds = 'alertFrequencySeconds';
  static const String alertsEnabled = 'alertsEnabled';
  static const String settingsPendingSync = 'settingsPendingSync';
  static const String settingsUpdatedAtEpochMs = 'settingsUpdatedAtEpochMs';
  static const String hasCalibration = 'hasCalibration';
  static const String neutralPhoneAngle = 'neutralPhoneAngle';
  static const String neutralHeadX = 'neutralHeadX';
  static const String calibrationPendingSync = 'calibrationPendingSync';
  static const String calibrationUpdatedAtEpochMs =
      'calibrationUpdatedAtEpochMs';
  static const String hasCompletedTutorial = 'hasCompletedTutorial';
  static const String selectedLanguageCode = 'selectedLanguageCode';
  static const String notificationPermissionRequested =
      'notificationPermissionRequested';
  static const String cameraPermissionRequested = 'cameraPermissionRequested';
  static const String alertsMutedUntilEpochMs = 'alertsMutedUntilEpochMs';
  static const String equippedHatId = 'equippedHatId';
  static const String equippedEyewearId = 'equippedEyewearId';
  static const String equippedHoldingId = 'equippedHoldingId';
  static const String equippedBackId = 'equippedBackId';
  static const String cosmeticEconomyVersion = 'cosmeticEconomyVersion';
  static const String ownedCosmeticIds = 'ownedCosmeticIds';
}

class SettingsLoadResult {
  const SettingsLoadResult({required this.settings, this.warning});

  final AppSettings settings;
  final String? warning;
}

class SettingsSaveResult {
  const SettingsSaveResult({
    required this.savedLocally,
    required this.savedToFirebase,
    this.error,
  });

  final bool savedLocally;
  final bool savedToFirebase;
  final Object? error;

  bool get succeeded => savedLocally && savedToFirebase;
}

abstract class SettingsStore {
  Future<SettingsLoadResult> load();

  Future<SettingsSaveResult> save(AppSettings settings);
}

class SettingsRepository implements SettingsStore {
  SettingsRepository({
    SharedPreferencesAsync? preferences,
    DatabaseReference? reference,
    UserDatabaseReferenceFactory? referenceFactory,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _reference = reference,
       _referenceFactory = referenceFactory ?? UserDatabaseReferenceFactory();

  final SharedPreferencesAsync _preferences;
  final DatabaseReference? _reference;
  final UserDatabaseReferenceFactory _referenceFactory;

  Future<DatabaseReference> get _settingsReference async {
    return _reference ?? await _referenceFactory.settings();
  }

  @override
  Future<SettingsLoadResult> load() async {
    final cached = await loadCachedSettings(_preferences);
    final settings = cached ?? AppSettings.defaults;
    if (cached == null) await cacheSettings(_preferences, settings);
    unawaited(_synchronize(settings, allowLegacyRemote: cached == null));
    return SettingsLoadResult(settings: settings);
  }

  @override
  Future<SettingsSaveResult> save(AppSettings settings) async {
    if (!settings.isValid) {
      throw const FormatException('Settings are outside the allowed range.');
    }

    final previousRevision = await _preferences.getInt(
      PreferenceKeys.settingsUpdatedAtEpochMs,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    final revision = previousRevision != null && previousRevision >= now
        ? previousRevision + 1
        : now;
    await cacheSettings(_preferences, settings, updatedAtEpochMs: revision);
    await _preferences.setBool(PreferenceKeys.settingsPendingSync, true);
    unawaited(_synchronize(settings));
    return const SettingsSaveResult(savedLocally: true, savedToFirebase: false);
  }

  Future<void> _synchronize(
    AppSettings local, {
    bool allowLegacyRemote = false,
  }) async {
    try {
      final pending =
          await _preferences.getBool(PreferenceKeys.settingsPendingSync) ??
          false;
      final localRevision =
          await _preferences.getInt(PreferenceKeys.settingsUpdatedAtEpochMs) ??
          0;
      final settingsReference = await _settingsReference;
      if (pending) {
        final result = await settingsReference.runTransaction((value) {
          final data = value is Map
              ? Map<String, Object?>.fromEntries(
                  value.entries.map(
                    (entry) => MapEntry(entry.key.toString(), entry.value),
                  ),
                )
              : <String, Object?>{};
          final remoteRevision =
              (data['settingsUpdatedAtEpochMs'] as num?)?.toInt() ?? 0;
          if (remoteRevision > localRevision) {
            return Transaction.abort();
          }
          data
            ..addAll(local.toMap())
            ..['settingsUpdatedAtEpochMs'] = localRevision
            ..['updatedAt'] = ServerValue.timestamp;
          return Transaction.success(data);
        });
        if (result.committed) {
          await _preferences.setBool(PreferenceKeys.settingsPendingSync, false);
        }
        return;
      }

      final snapshot = await settingsReference.get();
      if (!snapshot.exists || snapshot.value is! Map) return;
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      final remoteRevision = (data['settingsUpdatedAtEpochMs'] as num?)
          ?.toInt();
      if ((remoteRevision != null && remoteRevision > localRevision) ||
          (allowLegacyRemote && remoteRevision == null)) {
        await cacheSettings(
          _preferences,
          AppSettings.fromMap(data, fallback: local),
          updatedAtEpochMs: remoteRevision,
        );
      }
    } catch (_) {
      // Local settings are authoritative while cloud sync is unavailable.
    }
  }

  static Future<AppSettings?> loadCachedSettings(
    SharedPreferencesAsync preferences,
  ) async {
    if (await preferences.getBool(PreferenceKeys.hasCachedSettings) != true) {
      return null;
    }

    final data = <String, Object?>{
      'monitoringEnabled': await preferences.getBool(
        PreferenceKeys.monitoringEnabled,
      ),
      'alertDelaySeconds': await preferences.getInt(
        PreferenceKeys.alertDelaySeconds,
      ),
      'alertFrequencySeconds': await preferences.getInt(
        PreferenceKeys.alertFrequencySeconds,
      ),
      'alertsEnabled': await preferences.getBool(PreferenceKeys.alertsEnabled),
    };
    return AppSettings.fromMap(data);
  }

  static Future<void> cacheSettings(
    SharedPreferencesAsync preferences,
    AppSettings settings, {
    int? updatedAtEpochMs,
  }) async {
    await preferences.setBool(
      PreferenceKeys.monitoringEnabled,
      settings.monitoringEnabled,
    );
    await preferences.setInt(
      PreferenceKeys.alertDelaySeconds,
      settings.alertDelaySeconds,
    );
    await preferences.setInt(
      PreferenceKeys.alertFrequencySeconds,
      settings.alertFrequencySeconds,
    );
    await preferences.setBool(
      PreferenceKeys.alertsEnabled,
      settings.alertsEnabled,
    );
    await preferences.setBool(PreferenceKeys.hasCachedSettings, true);
    if (updatedAtEpochMs != null) {
      await preferences.setInt(
        PreferenceKeys.settingsUpdatedAtEpochMs,
        updatedAtEpochMs,
      );
    }
  }
}

class CalibrationLoadResult {
  const CalibrationLoadResult({this.calibration, this.warning});

  final Calibration? calibration;
  final String? warning;
}

class CalibrationSaveResult {
  const CalibrationSaveResult({
    required this.savedLocally,
    required this.savedToFirebase,
    this.error,
  });

  final bool savedLocally;
  final bool savedToFirebase;
  final Object? error;
}

class CalibrationRepository {
  CalibrationRepository({
    SharedPreferencesAsync? preferences,
    DatabaseReference? reference,
    UserDatabaseReferenceFactory? referenceFactory,
    Future<Object?> Function()? remoteLoader,
    Future<void> Function(Map<String, Object?> update)? remoteUpdater,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _reference = reference,
       _referenceFactory = referenceFactory ?? UserDatabaseReferenceFactory(),
       _remoteLoader = remoteLoader,
       _remoteUpdater = remoteUpdater;

  final SharedPreferencesAsync _preferences;
  final DatabaseReference? _reference;
  final UserDatabaseReferenceFactory _referenceFactory;
  final Future<Object?> Function()? _remoteLoader;
  final Future<void> Function(Map<String, Object?> update)? _remoteUpdater;
  static int _localWriteGeneration = 0;

  Future<DatabaseReference> get _settingsReference async {
    return _reference ?? await _referenceFactory.settings();
  }

  Future<CalibrationLoadResult> load() async {
    final loadGeneration = _localWriteGeneration;
    final cached = await loadCachedCalibration(_preferences);
    final localRevision = await _preferences.getInt(
      PreferenceKeys.calibrationUpdatedAtEpochMs,
    );
    final hasPendingLocalSave =
        await _preferences.getBool(PreferenceKeys.calibrationPendingSync) ??
        false;

    // Production startup never waits for Firebase. Test/injected loaders keep
    // the explicit awaited path below for deterministic repository checks.
    if (_remoteLoader == null) {
      unawaited(
        _synchronizeCachedCalibration(
          cached,
          localRevision,
          hasPendingLocalSave: hasPendingLocalSave,
        ),
      );
      return CalibrationLoadResult(calibration: cached);
    }

    if (cached != null && hasPendingLocalSave) {
      try {
        await _syncCalibration(
          cached,
          localRevision ?? DateTime.now().millisecondsSinceEpoch,
        );
        await _preferences.setBool(
          PreferenceKeys.calibrationPendingSync,
          false,
        );
        return CalibrationLoadResult(calibration: cached);
      } catch (_) {
        return CalibrationLoadResult(
          calibration: cached,
          warning:
              'Firebase calibration sync is still pending. Using the calibration saved on this device.',
        );
      }
    }

    try {
      final remoteValue = await _remoteLoader();
      if (remoteValue == null) {
        return CalibrationLoadResult(calibration: cached);
      }

      if (remoteValue is! Map) {
        return CalibrationLoadResult(
          calibration: cached,
          warning: 'The saved calibration is invalid. Please calibrate again.',
        );
      }
      final data = Map<dynamic, dynamic>.from(remoteValue);
      final latestLocalRevision = await _preferences.getInt(
        PreferenceKeys.calibrationUpdatedAtEpochMs,
      );
      if (latestLocalRevision != localRevision) {
        return CalibrationLoadResult(
          calibration: await loadCachedCalibration(_preferences),
        );
      }
      if (!data.containsKey('neutralPhoneAngle')) {
        return CalibrationLoadResult(calibration: cached);
      }

      final phoneAngle = (data['neutralPhoneAngle'] as num?)?.toDouble();
      final headAngle = (data['neutralHeadX'] as num?)?.toDouble();
      final remoteRevision = (data['calibrationUpdatedAtEpochMs'] as num?)
          ?.toInt();
      if (cached != null &&
          localRevision != null &&
          (remoteRevision == null || remoteRevision < localRevision)) {
        return CalibrationLoadResult(calibration: cached);
      }
      if (phoneAngle == null || !Calibration.isValidPhoneAngle(phoneAngle)) {
        return CalibrationLoadResult(
          calibration: cached,
          warning: 'The saved calibration is invalid. Please calibrate again.',
        );
      }

      final calibration = Calibration(
        neutralPhoneAngle: phoneAngle,
        neutralHeadX:
            headAngle != null && Calibration.isValidHeadAngle(headAngle)
            ? headAngle
            : null,
      );
      if (_localWriteGeneration != loadGeneration) {
        return CalibrationLoadResult(
          calibration: await loadCachedCalibration(_preferences),
        );
      }
      await cacheCalibration(
        _preferences,
        calibration,
        updatedAtEpochMs: remoteRevision,
      );
      return CalibrationLoadResult(calibration: calibration);
    } catch (error) {
      return CalibrationLoadResult(
        calibration: cached,
        warning: cached == null
            ? 'Could not load calibration. Please calibrate before monitoring.'
            : 'Could not reach Firebase. Using calibration saved on this device.',
      );
    }
  }

  Future<CalibrationSaveResult> save(Calibration calibration) async {
    if (!calibration.isValid) {
      throw const FormatException('Calibration is invalid.');
    }

    final previousRevision = await _preferences.getInt(
      PreferenceKeys.calibrationUpdatedAtEpochMs,
    );
    final nowRevision = DateTime.now().millisecondsSinceEpoch;
    final revision = previousRevision != null && previousRevision >= nowRevision
        ? previousRevision + 1
        : nowRevision;
    await cacheCalibration(
      _preferences,
      calibration,
      updatedAtEpochMs: revision,
    );
    await _preferences.setBool(PreferenceKeys.calibrationPendingSync, true);

    if (_remoteUpdater == null) {
      unawaited(_synchronizePendingCalibration(calibration, revision));
      return const CalibrationSaveResult(
        savedLocally: true,
        savedToFirebase: false,
      );
    }

    try {
      await _syncCalibration(calibration, revision);
      await _preferences.setBool(PreferenceKeys.calibrationPendingSync, false);
      return const CalibrationSaveResult(
        savedLocally: true,
        savedToFirebase: true,
      );
    } catch (error) {
      return CalibrationSaveResult(
        savedLocally: true,
        savedToFirebase: false,
        error: error,
      );
    }
  }

  Future<void> _synchronizeCachedCalibration(
    Calibration? cached,
    int? localRevision, {
    required bool hasPendingLocalSave,
  }) async {
    try {
      if (cached != null && hasPendingLocalSave) {
        await _synchronizePendingCalibration(
          cached,
          localRevision ?? DateTime.now().millisecondsSinceEpoch,
        );
        return;
      }

      final settingsReference = await _settingsReference;
      final remoteValue = (await settingsReference.get()).value;
      if (remoteValue is! Map ||
          !remoteValue.containsKey('neutralPhoneAngle')) {
        return;
      }
      final data = Map<dynamic, dynamic>.from(remoteValue);
      final phoneAngle = (data['neutralPhoneAngle'] as num?)?.toDouble();
      final headAngle = (data['neutralHeadX'] as num?)?.toDouble();
      final remoteRevision = (data['calibrationUpdatedAtEpochMs'] as num?)
          ?.toInt();
      final latestLocalRevision = await _preferences.getInt(
        PreferenceKeys.calibrationUpdatedAtEpochMs,
      );
      if (phoneAngle == null ||
          !Calibration.isValidPhoneAngle(phoneAngle) ||
          (latestLocalRevision != null &&
              (remoteRevision == null ||
                  remoteRevision < latestLocalRevision))) {
        return;
      }
      await cacheCalibration(
        _preferences,
        Calibration(
          neutralPhoneAngle: phoneAngle,
          neutralHeadX:
              headAngle != null && Calibration.isValidHeadAngle(headAngle)
              ? headAngle
              : null,
        ),
        updatedAtEpochMs: remoteRevision,
      );
    } catch (_) {
      // The local calibration remains usable until a later opportunity.
    }
  }

  Future<void> _synchronizePendingCalibration(
    Calibration calibration,
    int revision,
  ) async {
    try {
      await _syncCalibration(calibration, revision);
      final latestRevision = await _preferences.getInt(
        PreferenceKeys.calibrationUpdatedAtEpochMs,
      );
      if (latestRevision == revision) {
        await _preferences.setBool(
          PreferenceKeys.calibrationPendingSync,
          false,
        );
      }
    } catch (_) {
      // Pending remains true and will retry on a later load/save.
    }
  }

  Future<void> _syncCalibration(Calibration calibration, int revision) async {
    final update = <String, Object?>{
      'neutralPhoneAngle': calibration.neutralPhoneAngle,
      'calibrationUpdatedAtEpochMs': revision,
      'updatedAt': ServerValue.timestamp,
    };
    if (calibration.neutralHeadX != null) {
      update['neutralHeadX'] = calibration.neutralHeadX;
    }
    if (_remoteUpdater case final updater?) {
      await updater(update);
    } else {
      final settingsReference = await _settingsReference;
      await settingsReference.update(update);
    }
  }

  static Future<Calibration?> loadCachedCalibration(
    SharedPreferencesAsync preferences,
  ) async {
    if (await preferences.getBool(PreferenceKeys.hasCalibration) != true) {
      return null;
    }

    final phoneAngle = await preferences.getDouble(
      PreferenceKeys.neutralPhoneAngle,
    );
    final headAngle = await preferences.getDouble(PreferenceKeys.neutralHeadX);
    if (phoneAngle == null || !Calibration.isValidPhoneAngle(phoneAngle)) {
      return null;
    }

    return Calibration(
      neutralPhoneAngle: phoneAngle,
      neutralHeadX: headAngle != null && Calibration.isValidHeadAngle(headAngle)
          ? headAngle
          : null,
    );
  }

  static Future<void> cacheCalibration(
    SharedPreferencesAsync preferences,
    Calibration calibration, {
    int? updatedAtEpochMs,
  }) async {
    _localWriteGeneration++;
    await preferences.setDouble(
      PreferenceKeys.neutralPhoneAngle,
      calibration.neutralPhoneAngle,
    );
    if (calibration.neutralHeadX != null) {
      await preferences.setDouble(
        PreferenceKeys.neutralHeadX,
        calibration.neutralHeadX!,
      );
    }
    await preferences.setBool(PreferenceKeys.hasCalibration, true);
    if (updatedAtEpochMs != null) {
      await preferences.setInt(
        PreferenceKeys.calibrationUpdatedAtEpochMs,
        updatedAtEpochMs,
      );
    }
  }
}

class TutorialPreferences {
  TutorialPreferences({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  Future<bool> hasCompletedTutorial() async {
    return await _preferences.getBool(PreferenceKeys.hasCompletedTutorial) ??
        false;
  }

  Future<void> markCompleted() async {
    await _preferences.setBool(PreferenceKeys.hasCompletedTutorial, true);
  }
}

class LanguagePreferences {
  LanguagePreferences({SharedPreferencesAsync? preferences})
    : _preferences = preferences;

  static const Set<String> supportedLanguageCodes = {'en', 'th'};

  final SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _store => _preferences ?? SharedPreferencesAsync();

  Future<String?> load() async {
    final code = await _store.getString(PreferenceKeys.selectedLanguageCode);
    return supportedLanguageCodes.contains(code) ? code : null;
  }

  Future<void> save(String code) async {
    if (!supportedLanguageCodes.contains(code)) {
      throw ArgumentError.value(code, 'code', 'Unsupported language code');
    }
    await _store.setString(PreferenceKeys.selectedLanguageCode, code);
  }
}
