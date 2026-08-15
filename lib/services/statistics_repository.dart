import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_database_paths.dart';

String postureDateKey([DateTime? date]) {
  final value = date ?? DateTime.now();
  final year = value.year.toString();
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

class DailyStats {
  const DailyStats({
    int? monitoredTimeSeconds,
    int? badPostureSeconds,
    int? goodPostureSeconds,
    this.deviceScreenTimeSeconds,
    this.badDetectionCount = 0,
    this.goodDetectionCount = 0,
    this.alertsSentCount = 0,
    this.cameraUnavailableCount = 0,
    this.movementPausedCount = 0,
    int? totalScreenTime,
    int? totalBadPostureTime,
  }) : monitoredTimeSeconds = monitoredTimeSeconds ?? totalScreenTime ?? 0,
       badPostureSeconds = badPostureSeconds ?? totalBadPostureTime ?? 0,
       goodPostureSeconds =
           goodPostureSeconds ??
           ((monitoredTimeSeconds ?? totalScreenTime ?? 0) -
               (badPostureSeconds ?? totalBadPostureTime ?? 0));

  // Legacy totalScreenTimeSeconds means time monitored by Posture Guard. It is
  // intentionally not redefined as Android device screen time.
  final int monitoredTimeSeconds;
  final int badPostureSeconds;
  final int goodPostureSeconds;
  final int? deviceScreenTimeSeconds;
  final int badDetectionCount;
  final int goodDetectionCount;
  final int alertsSentCount;
  final int cameraUnavailableCount;
  final int movementPausedCount;

  int get totalScreenTime => monitoredTimeSeconds;

  int get totalBadPostureTime => badPostureSeconds;

  bool get hasTrackedPosture => monitoredTimeSeconds > 0;

  double get dailyScore {
    if (monitoredTimeSeconds <= 0) return 100;
    return (100 * (1 - badPostureSeconds / monitoredTimeSeconds)).clamp(0, 100);
  }

  DailyStats apply(StatsDelta delta) {
    final monitored = max(0, monitoredTimeSeconds + delta.screenSeconds);
    final bad = min(monitored, max(0, badPostureSeconds + delta.badSeconds));
    return DailyStats(
      monitoredTimeSeconds: monitored,
      badPostureSeconds: bad,
      goodPostureSeconds: monitored - bad,
      deviceScreenTimeSeconds: deviceScreenTimeSeconds,
      badDetectionCount: max(0, badDetectionCount + delta.badDetections),
      goodDetectionCount: max(0, goodDetectionCount + delta.goodDetections),
      alertsSentCount: max(0, alertsSentCount + delta.alertsSent),
      cameraUnavailableCount: max(
        0,
        cameraUnavailableCount + delta.cameraUnavailable,
      ),
      movementPausedCount: max(0, movementPausedCount + delta.movementPaused),
    );
  }

  DailyStats withDeviceScreenTime(int seconds) {
    return DailyStats(
      monitoredTimeSeconds: monitoredTimeSeconds,
      badPostureSeconds: badPostureSeconds,
      goodPostureSeconds: goodPostureSeconds,
      deviceScreenTimeSeconds: max(0, seconds),
      badDetectionCount: badDetectionCount,
      goodDetectionCount: goodDetectionCount,
      alertsSentCount: alertsSentCount,
      cameraUnavailableCount: cameraUnavailableCount,
      movementPausedCount: movementPausedCount,
    );
  }

  /// Cumulative daily counters are monotonic. Taking the greater value keeps a
  /// newer local record from being replaced by an older cloud snapshot.
  DailyStats mergeMonotonic(DailyStats other) {
    final monitored = max(monitoredTimeSeconds, other.monitoredTimeSeconds);
    final bad = min(monitored, max(badPostureSeconds, other.badPostureSeconds));
    final localDevice = deviceScreenTimeSeconds;
    final remoteDevice = other.deviceScreenTimeSeconds;
    return DailyStats(
      monitoredTimeSeconds: monitored,
      badPostureSeconds: bad,
      goodPostureSeconds: monitored - bad,
      deviceScreenTimeSeconds: localDevice == null
          ? remoteDevice
          : remoteDevice == null
          ? localDevice
          : max(localDevice, remoteDevice),
      badDetectionCount: max(badDetectionCount, other.badDetectionCount),
      goodDetectionCount: max(goodDetectionCount, other.goodDetectionCount),
      alertsSentCount: max(alertsSentCount, other.alertsSentCount),
      cameraUnavailableCount: max(
        cameraUnavailableCount,
        other.cameraUnavailableCount,
      ),
      movementPausedCount: max(movementPausedCount, other.movementPausedCount),
    );
  }

  Map<String, Object?> toMap() {
    final score = dailyScore.round();
    return {
      'monitoredTimeSeconds': monitoredTimeSeconds,
      'totalScreenTimeSeconds': monitoredTimeSeconds,
      'badPostureSeconds': badPostureSeconds,
      'totalBadPostureSeconds': badPostureSeconds,
      'goodPostureSeconds': goodPostureSeconds,
      if (deviceScreenTimeSeconds != null)
        'deviceScreenTimeSeconds': deviceScreenTimeSeconds,
      'score': score,
      'scorePercent': score,
      'badDetectionCount': badDetectionCount,
      'goodDetectionCount': goodDetectionCount,
      'alertsSentCount': alertsSentCount,
      'cameraUnavailableCount': cameraUnavailableCount,
      'movementPausedCount': movementPausedCount,
    };
  }

  factory DailyStats.fromValue(Object? value) {
    if (value is! Map) return const DailyStats();
    final data = Map<dynamic, dynamic>.from(value);
    final monitored =
        (data['monitoredTimeSeconds'] as num?)?.toInt() ??
        (data['totalScreenTimeSeconds'] as num?)?.toInt() ??
        0;
    final bad =
        (data['badPostureSeconds'] as num?)?.toInt() ??
        (data['totalBadPostureSeconds'] as num?)?.toInt() ??
        0;
    final rawDeviceScreenTime = data['deviceScreenTimeSeconds'];
    final safeMonitored = max(0, monitored);
    final safeBad = max(0, min(safeMonitored, bad));
    final rawGood = (data['goodPostureSeconds'] as num?)?.toInt();
    final safeGood = rawGood != null && rawGood >= 0 && rawGood <= safeMonitored
        ? rawGood
        : safeMonitored - safeBad;
    return DailyStats(
      monitoredTimeSeconds: safeMonitored,
      badPostureSeconds: safeBad,
      goodPostureSeconds: safeGood,
      deviceScreenTimeSeconds: rawDeviceScreenTime is num
          ? max(0, rawDeviceScreenTime.toInt())
          : null,
      badDetectionCount: (data['badDetectionCount'] as num?)?.toInt() ?? 0,
      goodDetectionCount: (data['goodDetectionCount'] as num?)?.toInt() ?? 0,
      alertsSentCount: (data['alertsSentCount'] as num?)?.toInt() ?? 0,
      cameraUnavailableCount:
          (data['cameraUnavailableCount'] as num?)?.toInt() ?? 0,
      movementPausedCount: (data['movementPausedCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class StatsDelta {
  const StatsDelta({
    this.screenSeconds = 0,
    this.badSeconds = 0,
    this.badDetections = 0,
    this.goodDetections = 0,
    this.alertsSent = 0,
    this.cameraUnavailable = 0,
    this.movementPaused = 0,
  });

  final int screenSeconds;
  final int badSeconds;
  final int badDetections;
  final int goodDetections;
  final int alertsSent;
  final int cameraUnavailable;
  final int movementPaused;

  bool get isEmpty {
    return screenSeconds == 0 &&
        badSeconds == 0 &&
        badDetections == 0 &&
        goodDetections == 0 &&
        alertsSent == 0 &&
        cameraUnavailable == 0 &&
        movementPaused == 0;
  }

  Map<String, int> toMap() {
    return {
      'screenSeconds': screenSeconds,
      'badSeconds': badSeconds,
      'badDetections': badDetections,
      'goodDetections': goodDetections,
      'alertsSent': alertsSent,
      'cameraUnavailable': cameraUnavailable,
      'movementPaused': movementPaused,
    };
  }

  factory StatsDelta.fromMap(Map<dynamic, dynamic> value) {
    return StatsDelta(
      screenSeconds: (value['screenSeconds'] as num?)?.toInt() ?? 0,
      badSeconds: (value['badSeconds'] as num?)?.toInt() ?? 0,
      badDetections: (value['badDetections'] as num?)?.toInt() ?? 0,
      goodDetections: (value['goodDetections'] as num?)?.toInt() ?? 0,
      alertsSent: (value['alertsSent'] as num?)?.toInt() ?? 0,
      cameraUnavailable: (value['cameraUnavailable'] as num?)?.toInt() ?? 0,
      movementPaused: (value['movementPaused'] as num?)?.toInt() ?? 0,
    );
  }
}

abstract class StatisticsRemoteStore {
  Future<Map<String, DailyStats>> loadAll();

  Future<void> applyDelta({
    required String dateKey,
    required String clientId,
    required int sequence,
    required StatsDelta delta,
  });

  Future<void> saveDeviceScreenTime(String dateKey, int seconds);
}

class FirebaseStatisticsRemoteStore implements StatisticsRemoteStore {
  FirebaseStatisticsRemoteStore({
    FirebaseDatabase? database,
    UserDatabaseReferenceFactory? referenceFactory,
  }) : _referenceFactory =
           referenceFactory ?? UserDatabaseReferenceFactory(database: database);

  final UserDatabaseReferenceFactory _referenceFactory;

  Future<DatabaseReference> _referenceFor(String dateKey) {
    return _referenceFactory.dailyStats(dateKey);
  }

  @override
  Future<Map<String, DailyStats>> loadAll() async {
    final reference = await _referenceFactory.dailyStatsRoot();
    final snapshot = await reference.get();
    return statisticsRecordsFromValue(snapshot.value);
  }

  @override
  Future<void> applyDelta({
    required String dateKey,
    required String clientId,
    required int sequence,
    required StatsDelta delta,
  }) async {
    final reference = await _referenceFor(dateKey);
    final result = await reference.runTransaction((currentValue) {
      final data = currentValue is Map
          ? Map<String, Object?>.fromEntries(
              currentValue.entries.map(
                (entry) => MapEntry(entry.key.toString(), entry.value),
              ),
            )
          : <String, Object?>{};
      final rawSequences = data['syncSequenceByClient'];
      final sequences = rawSequences is Map
          ? Map<String, Object?>.fromEntries(
              rawSequences.entries.map(
                (entry) => MapEntry(entry.key.toString(), entry.value),
              ),
            )
          : <String, Object?>{};
      final appliedSequence = (sequences[clientId] as num?)?.toInt() ?? 0;
      if (sequence <= appliedSequence) return Transaction.success(data);

      final updated = DailyStats.fromValue(data).apply(delta);
      data
        ..addAll(updated.toMap())
        ..['date'] = dateKey
        ..['updatedAt'] = ServerValue.timestamp
        ..['syncSequenceByClient'] = {...sequences, clientId: sequence};
      data.putIfAbsent('coinsEarned', () => 0);
      data.putIfAbsent('coinsAwarded', () => false);
      return Transaction.success(data);
    });
    if (!result.committed) {
      throw StateError('Daily statistics transaction was not committed.');
    }
  }

  @override
  Future<void> saveDeviceScreenTime(String dateKey, int seconds) async {
    final safeSeconds = max(0, seconds);
    final reference = await _referenceFor(dateKey);
    final result = await reference.runTransaction((currentValue) {
      final data = currentValue is Map
          ? Map<String, Object?>.fromEntries(
              currentValue.entries.map(
                (entry) => MapEntry(entry.key.toString(), entry.value),
              ),
            )
          : <String, Object?>{};
      final current = (data['deviceScreenTimeSeconds'] as num?)?.toInt() ?? 0;
      data
        ..['date'] = dateKey
        ..['deviceScreenTimeSeconds'] = max(current, safeSeconds)
        ..['updatedAt'] = ServerValue.timestamp;
      return Transaction.success(data);
    });
    if (!result.committed) {
      throw StateError('Screen-time transaction was not committed.');
    }
  }
}

Map<String, DailyStats> statisticsRecordsFromValue(Object? value) {
  if (value is! Map) return const {};
  final map = Map<dynamic, dynamic>.from(value);
  if (map.containsKey('totalScreenTimeSeconds') ||
      map.containsKey('monitoredTimeSeconds')) {
    final dateKey = map['date']?.toString() ?? postureDateKey();
    return {dateKey: DailyStats.fromValue(map)};
  }

  final records = <String, DailyStats>{};
  for (final entry in map.entries) {
    if (entry.value is! Map) continue;
    records[entry.key.toString()] = DailyStats.fromValue(entry.value);
  }
  return records;
}

class _PendingStatsOperation {
  const _PendingStatsOperation({
    required this.dateKey,
    required this.clientId,
    required this.sequence,
    required this.delta,
  });

  final String dateKey;
  final String clientId;
  final int sequence;
  final StatsDelta delta;

  String get id => '$clientId:$sequence';

  Map<String, Object> toMap() => {
    'dateKey': dateKey,
    'clientId': clientId,
    'sequence': sequence,
    'delta': delta.toMap(),
  };

  factory _PendingStatsOperation.fromMap(Map<dynamic, dynamic> value) {
    return _PendingStatsOperation(
      dateKey: value['dateKey']?.toString() ?? postureDateKey(),
      clientId: value['clientId']?.toString() ?? '',
      sequence: (value['sequence'] as num?)?.toInt() ?? 0,
      delta: value['delta'] is Map
          ? StatsDelta.fromMap(value['delta'] as Map)
          : const StatsDelta(),
    );
  }
}

class _LocalStatisticsState {
  _LocalStatisticsState({
    required this.clientId,
    required this.nextSequence,
    required this.records,
    required this.pending,
  });

  String clientId;
  int nextSequence;
  final Map<String, DailyStats> records;
  final List<_PendingStatsOperation> pending;

  Map<String, Object> toMap() => {
    'clientId': clientId,
    'nextSequence': nextSequence,
    'records': records.map((key, value) => MapEntry(key, value.toMap())),
    'pending': pending.map((value) => value.toMap()).toList(),
  };
}

class StatisticsRepository {
  StatisticsRepository({
    SharedPreferencesAsync? preferences,
    StatisticsRemoteStore? remoteStore,
    Duration watchInterval = const Duration(seconds: 2),
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _remoteStore = remoteStore,
       _watchInterval = watchInterval;

  static const String _localStateKey = 'localStatisticsStateV2';
  static const String _cloudCacheKey = 'cloudStatisticsCacheV2';
  static const String _deviceScreenTimeKey = 'localDeviceScreenTimeV2';

  final SharedPreferencesAsync _preferences;
  final StatisticsRemoteStore? _remoteStore;
  final Duration _watchInterval;
  bool _syncInProgress = false;
  bool _refreshInProgress = false;

  StatisticsRemoteStore get _remote =>
      _remoteStore ?? FirebaseStatisticsRemoteStore();

  Stream<DailyStats> watch(String dateKey) async* {
    yield await load(dateKey);
    unawaited(synchronize());
    await for (final _ in Stream<void>.periodic(_watchInterval)) {
      yield await load(dateKey);
    }
  }

  Future<DailyStats> load(String dateKey) async {
    final records = await _loadMergedRecords();
    return records[dateKey] ?? const DailyStats();
  }

  Stream<Map<String, DailyStats>> watchAll() async* {
    yield await loadAll();
    unawaited(synchronize());
    await for (final _ in Stream<void>.periodic(_watchInterval)) {
      yield await loadAll();
    }
  }

  Future<Map<String, DailyStats>> loadAll() => _loadMergedRecords();

  Future<void> saveDeviceScreenTime(
    String dateKey,
    int deviceScreenTimeSeconds,
  ) async {
    final values = await _readDeviceScreenTimes();
    values[dateKey] = max(values[dateKey] ?? 0, deviceScreenTimeSeconds);
    await _preferences.setString(_deviceScreenTimeKey, jsonEncode(values));
    unawaited(synchronize());
  }

  /// Commits locally before scheduling cloud work. A failed cloud attempt does
  /// not fail this method or discard its outbox entry.
  Future<void> addDelta(String dateKey, StatsDelta delta) async {
    if (delta.isEmpty) return;
    final state = await _readLocalState();
    final sequence = state.nextSequence++;
    final operation = _PendingStatsOperation(
      dateKey: dateKey,
      clientId: state.clientId,
      sequence: sequence,
      delta: delta,
    );
    state.records[dateKey] = (state.records[dateKey] ?? const DailyStats())
        .apply(delta);
    state.pending.add(operation);
    await _writeLocalState(state);
    unawaited(synchronize());
  }

  /// Retries pending writes and refreshes the separate cloud cache. Concurrent
  /// opportunities coalesce, avoiding a tight retry loop.
  Future<void> synchronize() async {
    if (_syncInProgress) return;
    _syncInProgress = true;
    try {
      await _syncPendingDeltas();
      await _syncDeviceScreenTimes();
      await _refreshCloudCache();
    } catch (_) {
      // Offline is a normal operating mode. Pending local values remain intact.
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> _syncPendingDeltas() async {
    while (true) {
      final state = await _readLocalState();
      if (state.pending.isEmpty) return;
      final operation = state.pending.first;
      await _remote.applyDelta(
        dateKey: operation.dateKey,
        clientId: operation.clientId,
        sequence: operation.sequence,
        delta: operation.delta,
      );

      // Re-read after the network request so a delta written meanwhile is not
      // erased with a stale state snapshot.
      final latest = await _readLocalState();
      latest.pending.removeWhere((value) => value.id == operation.id);
      await _writeLocalState(latest);
    }
  }

  Future<void> _syncDeviceScreenTimes() async {
    final values = await _readDeviceScreenTimes();
    for (final entry in values.entries) {
      await _remote.saveDeviceScreenTime(entry.key, entry.value);
    }
  }

  Future<void> _refreshCloudCache() async {
    if (_refreshInProgress) return;
    _refreshInProgress = true;
    try {
      final records = await _remote.loadAll();
      await _preferences.setString(
        _cloudCacheKey,
        jsonEncode(records.map((key, value) => MapEntry(key, value.toMap()))),
      );
    } finally {
      _refreshInProgress = false;
    }
  }

  Future<Map<String, DailyStats>> _loadMergedRecords() async {
    final local = (await _readLocalState()).records;
    final cloud = await _readRecords(_cloudCacheKey);
    final deviceScreenTimes = await _readDeviceScreenTimes();
    final keys = <String>{
      ...local.keys,
      ...cloud.keys,
      ...deviceScreenTimes.keys,
    };
    return {
      for (final key in keys)
        key: (local[key] ?? const DailyStats())
            .mergeMonotonic(cloud[key] ?? const DailyStats())
            .withDeviceScreenTime(
              max(
                deviceScreenTimes[key] ?? 0,
                max(
                  local[key]?.deviceScreenTimeSeconds ?? 0,
                  cloud[key]?.deviceScreenTimeSeconds ?? 0,
                ),
              ),
            ),
    };
  }

  Future<_LocalStatisticsState> _readLocalState() async {
    final encoded = await _preferences.getString(_localStateKey);
    if (encoded != null && encoded.isNotEmpty) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is Map) {
          final records = _recordsFromMap(decoded['records']);
          final rawPending = decoded['pending'];
          final pending = <_PendingStatsOperation>[];
          if (rawPending is List) {
            for (final value in rawPending) {
              if (value is Map) {
                final operation = _PendingStatsOperation.fromMap(value);
                if (operation.clientId.isNotEmpty &&
                    operation.sequence > 0 &&
                    !operation.delta.isEmpty) {
                  pending.add(operation);
                }
              }
            }
          }
          final clientId = decoded['clientId']?.toString();
          if (clientId != null && clientId.isNotEmpty) {
            return _LocalStatisticsState(
              clientId: clientId,
              nextSequence: max(
                1,
                (decoded['nextSequence'] as num?)?.toInt() ?? 1,
              ),
              records: records,
              pending: pending,
            );
          }
        }
      } catch (_) {
        // A malformed cache is ignored; cloud and new local data remain usable.
      }
    }

    final now = DateTime.now().microsecondsSinceEpoch;
    final random = Random().nextInt(0x7fffffff);
    return _LocalStatisticsState(
      clientId: 'android-$now-$random',
      nextSequence: 1,
      records: {},
      pending: [],
    );
  }

  Future<void> _writeLocalState(_LocalStatisticsState state) {
    return _preferences.setString(_localStateKey, jsonEncode(state.toMap()));
  }

  Future<Map<String, DailyStats>> _readRecords(String key) async {
    final encoded = await _preferences.getString(key);
    if (encoded == null || encoded.isEmpty) return {};
    try {
      return _recordsFromMap(jsonDecode(encoded));
    } catch (_) {
      return {};
    }
  }

  Map<String, DailyStats> _recordsFromMap(Object? value) {
    if (value is! Map) return {};
    return {
      for (final entry in value.entries)
        if (entry.value is Map)
          entry.key.toString(): DailyStats.fromValue(entry.value),
    };
  }

  Future<Map<String, int>> _readDeviceScreenTimes() async {
    final encoded = await _preferences.getString(_deviceScreenTimeKey);
    if (encoded == null || encoded.isEmpty) return {};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is num)
            entry.key.toString(): max(0, (entry.value as num).toInt()),
      };
    } catch (_) {
      return {};
    }
  }
}
