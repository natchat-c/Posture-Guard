import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cosmetics.dart';
import 'preferences_service.dart';
import 'user_database_paths.dart';

abstract class CosmeticStore {
  Future<CosmeticSelection> load();

  Future<void> save(CosmeticSelection selection);

  Future<Set<String>> loadOwnedIds();

  Future<Set<String>> unlock(String cosmeticId);
}

abstract class CosmeticOwnershipRemoteStore {
  Future<Set<String>> load();

  Future<Set<String>> merge(Set<String> localOwnedIds);
}

class FirebaseCosmeticOwnershipRemoteStore
    implements CosmeticOwnershipRemoteStore {
  FirebaseCosmeticOwnershipRemoteStore({
    DatabaseReference? reference,
    UserDatabaseReferenceFactory? referenceFactory,
  }) : _reference = reference,
       _referenceFactory = referenceFactory ?? UserDatabaseReferenceFactory();

  final DatabaseReference? _reference;
  final UserDatabaseReferenceFactory _referenceFactory;

  Future<DatabaseReference> get _resolvedReference async {
    return _reference ?? await _referenceFactory.cosmetics();
  }

  @override
  Future<Set<String>> load() async {
    final reference = await _resolvedReference;
    final snapshot = await reference.get();
    return _ownedIdsFromCloudValue(snapshot.value);
  }

  @override
  Future<Set<String>> merge(Set<String> localOwnedIds) async {
    late Set<String> merged;
    final reference = await _resolvedReference;
    final result = await reference.runTransaction((value) {
      merged = _normalizeOwnedIds({
        ..._ownedIdsFromCloudValue(value),
        ...localOwnedIds,
      });
      final data = value is Map
          ? Map<String, Object?>.fromEntries(
              value.entries.map(
                (entry) => MapEntry(entry.key.toString(), entry.value),
              ),
            )
          : <String, Object?>{};
      data
        ..['ownedIds'] = (merged.toList()..sort())
        ..['updatedAt'] = ServerValue.timestamp;
      return Transaction.success(data);
    });
    if (!result.committed) {
      throw StateError('Cosmetic ownership sync was not committed.');
    }
    return merged;
  }
}

