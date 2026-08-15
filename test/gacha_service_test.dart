import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/l10n/app_localizations.dart';
import 'package:postureguard/models/cosmetics.dart';
import 'package:postureguard/pages/customize_page.dart';
import 'package:postureguard/pages/shop_page.dart';
import 'package:postureguard/services/coin_repository.dart';
import 'package:postureguard/services/cosmetic_repository.dart';
import 'package:postureguard/services/gacha_service.dart';
import 'package:postureguard/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _SequenceRandom implements GachaRandomSource {
  _SequenceRandom({
    required List<double> doubles,
    List<int> integers = const [],
  }) : _doubles = List.of(doubles),
       _integers = List.of(integers);

  final List<double> _doubles;
  final List<int> _integers;
  int doubleCalls = 0;
  int intCalls = 0;

  @override
  double nextDouble() {
    doubleCalls++;
    return _doubles.removeAt(0);
  }

  @override
  int nextInt(int maximum) {
    intCalls++;
    final value = _integers.isEmpty ? 0 : _integers.removeAt(0);
    if (value < 0 || value >= maximum) {
      throw RangeError.range(value, 0, maximum);
    }
    return value;
  }
}

class _MemoryCoinStore implements CoinStore {
  _MemoryCoinStore(int coins) : state = CoinState(totalCoins: coins);

  CoinState state;
  int saveCalls = 0;

  @override
  Future<CoinState> load() async => state;

  @override
  Future<CoinState> setTotalCoins(CoinState current, int totalCoins) async {
    saveCalls++;
    state = CoinState(
      totalCoins: totalCoins,
      awardedDates: current.awardedDates,
      awardedThroughDate: current.awardedThroughDate,
      balanceRevision: current.balanceRevision + 1,
    );
    return state;
  }
}

class _BlockingCoinStore extends _MemoryCoinStore {
  _BlockingCoinStore(super.coins);

  final releaseLoad = Completer<void>();

  @override
  Future<CoinState> load() async {
    await releaseLoad.future;
    return super.load();
  }
}

class _OfflineCoinRemote implements CoinRemoteStore {
  @override
  Future<CoinState> load() => Future.error(StateError('offline'));

  @override
  Future<CoinState> merge(CoinState local) =>
      Future.error(StateError('offline'));
}

class _DelayedCoinRemote implements CoinRemoteStore {
  _DelayedCoinRemote(this.state);

  CoinState state;
  final loadStarted = Completer<void>();
  final releaseLoad = Completer<void>();

  @override
  Future<CoinState> load() async {
    if (!loadStarted.isCompleted) loadStarted.complete();
    await releaseLoad.future;
    return state;
  }

  @override
  Future<CoinState> merge(CoinState local) async {
    state = state.merge(local);
    return state;
  }
}

