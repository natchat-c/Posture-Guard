import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'statistics_repository.dart';

class CoinState {
  const CoinState({
    this.totalCoins = 0,
    this.awardedDates = const {},
    this.awardedThroughDate,
    this.balanceRevision = 0,
  });

  final int totalCoins;
  final Set<String> awardedDates;
  final String? awardedThroughDate;
  final int balanceRevision;

  CoinState merge(CoinState other) {
    final mergedTotal = balanceRevision == other.balanceRevision
        ? max(totalCoins, other.totalCoins)
        : balanceRevision > other.balanceRevision
        ? totalCoins
        : other.totalCoins;
    return CoinState(
      totalCoins: mergedTotal,
      awardedDates: {...awardedDates, ...other.awardedDates},
      awardedThroughDate: _laterDate(
        awardedThroughDate,
        other.awardedThroughDate,
      ),
      balanceRevision: max(balanceRevision, other.balanceRevision),
    );
  }

  Map<String, Object> toMap() => {
    'totalCoins': max(0, totalCoins),
    'awardedDates': awardedDates.toList()..sort(),
    'lastAwardedDate': ?awardedThroughDate,
    'balanceRevision': max(0, balanceRevision),
  };

  factory CoinState.fromValue(Object? value) {
    if (value is! Map) return const CoinState();
    final data = Map<dynamic, dynamic>.from(value);
    final rawDates = data['awardedDates'];
    final dates = rawDates is List
        ? rawDates.map((value) => value.toString()).toSet()
        : <String>{};
    final legacyLastAwarded = data['lastAwardedDate']?.toString();
    if (legacyLastAwarded != null && legacyLastAwarded.isNotEmpty) {
      dates.add(legacyLastAwarded);
    }
    return CoinState(
      totalCoins: max(0, (data['totalCoins'] as num?)?.toInt() ?? 0),
      awardedDates: dates,
      awardedThroughDate: legacyLastAwarded,
      balanceRevision: max(0, (data['balanceRevision'] as num?)?.toInt() ?? 0),
    );
  }

  static String? _laterDate(String? first, String? second) {
    if (first == null) return second;
    if (second == null) return first;
    return first.compareTo(second) >= 0 ? first : second;
  }
}

abstract class CoinRemoteStore {
  Future<CoinState> load();

  Future<CoinState> merge(CoinState local);
}

abstract class CoinStore {
  Future<CoinState> load();

  Future<CoinState> setTotalCoins(CoinState state, int totalCoins);
}

class FirebaseCoinRemoteStore implements CoinRemoteStore {
  FirebaseCoinRemoteStore({DatabaseReference? reference})
    : _reference = reference;

  final DatabaseReference? _reference;

  DatabaseReference get _resolvedReference {
    if (_reference case final reference?) return reference;
    if (Firebase.apps.isEmpty) throw StateError('Firebase is not initialized.');
    return FirebaseDatabase.instance.ref('users/demo_user/coins');
  }

  @override
  Future<CoinState> load() async {
    final snapshot = await _resolvedReference.get();
    return CoinState.fromValue(snapshot.value);
  }

  @override
  Future<CoinState> merge(CoinState local) async {
    late CoinState merged;
    final result = await _resolvedReference.runTransaction((value) {
      merged = CoinState.fromValue(value).merge(local);
      final data = value is Map
          ? Map<String, Object?>.fromEntries(
              value.entries.map(
                (entry) => MapEntry(entry.key.toString(), entry.value),
              ),
            )
          : <String, Object?>{};
      data
        ..addAll(merged.toMap())
        ..['updatedAt'] = ServerValue.timestamp;
      return Transaction.success(data);
    });
    if (!result.committed) throw StateError('Coin sync was not committed.');
    return merged;
  }
}