class CosmeticRepository implements CosmeticStore {
  CosmeticRepository({
    SharedPreferencesAsync? preferences,
    CosmeticOwnershipRemoteStore? remoteStore,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _remoteStore = remoteStore;

  final SharedPreferencesAsync _preferences;
  final CosmeticOwnershipRemoteStore? _remoteStore;
  Future<void>? _syncFuture;
  int _localMutationGeneration = 0;
  Set<String>? _latestLocalMutation;

  static const int currentEconomyVersion = 1;

  CosmeticOwnershipRemoteStore get _remote =>
      _remoteStore ?? FirebaseCosmeticOwnershipRemoteStore();

  @override
  Future<CosmeticSelection> load() async {
    final ownedIds = await loadOwnedIds();
    final hatId = await _preferences.getString(PreferenceKeys.equippedHatId);
    final eyewearId = await _preferences.getString(
      PreferenceKeys.equippedEyewearId,
    );
    final holdingId = await _preferences.getString(
      PreferenceKeys.equippedHoldingId,
    );
    final backId = await _preferences.getString(PreferenceKeys.equippedBackId);
    final activeHatId = _ownedActiveId(hatId, CosmeticCategory.hat, ownedIds);
    final activeEyewearId = _ownedActiveId(
      eyewearId,
      CosmeticCategory.eyewear,
      ownedIds,
    );
    final activeHoldingId = _ownedActiveId(
      holdingId,
      CosmeticCategory.holding,
      ownedIds,
    );
    final activeBackId = _ownedActiveId(
      backId,
      CosmeticCategory.back,
      ownedIds,
    );
    if (hatId != null && activeHatId == null) {
      await _preferences.remove(PreferenceKeys.equippedHatId);
    }
    if (eyewearId != null && activeEyewearId == null) {
      await _preferences.remove(PreferenceKeys.equippedEyewearId);
    }
    if (holdingId != null && activeHoldingId == null) {
      await _preferences.remove(PreferenceKeys.equippedHoldingId);
    }
    if (backId != null && activeBackId == null) {
      await _preferences.remove(PreferenceKeys.equippedBackId);
    }
    return CosmeticSelection(
      hatId: activeHatId,
      eyewearId: activeEyewearId,
      holdingId: activeHoldingId,
      backId: activeBackId,
    );
  }

  @override
  Future<void> save(CosmeticSelection selection) async {
    final ownedIds = await loadOwnedIds();
    await _writeOrRemove(
      PreferenceKeys.equippedHatId,
      _ownedActiveId(selection.hatId, CosmeticCategory.hat, ownedIds),
    );
    await _writeOrRemove(
      PreferenceKeys.equippedEyewearId,
      _ownedActiveId(selection.eyewearId, CosmeticCategory.eyewear, ownedIds),
    );
    await _writeOrRemove(
      PreferenceKeys.equippedHoldingId,
      _ownedActiveId(selection.holdingId, CosmeticCategory.holding, ownedIds),
    );
    await _writeOrRemove(
      PreferenceKeys.equippedBackId,
      _ownedActiveId(selection.backId, CosmeticCategory.back, ownedIds),
    );
  }

  @override
  Future<Set<String>> loadOwnedIds() async {
    final ownedIds = await _loadOwnedIdsLocal();
    unawaited(synchronize());
    return ownedIds;
  }

  Future<Set<String>> _loadOwnedIdsLocal() async {
    await _migrateEconomyOnce();
    final stored = await _preferences.getStringList(
      PreferenceKeys.ownedCosmeticIds,
    );
    final ownedIds = _normalizeOwnedIds(stored ?? const <String>[]);
    final normalized = ownedIds.toList()..sort();
    if (!_sameIds(stored, normalized)) {
      await _preferences.setStringList(
        PreferenceKeys.ownedCosmeticIds,
        normalized,
      );
    }
    if (await _preferences.getBool(
          PreferenceKeys.cosmeticOwnershipPendingSync,
        ) ==
        null) {
      // Existing installations predate cloud cosmetic ownership. Seed their
      // current local collection on the first authenticated synchronization.
      await _preferences.setBool(
        PreferenceKeys.cosmeticOwnershipPendingSync,
        true,
      );
    }
    return Set.unmodifiable(ownedIds);
  }

  @override
  Future<Set<String>> unlock(String cosmeticId) async {
    if (CosmeticCatalog.find(cosmeticId) == null) {
      throw ArgumentError.value(cosmeticId, 'cosmeticId', 'Unknown cosmetic');
    }
    final ownedIds = {...await _loadOwnedIdsLocal(), cosmeticId};
    await _saveOwnershipMutation(ownedIds);
    unawaited(synchronize());
    return Set.unmodifiable(ownedIds);
  }

  Future<void> synchronize() => _syncFuture ??= _synchronize();

  Future<void> _synchronize() async {
    try {
      while (true) {
        final syncGeneration = _localMutationGeneration;
        var local = await _loadOwnedIdsLocal();
        final latestMutation = _latestLocalMutation;
        if (latestMutation != null) {
          local = _normalizeOwnedIds({...local, ...latestMutation});
        }
        final pending =
            (await _preferences.getBool(
                  PreferenceKeys.cosmeticOwnershipPendingSync,
                ) ??
                false) ||
            latestMutation != null;
        Set<String> merged;
        if (pending) {
          merged = await _remote.merge(local);
        } else {
          final cloud = await _remote.load();
          final union = _normalizeOwnedIds({...local, ...cloud});
          merged = cloud.containsAll(local)
              ? union
              : await _remote.merge(union);
        }

        if (_localMutationGeneration != syncGeneration) continue;

        // Another repository instance may have unlocked an item while the
        // cloud request was in flight. Union the latest persisted state and
        // retry instead of allowing a stale cloud snapshot to remove it.
        final newestLocal = await _loadOwnedIdsLocal();
        if (!merged.containsAll(newestLocal)) {
          await _saveOwnedIdsLocal(
            _normalizeOwnedIds({...merged, ...newestLocal}),
            pending: true,
          );
          continue;
        }

        await _saveOwnedIdsLocal(merged, pending: false);
        if (_localMutationGeneration != syncGeneration) continue;
        _latestLocalMutation = null;
        break;
      }
    } catch (_) {
      // Ownership remains immediately available locally while offline.
    } finally {
      _syncFuture = null;
    }
  }

  Future<void> _saveOwnershipMutation(Set<String> ownedIds) async {
    final generation = ++_localMutationGeneration;
    final normalized = _normalizeOwnedIds(ownedIds);
    _latestLocalMutation = normalized;
    try {
      await _saveOwnedIdsLocal(normalized, pending: true);
    } catch (_) {
      if (_localMutationGeneration == generation) {
        _latestLocalMutation = null;
      }
      rethrow;
    }
  }

  Future<void> _saveOwnedIdsLocal(
    Set<String> ownedIds, {
    required bool pending,
  }) async {
    await _preferences.setStringList(
      PreferenceKeys.ownedCosmeticIds,
      ownedIds.toList()..sort(),
    );
    await _preferences.setBool(
      PreferenceKeys.cosmeticOwnershipPendingSync,
      pending,
    );
  }

  Future<void> _migrateEconomyOnce() async {
    final version =
        await _preferences.getInt(PreferenceKeys.cosmeticEconomyVersion) ?? 0;
    if (version >= currentEconomyVersion) return;
    await _preferences.setStringList(
      PreferenceKeys.ownedCosmeticIds,
      CosmeticCatalog.starterIds.toList()..sort(),
    );
    await _preferences.setInt(
      PreferenceKeys.cosmeticEconomyVersion,
      currentEconomyVersion,
    );
  }

  String? _ownedActiveId(
    String? id,
    CosmeticCategory category,
    Set<String> ownedIds,
  ) {
    final activeId = CosmeticCatalog.find(id, category)?.id;
    return ownedIds.contains(activeId) ? activeId : null;
  }

  bool _sameIds(List<String>? stored, List<String> normalized) {
    if (stored == null || stored.length != normalized.length) return false;
    final sorted = [...stored]..sort();
    for (var index = 0; index < sorted.length; index++) {
      if (sorted[index] != normalized[index]) return false;
    }
    return true;
  }

  Future<void> _writeOrRemove(String key, String? value) {
    return value == null
        ? _preferences.remove(key)
        : _preferences.setString(key, value);
  }
}

Set<String> _normalizeOwnedIds(Iterable<String> ids) => {
  ...CosmeticCatalog.starterIds,
  for (final id in ids)
    if (CosmeticCatalog.find(id) != null) id,
};

Set<String> _ownedIdsFromCloudValue(Object? value) {
  Object? rawOwnedIds = value;
  if (value is Map) rawOwnedIds = value['ownedIds'];

  final ids = <String>[];
  if (rawOwnedIds is List) {
    ids.addAll(rawOwnedIds.map((value) => value.toString()));
  } else if (rawOwnedIds is Map) {
    for (final entry in rawOwnedIds.entries) {
      if (entry.value == true) ids.add(entry.key.toString());
    }
  }
  return Set.unmodifiable(_normalizeOwnedIds(ids));
}

class MemoryCosmeticStore implements CosmeticStore {
  MemoryCosmeticStore([
    this.selection = CosmeticSelection.none,
    Set<String>? ownedCosmeticIds,
  ]) : ownedCosmeticIds = {...CosmeticCatalog.starterIds, ...?ownedCosmeticIds};

  CosmeticSelection selection;
  final Set<String> ownedCosmeticIds;

  @override
  Future<CosmeticSelection> load() async {
    selection = _ownedSelection(selection);
    return selection;
  }

  @override
  Future<void> save(CosmeticSelection selection) async {
    this.selection = _ownedSelection(selection);
  }

  @override
  Future<Set<String>> loadOwnedIds() async =>
      Set.unmodifiable(ownedCosmeticIds);

  @override
  Future<Set<String>> unlock(String cosmeticId) async {
    if (CosmeticCatalog.find(cosmeticId) == null) {
      throw ArgumentError.value(cosmeticId, 'cosmeticId', 'Unknown cosmetic');
    }
    ownedCosmeticIds.add(cosmeticId);
    return loadOwnedIds();
  }

  CosmeticSelection _ownedSelection(CosmeticSelection value) {
    String? owned(String? id, CosmeticCategory category) {
      final activeId = CosmeticCatalog.find(id, category)?.id;
      return ownedCosmeticIds.contains(activeId) ? activeId : null;
    }

    return CosmeticSelection(
      hatId: owned(value.hatId, CosmeticCategory.hat),
      eyewearId: owned(value.eyewearId, CosmeticCategory.eyewear),
      holdingId: owned(value.holdingId, CosmeticCategory.holding),
      backId: owned(value.backId, CosmeticCategory.back),
    );
  }
}
