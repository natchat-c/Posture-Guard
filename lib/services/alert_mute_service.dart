import 'package:shared_preferences/shared_preferences.dart';

import 'preferences_service.dart';

const Duration postureAlertMuteDuration = Duration(minutes: 15);

abstract class AlertMuteStore {
  Future<int?> readMutedUntilEpochMs();

  Future<void> writeMutedUntilEpochMs(int? epochMs);
}

class SharedPreferencesAlertMuteStore implements AlertMuteStore {
  SharedPreferencesAlertMuteStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<int?> readMutedUntilEpochMs() {
    return _preferences.getInt(PreferenceKeys.alertsMutedUntilEpochMs);
  }

  @override
  Future<void> writeMutedUntilEpochMs(int? epochMs) async {
    if (epochMs == null) {
      await _preferences.remove(PreferenceKeys.alertsMutedUntilEpochMs);
    } else {
      await _preferences.setInt(
        PreferenceKeys.alertsMutedUntilEpochMs,
        epochMs,
      );
    }
  }
}

class AlertMuteController {
  AlertMuteController({AlertMuteStore? store, DateTime Function()? clock})
    : _store = store ?? SharedPreferencesAlertMuteStore(),
      _clock = clock ?? DateTime.now;

  final AlertMuteStore _store;
  final DateTime Function() _clock;

  Future<DateTime?> activeMutedUntil() async {
    final epochMs = await _store.readMutedUntilEpochMs();
    if (epochMs == null) return null;
    final until = DateTime.fromMillisecondsSinceEpoch(epochMs);
    if (!until.isAfter(_clock())) {
      await _store.writeMutedUntilEpochMs(null);
      return null;
    }
    return until;
  }

  Future<DateTime> muteFor([
    Duration duration = postureAlertMuteDuration,
  ]) async {
    final until = _clock().add(duration);
    await _store.writeMutedUntilEpochMs(until.millisecondsSinceEpoch);
    return until;
  }

  Future<void> unmute() => _store.writeMutedUntilEpochMs(null);

  Future<bool> get isMuted async => await activeMutedUntil() != null;
}