class CoinRepository implements CoinStore {
  CoinRepository({
    SharedPreferencesAsync? preferences,
    CoinRemoteStore? remoteStore,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _remoteStore = remoteStore;

  static const String _stateKey = 'localCoinStateV2';
  static const String _pendingKey = 'localCoinStatePendingSyncV2';

  final SharedPreferencesAsync _preferences;
  final CoinRemoteStore? _remoteStore;
  Future<void>? _syncFuture;
  int _localMutationGeneration = 0;
  CoinState? _latestLocalMutation;

  CoinRemoteStore get _remote => _remoteStore ?? FirebaseCoinRemoteStore();

  @override
  Future<CoinState> load() async {
    final local = await _loadLocal();
    unawaited(synchronize());
    return local;
  }

  Future<CoinState> awardCompletedDays({
    required CoinState state,
    required Map<String, DailyStats> records,
    DateTime? now,
  }) async {
    final today = DateTime.parse(postureDateKey(now));
    var total = state.totalCoins;
    final awarded = {...state.awardedDates};
    final eligibleDates = records.keys.toList()..sort();
    for (final dateKey in eligibleDates) {
      final date = DateTime.tryParse(dateKey);
      final stats = records[dateKey];
      if (date == null ||
          !date.isBefore(today) ||
          stats == null ||
          !stats.hasTrackedPosture ||
          (state.awardedThroughDate != null &&
              dateKey.compareTo(state.awardedThroughDate!) <= 0) ||
          awarded.contains(dateKey)) {
        continue;
      }
      total += stats.dailyScore.round().clamp(0, 100);
      awarded.add(dateKey);
    }
    final updated = CoinState(
      totalCoins: total,
      awardedDates: awarded,
      awardedThroughDate: state.awardedThroughDate,
      balanceRevision: state.balanceRevision,
    );
    if (updated.totalCoins != state.totalCoins ||
        updated.awardedDates.length != state.awardedDates.length) {
      await _saveMutation(updated);
      unawaited(synchronize());
    }
    return updated;
  }

  @override
  Future<CoinState> setTotalCoins(CoinState state, int totalCoins) async {
    if (totalCoins < 0) {
      throw ArgumentError.value(totalCoins, 'totalCoins', 'Cannot be negative');
    }
    final updated = CoinState(
      totalCoins: totalCoins,
      awardedDates: state.awardedDates,
      awardedThroughDate: state.awardedThroughDate,
      balanceRevision: state.balanceRevision + 1,
    );
    await _saveMutation(updated);
    unawaited(synchronize());
    return updated;
  }

  Future<void> synchronize() => _syncFuture ??= _synchronize();

  Future<void> _synchronize() async {
    try {
      while (true) {
        final syncGeneration = _localMutationGeneration;
        var local = await _loadLocal();
        final latestMutation = _latestLocalMutation;
        if (latestMutation != null) local = local.merge(latestMutation);
        final pending =
            (await _preferences.getBool(_pendingKey) ?? false) ||
            latestMutation != null;
        final merged = pending
            ? await _remote.merge(local)
            : local.merge(await _remote.load());

        // A box purchase or coin award may finish while the remote request is
        // in flight. Retry with that newer local state instead of allowing the
        // older synchronization snapshot to overwrite it.
        if (_localMutationGeneration != syncGeneration) continue;
        await _saveLocal(merged, pending: false);
        if (_localMutationGeneration != syncGeneration) continue;
        _latestLocalMutation = null;
        break;
      }
    } catch (_) {
      // Balance and award history stay available locally while offline.
    } finally {
      _syncFuture = null;
    }
  }

  Future<void> _saveMutation(CoinState state) async {
    final generation = ++_localMutationGeneration;
    _latestLocalMutation = state;
    try {
      await _saveLocal(state, pending: true);
    } catch (_) {
      if (_localMutationGeneration == generation) {
        _latestLocalMutation = null;
      }
      rethrow;
    }
  }

  Future<CoinState> _loadLocal() async {
    final encoded = await _preferences.getString(_stateKey);
    if (encoded == null || encoded.isEmpty) return const CoinState();
    try {
      return CoinState.fromValue(jsonDecode(encoded));
    } catch (_) {
      return const CoinState();
    }
  }

  Future<void> _saveLocal(CoinState state, {required bool pending}) async {
    await _preferences.setString(_stateKey, jsonEncode(state.toMap()));
    await _preferences.setBool(_pendingKey, pending);
  }
}
