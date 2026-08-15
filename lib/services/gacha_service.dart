import 'dart:math';

import '../models/cosmetics.dart';
import 'coin_repository.dart';
import 'cosmetic_repository.dart';

enum GachaBoxType { standard, premium }

class GachaBoxConfig {
  const GachaBoxConfig({
    required this.type,
    required this.cost,
    required this.rarityOdds,
  });

  final GachaBoxType type;
  final int cost;
  final Map<CosmeticRarity, int> rarityOdds;
}

class GachaConfiguration {
  const GachaConfiguration._();

  static const standard = GachaBoxConfig(
    type: GachaBoxType.standard,
    cost: 100,
    rarityOdds: {
      CosmeticRarity.oneStar: 45,
      CosmeticRarity.twoStar: 30,
      CosmeticRarity.threeStar: 15,
      CosmeticRarity.fourStar: 8,
      CosmeticRarity.fiveStar: 2,
    },
  );

  static const premium = GachaBoxConfig(
    type: GachaBoxType.premium,
    cost: 300,
    rarityOdds: {
      CosmeticRarity.oneStar: 10,
      CosmeticRarity.twoStar: 20,
      CosmeticRarity.threeStar: 30,
      CosmeticRarity.fourStar: 25,
      CosmeticRarity.fiveStar: 15,
    },
  );

  static const duplicateRefunds = <CosmeticRarity, int>{
    CosmeticRarity.oneStar: 20,
    CosmeticRarity.twoStar: 40,
    CosmeticRarity.threeStar: 75,
    CosmeticRarity.fourStar: 150,
    CosmeticRarity.fiveStar: 300,
  };

  static GachaBoxConfig forType(GachaBoxType type) => switch (type) {
    GachaBoxType.standard => standard,
    GachaBoxType.premium => premium,
  };

  static int duplicateRefund(CosmeticRarity rarity) =>
      duplicateRefunds[rarity]!;
}

abstract class GachaRandomSource {
  double nextDouble();

  int nextInt(int maximum);
}

class SecureGachaRandomSource implements GachaRandomSource {
  SecureGachaRandomSource() : _random = Random.secure();

  final Random _random;

  @override
  double nextDouble() => _random.nextDouble();

  @override
  int nextInt(int maximum) => _random.nextInt(maximum);
}

class GachaService {
  GachaService({GachaRandomSource? randomSource})
    : _randomSource = randomSource ?? SecureGachaRandomSource();

  final GachaRandomSource _randomSource;

  CosmeticRarity rarityForRoll(GachaBoxType type, double roll) {
    if (!roll.isFinite || roll < 0 || roll >= 1) {
      throw RangeError.range(roll, 0, 1, 'roll', 'Must be in [0, 1)');
    }
    final odds = GachaConfiguration.forType(type).rarityOdds;
    final bucket = (roll * 1000000).floor();
    var upperBoundary = 0;
    for (final rarity in CosmeticRarity.values) {
      upperBoundary += odds[rarity]! * 10000;
      if (bucket < upperBoundary) return rarity;
    }
    return CosmeticRarity.fiveStar;
  }

  CosmeticItem draw(GachaBoxType type) {
    final rarity = rarityForRoll(type, _randomSource.nextDouble());
    final pool = CosmeticCatalog.gachaPoolForRarity(rarity);
    if (pool.isEmpty) {
      throw StateError('No gacha cosmetics configured for ${rarity.name}.');
    }
    return pool[_randomSource.nextInt(pool.length)];
  }
}

enum GachaPurchaseStatus { newUnlock, duplicate, insufficientCoins, busy }

class GachaPurchaseResult {
  const GachaPurchaseResult({
    required this.status,
    required this.boxType,
    required this.coinBalance,
    this.item,
    this.duplicateRefund = 0,
  });

  final GachaPurchaseStatus status;
  final GachaBoxType boxType;
  final int? coinBalance;
  final CosmeticItem? item;
  final int duplicateRefund;

  bool get isNewUnlock => status == GachaPurchaseStatus.newUnlock;
  bool get isDuplicate => status == GachaPurchaseStatus.duplicate;
}

class GachaShopService {
  GachaShopService({
    required CoinStore coinStore,
    required CosmeticStore cosmeticStore,
    GachaService? gachaService,
  }) : _coinStore = coinStore,
       _cosmeticStore = cosmeticStore,
       _gachaService = gachaService ?? GachaService();

  final CoinStore _coinStore;
  final CosmeticStore _cosmeticStore;
  final GachaService _gachaService;
  bool _opening = false;

  bool get isOpening => _opening;

  Future<GachaPurchaseResult> openBox(GachaBoxType boxType) async {
    if (_opening) {
      return GachaPurchaseResult(
        status: GachaPurchaseStatus.busy,
        boxType: boxType,
        coinBalance: null,
      );
    }
    _opening = true;
    try {
      final configuration = GachaConfiguration.forType(boxType);
      final coinState = await _coinStore.load();
      if (coinState.totalCoins < configuration.cost) {
        return GachaPurchaseResult(
          status: GachaPurchaseStatus.insufficientCoins,
          boxType: boxType,
          coinBalance: coinState.totalCoins,
        );
      }

      final ownedIds = await _cosmeticStore.loadOwnedIds();
      final item = _gachaService.draw(boxType);
      final duplicate = ownedIds.contains(item.id);
      final refund = duplicate
          ? GachaConfiguration.duplicateRefund(item.rarity)
          : 0;
      final nextBalance = coinState.totalCoins - configuration.cost + refund;
      final savedCoins = await _coinStore.setTotalCoins(coinState, nextBalance);
      if (!duplicate) await _cosmeticStore.unlock(item.id);

      return GachaPurchaseResult(
        status: duplicate
            ? GachaPurchaseStatus.duplicate
            : GachaPurchaseStatus.newUnlock,
        boxType: boxType,
        coinBalance: savedCoins.totalCoins,
        item: item,
        duplicateRefund: refund,
      );
    } finally {
      _opening = false;
    }
  }
}
