import 'package:shared_preferences/shared_preferences.dart';

import '../models/cosmetics.dart';
import 'preferences_service.dart';

abstract class CosmeticStore {
  Future<CosmeticSelection> load();

  Future<void> save(CosmeticSelection selection);

  Future<Set<String>> loadOwnedIds();

  Future<Set<String>> unlock(String cosmeticId);
}

class CosmeticRepository implements CosmeticStore {
  CosmeticRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  static const int currentEconomyVersion = 1;

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
    await _migrateEconomyOnce();
    final stored = await _preferences.getStringList(
      PreferenceKeys.ownedCosmeticIds,
    );
    final ownedIds = <String>{
      ...CosmeticCatalog.starterIds,
      for (final id in stored ?? const <String>[])
        if (CosmeticCatalog.find(id) != null) id,
    };
    final normalized = ownedIds.toList()..sort();
    if (!_sameIds(stored, normalized)) {
      await _preferences.setStringList(
        PreferenceKeys.ownedCosmeticIds,
        normalized,
      );
    }
    return Set.unmodifiable(ownedIds);
  }

  @override
  Future<Set<String>> unlock(String cosmeticId) async {
    if (CosmeticCatalog.find(cosmeticId) == null) {
      throw ArgumentError.value(cosmeticId, 'cosmeticId', 'Unknown cosmetic');
    }
    final ownedIds = {...await loadOwnedIds(), cosmeticId};
    await _preferences.setStringList(
      PreferenceKeys.ownedCosmeticIds,
      ownedIds.toList()..sort(),
    );
    return Set.unmodifiable(ownedIds);
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
