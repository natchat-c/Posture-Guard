import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/calibration.dart';

class PreferenceKeys {
  const PreferenceKeys._();

  static const String hasCachedSettings = 'hasCachedSettings';
  static const String monitoringEnabled = 'monitoringEnabled';
  static const String alertDelaySeconds = 'alertDelaySeconds';
  static const String alertFrequencySeconds = 'alertFrequencySeconds';
  static const String alertsEnabled = 'alertsEnabled';
  static const String settingsPendingSync = 'settingsPendingSync';
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
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _reference = reference;

  final SharedPreferencesAsync _preferences;
  final DatabaseReference? _reference;

  DatabaseReference get _settingsReference {
    return _reference ??
        FirebaseDatabase.instance.ref('users/demo_user/settings');
  }

  @override
  Future<SettingsLoadResult> load() async {
    final cached = await loadCachedSettings(_preferences);
    final hasPendingLocalSave =
        await _preferences.getBool(PreferenceKeys.settingsPendingSync) ?? false;

    if (cached != null && hasPendingLocalSave) {
      try {
        await _settingsReference.update({
          ...cached.toMap(),
          'updatedAt': ServerValue.timestamp,
        });
        await _preferences.setBool(PreferenceKeys.settingsPendingSync, false);
        return SettingsLoadResult(settings: cached);
      } catch (_) {
        return SettingsLoadResult(
          settings: cached,
          warning:
              'Firebase sync is still pending. Using settings saved on this device.',
        );
      }
    }

    try {
      final snapshot = await _settingsReference.get();
      if (!snapshot.exists || snapshot.value == null) {
        final settings = cached ?? AppSettings.defaults;
        await cacheSettings(_preferences, settings);
        return SettingsLoadResult(settings: settings);
      }

      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      // Old detectionMode/useCameraMode fields are intentionally ignored.
      final settings = AppSettings.fromMap(
        data,
        fallback: cached ?? AppSettings.defaults,
      );
      await cacheSettings(_preferences, settings);
      return SettingsLoadResult(settings: settings);
    } catch (error) {
      final settings = cached ?? AppSettings.defaults;
      await cacheSettings(_preferences, settings);
      return SettingsLoadResult(
        settings: settings,
        warning: cached == null
            ? 'Could not load Firebase settings. Using safe defaults.'
            : 'Could not reach Firebase. Using settings saved on this device.',
      );
    }
  }

  @override
  Future<SettingsSaveResult> save(AppSettings settings) async {
    if (!settings.isValid) {
      throw const FormatException('Settings are outside the allowed range.');
    }

    await cacheSettings(_preferences, settings);
    await _preferences.setBool(PreferenceKeys.settingsPendingSync, true);

    try {
      await _settingsReference.update({
        ...settings.toMap(),
        'updatedAt': ServerValue.timestamp,
      });
      await _preferences.setBool(PreferenceKeys.settingsPendingSync, false);
      return const SettingsSaveResult(
        savedLocally: true,
        savedToFirebase: true,
      );
    } catch (error) {
      return SettingsSaveResult(
        savedLocally: true,
        savedToFirebase: false,
        error: error,
      );
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
    AppSettings settings,
  ) async {
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
    Future<Object?> Function()? remoteLoader,
    Future<void> Function(Map<String, Object?> update)? remoteUpdater,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _reference = reference,
       _remoteLoader = remoteLoader,
       _remoteUpdater = remoteUpdater;

  final SharedPreferencesAsync _preferences;
  final DatabaseReference? _reference;
  final Future<Object?> Function()? _remoteLoader;
  final Future<void> Function(Map<String, Object?> update)? _remoteUpdater;
  static int _localWriteGeneration = 0;

  DatabaseReference get _settingsReference {
    return _reference ??
        FirebaseDatabase.instance.ref('users/demo_user/settings');
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
      final remoteValue = _remoteLoader != null
          ? await _remoteLoader()
          : (await _settingsReference.get()).value;
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
      await _settingsReference.update(update);
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