Widget _app(Widget home) {
  return MaterialApp(
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('rarity assignments and starter-only exclusions are exact', () {
    const expected = <CosmeticRarity, Set<String>>{
      CosmeticRarity.oneStar: {
        'cowboy_hat',
        'glasses3',
        'glasses',
        'brush',
        'candy',
        'coffee',
      },
      CosmeticRarity.twoStar: {
        'cat_ears',
        'flower_hat',
        'scholar_hat',
        'glasses2',
        'glasses4',
        'flowers',
        'gaming_controller',
      },
      CosmeticRarity.threeStar: {
        'santa_hat',
        'sunglasses',
        'magic_book',
        'microphone',
        'teddy_bear',
        'backpack',
        'bat_wings',
      },
      CosmeticRarity.fourStar: {
        'crown',
        'heart_glasses',
        'star_glasses',
        'magic_wand',
        'butterfly_wings',
        'devil_wings',
      },
      CosmeticRarity.fiveStar: {
        'halo',
        'angle_wings',
        'dragon_wings',
        'fairy_wings',
      },
    };

    for (final rarity in CosmeticRarity.values) {
      expect(
        CosmeticCatalog.all
            .where((item) => item.rarity == rarity)
            .map((item) => item.id)
            .toSet(),
        expected[rarity],
      );
    }
    expect(CosmeticCatalog.starterIds, {'cowboy_hat', 'glasses3'});
    expect(CosmeticCatalog.find('cowboy_hat')!.isStarter, isTrue);
    expect(CosmeticCatalog.find('glasses3')!.isStarter, isTrue);
    expect(CosmeticCatalog.find('crown')!.rarity, CosmeticRarity.fourStar);
    expect(CosmeticCatalog.find('magic_wand')!.rarity, CosmeticRarity.fourStar);
    expect(
      CosmeticCatalog.find('dragon_wings')!.rarity,
      CosmeticRarity.fiveStar,
    );
    expect(
      CosmeticCatalog.find('fairy_wings')!.rarity,
      CosmeticRarity.fiveStar,
    );
    expect(
      CosmeticCatalog.gachaPool.map((item) => item.id),
      isNot(contains(anyOf(CosmeticCatalog.starterIds))),
    );
  });

  test('Standard and Premium configurations use exact costs and odds', () {
    expect(GachaConfiguration.standard.cost, 100);
    expect(GachaConfiguration.standard.rarityOdds, const {
      CosmeticRarity.oneStar: 45,
      CosmeticRarity.twoStar: 30,
      CosmeticRarity.threeStar: 15,
      CosmeticRarity.fourStar: 8,
      CosmeticRarity.fiveStar: 2,
    });
    expect(GachaConfiguration.premium.cost, 300);
    expect(GachaConfiguration.premium.rarityOdds, const {
      CosmeticRarity.oneStar: 10,
      CosmeticRarity.twoStar: 20,
      CosmeticRarity.threeStar: 30,
      CosmeticRarity.fourStar: 25,
      CosmeticRarity.fiveStar: 15,
    });
    expect(
      GachaConfiguration.standard.rarityOdds.values.reduce((a, b) => a + b),
      100,
    );
    expect(
      GachaConfiguration.premium.rarityOdds.values.reduce((a, b) => a + b),
      100,
    );
  });

  test('Standard deterministic rarity boundaries are exact', () {
    final service = GachaService(randomSource: _SequenceRandom(doubles: [0]));
    const cases = [
      (roll: 0.00, rarity: CosmeticRarity.oneStar),
      (roll: 0.449999, rarity: CosmeticRarity.oneStar),
      (roll: 0.45, rarity: CosmeticRarity.twoStar),
      (roll: 0.749999, rarity: CosmeticRarity.twoStar),
      (roll: 0.75, rarity: CosmeticRarity.threeStar),
      (roll: 0.899999, rarity: CosmeticRarity.threeStar),
      (roll: 0.90, rarity: CosmeticRarity.fourStar),
      (roll: 0.979999, rarity: CosmeticRarity.fourStar),
      (roll: 0.98, rarity: CosmeticRarity.fiveStar),
      (roll: 0.999999, rarity: CosmeticRarity.fiveStar),
    ];
    for (final testCase in cases) {
      expect(
        service.rarityForRoll(GachaBoxType.standard, testCase.roll),
        testCase.rarity,
        reason: '${testCase.roll}',
      );
    }
  });

  test('Premium deterministic rarity boundaries are exact', () {
    final service = GachaService(randomSource: _SequenceRandom(doubles: [0]));
    const cases = [
      (roll: 0.00, rarity: CosmeticRarity.oneStar),
      (roll: 0.099999, rarity: CosmeticRarity.oneStar),
      (roll: 0.10, rarity: CosmeticRarity.twoStar),
      (roll: 0.299999, rarity: CosmeticRarity.twoStar),
      (roll: 0.30, rarity: CosmeticRarity.threeStar),
      (roll: 0.599999, rarity: CosmeticRarity.threeStar),
      (roll: 0.60, rarity: CosmeticRarity.fourStar),
      (roll: 0.849999, rarity: CosmeticRarity.fourStar),
      (roll: 0.85, rarity: CosmeticRarity.fiveStar),
      (roll: 0.999999, rarity: CosmeticRarity.fiveStar),
    ];
    for (final testCase in cases) {
      expect(
        service.rarityForRoll(GachaBoxType.premium, testCase.roll),
        testCase.rarity,
        reason: '${testCase.roll}',
      );
    }
  });

  test('new unlock deducts cost and persists one owned cosmetic', () async {
    final preferences = SharedPreferencesAsync();
    final cosmetics = CosmeticRepository(preferences: preferences);
    final coins = _MemoryCoinStore(500);
    final service = GachaShopService(
      coinStore: coins,
      cosmeticStore: cosmetics,
      gachaService: GachaService(
        randomSource: _SequenceRandom(doubles: [0.90], integers: [3]),
      ),
    );

    final result = await service.openBox(GachaBoxType.standard);

    expect(result.status, GachaPurchaseStatus.newUnlock);
    expect(result.item?.id, 'magic_wand');
    expect(result.coinBalance, 400);
    expect(result.duplicateRefund, 0);
    expect(await CosmeticRepository(preferences: preferences).loadOwnedIds(), {
      'cowboy_hat',
      'glasses3',
      'magic_wand',
    });
  });

  test(
    'offline restart retains unlocked cosmetic, equipment, and coin balance',
    () async {
      final preferences = SharedPreferencesAsync();
      final cosmetics = CosmeticRepository(preferences: preferences);
      final coins = CoinRepository(
        preferences: preferences,
        remoteStore: _OfflineCoinRemote(),
      );
      await coins.setTotalCoins(const CoinState(), 500);
      final result = await GachaShopService(
        coinStore: coins,
        cosmeticStore: cosmetics,
        gachaService: GachaService(
          randomSource: _SequenceRandom(doubles: [0.99], integers: [2]),
        ),
      ).openBox(GachaBoxType.standard);
      expect(result.item?.id, 'dragon_wings');
      expect(result.coinBalance, 400);

      await cosmetics.save(const CosmeticSelection(backId: 'dragon_wings'));
      final reopenedCosmetics = CosmeticRepository(preferences: preferences);
      final reopenedCoins = CoinRepository(
        preferences: preferences,
        remoteStore: _OfflineCoinRemote(),
      );
      expect(await reopenedCosmetics.loadOwnedIds(), contains('dragon_wings'));
      expect(
        await reopenedCosmetics.load(),
        const CosmeticSelection(backId: 'dragon_wings'),
      );
      expect((await reopenedCoins.load()).totalCoins, 400);
    },
  );

  test('an in-flight cloud read cannot restore coins spent locally', () async {
    final preferences = SharedPreferencesAsync();
    const initial = CoinState(totalCoins: 500);
    await preferences.setString(
      'localCoinStateV2',
      jsonEncode(initial.toMap()),
    );
    final remote = _DelayedCoinRemote(initial);
    final coins = CoinRepository(preferences: preferences, remoteStore: remote);

    final loaded = await coins.load();
    await remote.loadStarted.future;
    await coins.setTotalCoins(loaded, 400);
    remote.releaseLoad.complete();
    await coins.synchronize();

    final reopened = CoinRepository(
      preferences: preferences,
      remoteStore: _OfflineCoinRemote(),
    );
    expect((await reopened.load()).totalCoins, 400);
    expect(remote.state.totalCoins, 400);
    expect(remote.state.balanceRevision, 1);
  });

  test(
    'three-star duplicate refunds 75 for a net Standard cost of 25',
    () async {
      final cosmetics = MemoryCosmeticStore(CosmeticSelection.none, {
        'magic_book',
      });
      final coins = _MemoryCoinStore(500);
      final service = GachaShopService(
        coinStore: coins,
        cosmeticStore: cosmetics,
        gachaService: GachaService(
          randomSource: _SequenceRandom(doubles: [0.75], integers: [2]),
        ),
      );

      final before = (await cosmetics.loadOwnedIds()).length;
      final result = await service.openBox(GachaBoxType.standard);

      expect(result.status, GachaPurchaseStatus.duplicate);
      expect(result.item?.id, 'magic_book');
      expect(result.duplicateRefund, 75);
      expect(result.coinBalance, 475);
      expect((await cosmetics.loadOwnedIds()).length, before);
    },
  );

  test('five-star duplicate uses the exact 300-coin refund', () async {
    final cosmetics = MemoryCosmeticStore(CosmeticSelection.none, {
      'dragon_wings',
    });
    final service = GachaShopService(
      coinStore: _MemoryCoinStore(500),
      cosmeticStore: cosmetics,
      gachaService: GachaService(
        randomSource: _SequenceRandom(doubles: [0.99], integers: [2]),
      ),
    );

    final result = await service.openBox(GachaBoxType.standard);

    expect(result.item?.id, 'dragon_wings');
    expect(result.status, GachaPurchaseStatus.duplicate);
    expect(result.duplicateRefund, 300);
    expect(result.coinBalance, 700);
  });

  test('insufficient balances never roll, save, or become negative', () async {
    for (final testCase in const [
      (type: GachaBoxType.standard, balance: 99),
      (type: GachaBoxType.premium, balance: 299),
    ]) {
      final random = _SequenceRandom(doubles: [0]);
      final coins = _MemoryCoinStore(testCase.balance);
      final result = await GachaShopService(
        coinStore: coins,
        cosmeticStore: MemoryCosmeticStore(),
        gachaService: GachaService(randomSource: random),
      ).openBox(testCase.type);

      expect(result.status, GachaPurchaseStatus.insufficientCoins);
      expect(result.coinBalance, testCase.balance);
      expect(coins.saveCalls, 0);
      expect(random.doubleCalls, 0);
      expect(random.intCalls, 0);
    }
  });

  test('opening guard rejects a rapid second transaction', () async {
    final coins = _BlockingCoinStore(500);
    final service = GachaShopService(
      coinStore: coins,
      cosmeticStore: MemoryCosmeticStore(),
      gachaService: GachaService(
        randomSource: _SequenceRandom(doubles: [0.0], integers: [0]),
      ),
    );

    final first = service.openBox(GachaBoxType.standard);
    final second = await service.openBox(GachaBoxType.standard);
    expect(second.status, GachaPurchaseStatus.busy);
    coins.releaseLoad.complete();
    expect((await first).status, GachaPurchaseStatus.newUnlock);
    expect(coins.saveCalls, 1);
  });

  test(
    'one-time economy migration preserves coins and only resets old free ownership',
    () async {
      final preferences = SharedPreferencesAsync();
      final coinJson = jsonEncode(const CoinState(totalCoins: 1485).toMap());
      await preferences.setString('localCoinStateV2', coinJson);
      await preferences.setStringList(
        PreferenceKeys.ownedCosmeticIds,
        CosmeticCatalog.all.map((item) => item.id).toList(),
      );
      await preferences.setString(PreferenceKeys.equippedHatId, 'crown');
      await preferences.setString(PreferenceKeys.equippedEyewearId, 'glasses3');
      await preferences.setString(
        PreferenceKeys.equippedHoldingId,
        'magic_wand',
      );
      await preferences.setString(
        PreferenceKeys.equippedBackId,
        'dragon_wings',
      );

      final repository = CosmeticRepository(preferences: preferences);
      expect(await repository.loadOwnedIds(), {'cowboy_hat', 'glasses3'});
      expect(
        await repository.load(),
        const CosmeticSelection(eyewearId: 'glasses3'),
      );
      expect(await preferences.getString('localCoinStateV2'), coinJson);
      expect(
        await preferences.getInt(PreferenceKeys.cosmeticEconomyVersion),
        CosmeticRepository.currentEconomyVersion,
      );

      await repository.unlock('dragon_wings');
      expect(
        await CosmeticRepository(preferences: preferences).loadOwnedIds(),
        {'cowboy_hat', 'glasses3', 'dragon_wings'},
      );
      expect(await preferences.getString('localCoinStateV2'), coinJson);
    },
  );

  testWidgets('Customize shows owned items only and keeps None available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryCosmeticStore(CosmeticSelection.none, {'magic_wand'});
    await tester.pumpWidget(
      _app(Customizes(cosmeticStore: store, coinStore: _MemoryCoinStore(0))),
    );
    await tester.pumpAndSettle();

    final starter = find.byKey(const Key('customize-hat-cowboy_hat'));
    expect(find.text('Cowboy Hat'), findsOneWidget);
    expect(find.text('Bold Glasses'), findsOneWidget);
    expect(find.text('Magic Wand'), findsOneWidget);
    expect(find.text('Crown'), findsNothing);
    expect(find.text('Halo'), findsNothing);
    expect(find.text('Dragon Wings'), findsNothing);
    expect(find.byIcon(Icons.lock), findsNothing);
    for (final category in CosmeticCategory.values) {
      expect(
        find.byKey(Key('customize-${category.name}-none')),
        findsOneWidget,
      );
    }

    await tester.tap(starter);
    await tester.pumpAndSettle();
    expect(store.selection.hatId, 'cowboy_hat');
    await tester.tap(find.byKey(const Key('customize-hat-none')));
    await tester.pumpAndSettle();
    expect(store.selection, CosmeticSelection.none);
  });

  testWidgets('box help dialogs show centralized odds and duplicate rewards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(
        Shop(
          cosmeticStore: MemoryCosmeticStore(),
          coinStore: _MemoryCoinStore(500),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('45%'), findsNothing);
    expect(find.text('15%'), findsNothing);
    for (final type in GachaBoxType.values) {
      await tester.tap(find.byKey(Key('odds-help-${type.name}')));
      await tester.pumpAndSettle();
      final config = GachaConfiguration.forType(type);
      expect(find.byKey(Key('oddsDialog-${type.name}')), findsOneWidget);
      expect(find.text('Cost: ${config.cost} coins'), findsOneWidget);
      expect(find.text('Duplicates are converted into coins.'), findsOneWidget);
      for (final rarity in CosmeticRarity.values) {
        final oddsRow = find.byKey(Key('odds-${type.name}-${rarity.name}'));
        expect(oddsRow, findsOneWidget);
        expect(
          find.descendant(
            of: oddsRow,
            matching: find.text('${config.rarityOdds[rarity]}%'),
          ),
          findsOneWidget,
        );
        final refundRow = find.byKey(Key('refund-${type.name}-${rarity.name}'));
        expect(refundRow, findsOneWidget);
        expect(
          find.descendant(
            of: refundRow,
            matching: find.text(
              '${GachaConfiguration.duplicateRefund(rarity)} coins',
            ),
          ),
          findsOneWidget,
        );
      }
      await tester.tap(find.byKey(Key('close-${type.name}-odds')));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Shop collection still shows unowned cosmetics as locked', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(
        Shop(
          cosmeticStore: MemoryCosmeticStore(),
          coinStore: _MemoryCoinStore(0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shop-item-crown')), findsOneWidget);
    expect(find.byKey(const Key('shop-item-halo')), findsOneWidget);
    for (var index = 0; index < 12; index++) {
      await tester.drag(
        find.byKey(const Key('shopScrollView')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
    }
    final dragon = find.byKey(const Key('shop-item-dragon_wings'));
    expect(dragon, findsOneWidget);
    expect(
      find.descendant(of: dragon, matching: find.byIcon(Icons.lock)),
      findsOneWidget,
    );
  });

  testWidgets(
    'Shop opens once per rapid tap and shows new then duplicate results',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cosmetics = MemoryCosmeticStore();
      final coins = _BlockingCoinStore(500);
      final random = _SequenceRandom(doubles: [0.90, 0.90], integers: [3, 3]);
      await tester.pumpWidget(
        _app(
          Shop(
            cosmeticStore: cosmetics,
            coinStore: coins,
            gachaService: GachaService(randomSource: random),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final open = find.byKey(const Key('open-standard-box'));
      await tester.tap(open);
      await tester.tap(open);
      expect(find.byKey(const Key('gachaResultDialog')), findsNothing);
      coins.releaseLoad.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('gachaResultDialog')), findsOneWidget);
      expect(find.text('NEW!'), findsOneWidget);
      expect(find.text('Magic Wand'), findsOneWidget);
      expect(find.text('Unlocked'), findsOneWidget);
      expect(coins.state.totalCoins, 400);
      expect(coins.saveCalls, 1);
      expect(await cosmetics.loadOwnedIds(), contains('magic_wand'));

      await tester.tap(find.byKey(const Key('gachaResultOkButton')));
      await tester.pumpAndSettle();
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.text('Duplicate'), findsOneWidget);
      expect(find.text('Converted to +150 coins'), findsOneWidget);
      expect(coins.state.totalCoins, 450);
      expect(coins.saveCalls, 2);
    },
  );

  testWidgets('Shop reports insufficient coins without awarding anything', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cosmetics = MemoryCosmeticStore();
    final coins = _MemoryCoinStore(99);
    await tester.pumpWidget(
      _app(Shop(cosmeticStore: cosmetics, coinStore: coins)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-standard-box')));
    await tester.pump();
    expect(find.text('Not enough coins'), findsOneWidget);
    expect(find.byKey(const Key('gachaResultDialog')), findsNothing);
    expect(coins.state.totalCoins, 99);
    expect(coins.saveCalls, 0);
    expect(await cosmetics.loadOwnedIds(), CosmeticCatalog.starterIds);
  });
}
