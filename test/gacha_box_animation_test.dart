import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/l10n/app_localizations.dart';
import 'package:postureguard/models/cosmetics.dart';
import 'package:postureguard/pages/shop_page.dart';
import 'package:postureguard/services/coin_repository.dart';
import 'package:postureguard/services/cosmetic_repository.dart';
import 'package:postureguard/services/gacha_service.dart';
import 'package:postureguard/widgets/gacha_box_visual.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _CountingCoinStore implements CoinStore {
  _CountingCoinStore(int coins) : state = CoinState(totalCoins: coins);

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

class _CountingCosmeticStore extends MemoryCosmeticStore {
  _CountingCosmeticStore([Set<String>? ownedIds])
    : super(CosmeticSelection.none, ownedIds);

  int unlockCalls = 0;

  @override
  Future<Set<String>> unlock(String cosmeticId) async {
    unlockCalls++;
    return super.unlock(cosmeticId);
  }
}

class _FixedRandom implements GachaRandomSource {
  int doubleCalls = 0;
  int intCalls = 0;

  @override
  double nextDouble() {
    doubleCalls++;
    return 0.99;
  }

  @override
  int nextInt(int maximum) {
    intCalls++;
    return 0;
  }
}

Widget _app(Widget home, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
}

Future<void> _waitForOpeningOverlay(WidgetTester tester) async {
  for (
    var attempt = 0;
    attempt < 10 &&
        find.byKey(const Key('gachaAnimationTapTarget')).evaluate().isEmpty;
    attempt++
  ) {
    await tester.pump();
  }
  expect(find.byKey(const Key('gachaAnimationTapTarget')), findsOneWidget);
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('Standard and Premium use the exact split box assets', (
    tester,
  ) async {
    expect(
      GachaBoxAssetLayout.standard.baseAsset,
      'images/boxes/normal_box.png',
    );
    expect(
      GachaBoxAssetLayout.standard.lidAsset,
      'images/boxes/normal_lid.png',
    );
    expect(GachaBoxAssetLayout.premium.baseAsset, 'images/boxes/elite_box.png');
    expect(GachaBoxAssetLayout.premium.lidAsset, 'images/boxes/elite_lid.png');

    await tester.pumpWidget(
      _app(
        const Row(
          children: [
            Expanded(
              child: GachaBoxVisual(
                type: GachaBoxType.standard,
                keyPrefix: 'assetTest',
              ),
            ),
            Expanded(
              child: GachaBoxVisual(
                type: GachaBoxType.premium,
                keyPrefix: 'assetTest',
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    String assetFor(Key key) {
      final image = tester.widget<Image>(find.byKey(key));
      return (image.image as AssetImage).assetName;
    }

    expect(
      assetFor(const Key('assetTest-base-standard')),
      GachaBoxAssetLayout.standard.baseAsset,
    );
    expect(
      assetFor(const Key('assetTest-lid-standard')),
      GachaBoxAssetLayout.standard.lidAsset,
    );
    expect(
      assetFor(const Key('assetTest-base-premium')),
      GachaBoxAssetLayout.premium.baseAsset,
    );
    expect(
      assetFor(const Key('assetTest-lid-premium')),
      GachaBoxAssetLayout.premium.lidAsset,
    );
  });

  testWidgets('overlay reveals the exact already-resolved result and rarity', (
    tester,
  ) async {
    final item = CosmeticCatalog.find('halo')!;
    final result = GachaPurchaseResult(
      status: GachaPurchaseStatus.newUnlock,
      boxType: GachaBoxType.premium,
      coinBalance: 200,
      item: item,
    );
    var continueCalls = 0;
    await tester.pumpWidget(
      _app(
        GachaOpeningOverlay(result: result, onContinue: () => continueCalls++),
      ),
    );
    await tester.pump();

    final overlay = tester.widget<GachaOpeningOverlay>(
      find.byType(GachaOpeningOverlay),
    );
    expect(identical(overlay.result, result), isTrue);
    expect(find.byKey(Key('gachaResultPreview-${item.id}')), findsNothing);

    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.byKey(const Key('gachaAnimationTapTarget')));
    await tester.pump();

    expect(find.byKey(Key('gachaResultPreview-${item.id}')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('gachaResultRarity'))).data,
      item.rarity.stars,
    );
    expect(find.text(item.englishName), findsOneWidget);
    expect(find.text('NEW!'), findsOneWidget);
    expect(find.text('Unlocked'), findsOneWidget);
    expect(find.byKey(const Key('gachaResultOkButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('gachaResultOkButton')));
    expect(continueCalls, 1);
  });

  testWidgets(
    'one rapid purchase and animation skip commit one new item exactly once',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final coins = _CountingCoinStore(500);
      final cosmetics = _CountingCosmeticStore();
      final random = _FixedRandom();
      await tester.pumpWidget(
        _app(
          Shop(
            coinStore: coins,
            cosmeticStore: cosmetics,
            gachaService: GachaService(randomSource: random),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-standard-box')));
      await tester.tap(find.byKey(const Key('open-premium-box')));
      await _waitForOpeningOverlay(tester);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.tap(find.byKey(const Key('gachaAnimationTapTarget')));
      await tester.pumpAndSettle();

      expect(random.doubleCalls, 1);
      expect(random.intCalls, 1);
      expect(coins.saveCalls, 1);
      expect(coins.state.totalCoins, 400);
      expect(cosmetics.unlockCalls, 1);
      expect(await cosmetics.loadOwnedIds(), contains('halo'));
      expect(
        tester.widget<Text>(find.byKey(const Key('gachaResultItemName'))).data,
        'Halo',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('gachaResultRarity'))).data,
        '★★★★★',
      );

      await tester.tap(find.byKey(const Key('gachaResultOkButton')));
      await tester.pumpAndSettle();
      expect(random.doubleCalls, 1);
      expect(coins.saveCalls, 1);
      expect(cosmetics.unlockCalls, 1);
      expect(find.text('Coins: 400'), findsOneWidget);
    },
  );

  testWidgets('duplicate reveal uses the persisted configured refund once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final coins = _CountingCoinStore(500);
    final cosmetics = _CountingCosmeticStore({'halo'});
    final random = _FixedRandom();
    await tester.pumpWidget(
      _app(
        Shop(
          coinStore: coins,
          cosmeticStore: cosmetics,
          gachaService: GachaService(randomSource: random),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-standard-box')));
    await tester.pumpAndSettle();

    expect(random.doubleCalls, 1);
    expect(random.intCalls, 1);
    expect(coins.saveCalls, 1);
    expect(coins.state.totalCoins, 700);
    expect(cosmetics.unlockCalls, 0);
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.text('Converted to +300 coins'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('gachaResultRarity'))).data,
      '★★★★★',
    );

    await tester.tap(find.byKey(const Key('gachaResultOkButton')));
    await tester.pumpAndSettle();
    expect(random.doubleCalls, 1);
    expect(coins.saveCalls, 1);
    expect(cosmetics.unlockCalls, 0);
    expect(find.text('Coins: 700'), findsOneWidget);
  });

  testWidgets(
    'completed reveal fits every requested portrait size and locale',
    (tester) async {
      const sizes = [
        Size(320, 568),
        Size(360, 640),
        Size(390, 844),
        Size(412, 915),
        Size(430, 932),
      ];
      final item = CosmeticCatalog.find('fairy_wings')!;
      final result = GachaPurchaseResult(
        status: GachaPurchaseStatus.duplicate,
        boxType: GachaBoxType.premium,
        coinBalance: 500,
        item: item,
        duplicateRefund: GachaConfiguration.duplicateRefund(item.rarity),
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;

      for (final size in sizes) {
        for (final locale in const [Locale('en'), Locale('th')]) {
          tester.view.physicalSize = size;
          await tester.pumpWidget(
            _app(
              GachaOpeningOverlay(result: result, onContinue: () {}),
              locale: locale,
            ),
          );
          await tester.pumpAndSettle();

          final button = find.byKey(const Key('gachaResultOkButton'));
          expect(button, findsOneWidget);
          final rect = tester.getRect(button);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
