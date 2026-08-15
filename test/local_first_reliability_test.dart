import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/models/app_settings.dart';
import 'package:postureguard/models/calibration.dart';
import 'package:postureguard/services/coin_repository.dart';
import 'package:postureguard/services/preferences_service.dart';
import 'package:postureguard/services/statistics_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FakeStatisticsRemote implements StatisticsRemoteStore {
  bool online = false;
  final Map<String, DailyStats> records = {};
  final Set<String> appliedOperations = {};
  int applyCalls = 0;

  void _requireOnline() {
    if (!online) throw StateError('offline');
  }

  @override
  Future<void> applyDelta({
    required String dateKey,
    required String clientId,
    required int sequence,
    required StatsDelta delta,
  }) async {
    applyCalls++;
    _requireOnline();
    final id = '$clientId:$sequence';
    if (!appliedOperations.add(id)) return;
    records[dateKey] = (records[dateKey] ?? const DailyStats()).apply(delta);
  }

  @override
  Future<Map<String, DailyStats>> loadAll() async {
    _requireOnline();
    return Map.of(records);
  }

  @override
  Future<void> saveDeviceScreenTime(String dateKey, int seconds) async {
    _requireOnline();
    final current = records[dateKey] ?? const DailyStats();
    records[dateKey] = current.withDeviceScreenTime(
      max(current.deviceScreenTimeSeconds ?? 0, seconds),
    );
  }
}

class _FakeCoinRemote implements CoinRemoteStore {
  bool online = false;
  CoinState state = const CoinState();

  void _requireOnline() {
    if (!online) throw StateError('offline');
  }

  @override
  Future<CoinState> load() async {
    _requireOnline();
    return state;
  }

  @override
  Future<CoinState> merge(CoinState local) async {
    _requireOnline();
    state = state.merge(local);
    return state;
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'settings and calibration load immediately from the phone offline',
    () async {
      final preferences = SharedPreferencesAsync();
      const settings = AppSettings(
        monitoringEnabled: true,
        alertDelaySeconds: 15,
        alertFrequencySeconds: 60,
        alertsEnabled: false,
      );
      await SettingsRepository.cacheSettings(preferences, settings);
      await CalibrationRepository.cacheCalibration(
        preferences,
        const Calibration(neutralPhoneAngle: 67, neutralHeadX: 3),
        updatedAtEpochMs: 100,
      );

      final loadedSettings = await SettingsRepository(
        preferences: preferences,
      ).load().timeout(const Duration(seconds: 1));
      final loadedCalibration = await CalibrationRepository(
        preferences: preferences,
      ).load().timeout(const Duration(seconds: 1));

      expect(loadedSettings.settings, settings);
      expect(loadedCalibration.calibration?.neutralPhoneAngle, 67);
      expect(loadedCalibration.calibration?.neutralHeadX, 3);
    },
  );

  test(
    'daily posture data persists offline, survives reopening, and syncs once',
    () async {
      final preferences = SharedPreferencesAsync();
      final remote = _FakeStatisticsRemote();
      final repository = StatisticsRepository(
        preferences: preferences,
        remoteStore: remote,
      );
      const dateKey = '2026-08-07';

      await repository.addDelta(
        dateKey,
        const StatsDelta(
          screenSeconds: 12,
          badSeconds: 3,
          goodDetections: 2,
          badDetections: 1,
          alertsSent: 1,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final reopened = StatisticsRepository(
        preferences: SharedPreferencesAsync(),
        remoteStore: remote,
      );
      final offline = await reopened.load(dateKey);
      expect(offline.monitoredTimeSeconds, 12);
      expect(offline.badPostureSeconds, 3);
      expect(offline.goodPostureSeconds, 9);
      expect(offline.dailyScore, 75);
      expect(offline.alertsSentCount, 1);

      remote.online = true;
      await reopened.synchronize();
      await reopened.synchronize();

      expect(remote.records[dateKey]?.monitoredTimeSeconds, 12);
      expect(remote.records[dateKey]?.badPostureSeconds, 3);
      expect(remote.appliedOperations, hasLength(1));
    },
  );

  test(
    'an older cloud snapshot cannot make local statistics go backwards',
    () async {
      final preferences = SharedPreferencesAsync();
      final remote = _FakeStatisticsRemote()..online = true;
      final repository = StatisticsRepository(
        preferences: preferences,
        remoteStore: remote,
      );
      const dateKey = '2026-08-07';
      await repository.addDelta(
        dateKey,
        const StatsDelta(screenSeconds: 20, badSeconds: 4),
      );
      await repository.synchronize();

      remote.records[dateKey] = const DailyStats(
        monitoredTimeSeconds: 5,
        badPostureSeconds: 2,
      );
      await repository.synchronize();

      final merged = await repository.load(dateKey);
      expect(merged.monitoredTimeSeconds, 20);
      expect(merged.badPostureSeconds, 4);
    },
  );

  test('device screen time remains available without a network', () async {
    final remote = _FakeStatisticsRemote();
    final repository = StatisticsRepository(remoteStore: remote);
    await repository.saveDeviceScreenTime('2026-08-07', 4321);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final reopened = StatisticsRepository(remoteStore: remote);
    expect((await reopened.load('2026-08-07')).deviceScreenTimeSeconds, 4321);
  });

  test(
    'earned coins survive offline reopening and reconnect without doubling',
    () async {
      final preferences = SharedPreferencesAsync();
      final remote = _FakeCoinRemote();
      final repository = CoinRepository(
        preferences: preferences,
        remoteStore: remote,
      );
      final yesterday = DateTime(2026, 8, 6);
      const dateKey = '2026-08-06';

      final awarded = await repository.awardCompletedDays(
        state: const CoinState(),
        records: {
          dateKey: const DailyStats(
            monitoredTimeSeconds: 100,
            badPostureSeconds: 25,
          ),
        },
        now: DateTime(2026, 8, 7),
      );
      expect(postureDateKey(yesterday), dateKey);
      expect(awarded.totalCoins, 75);

      final reopened = CoinRepository(
        preferences: SharedPreferencesAsync(),
        remoteStore: remote,
      );
      expect((await reopened.load()).totalCoins, 75);

      remote.online = true;
      await reopened.synchronize();
      await reopened.synchronize();
      expect(remote.state.totalCoins, 75);
      expect(remote.state.awardedDates, contains(dateKey));
    },
  );
}
