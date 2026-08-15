import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/l10n/app_localizations.dart';
import 'package:postureguard/models/cosmetics.dart';
import 'package:postureguard/models/gacha_box_visual_config.dart';
import 'package:postureguard/pages/shop_page.dart';
import 'package:postureguard/services/coin_repository.dart';
import 'package:postureguard/services/cosmetic_repository.dart';
import 'package:postureguard/services/gacha_service.dart';
import 'package:postureguard/widgets/gacha_box_visual.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _MemoryCoinStore implements CoinStore {
  _MemoryCoinStore([int coins = 500]) : state = CoinState(totalCoins: coins);

  CoinState state;

  @override
  Future<CoinState> load() async => state;

  @override
  Future<CoinState> setTotalCoins(CoinState current, int totalCoins) async {
    state = CoinState(totalCoins: totalCoins);
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

void _expectConfig(GachaBoxVisualConfig actual, GachaBoxVisualConfig expected) {
  expect(actual.baseScale, expected.baseScale);
  expect(actual.baseX, expected.baseX);
  expect(actual.baseY, expected.baseY);
  expect(actual.lidScale, expected.lidScale);
  expect(actual.lidX, expected.lidX);
  expect(actual.lidY, expected.lidY);
  expect(actual.lidOpenX, expected.lidOpenX);
  expect(actual.lidOpenY, expected.lidOpenY);
  expect(actual.lidOpenRotationDegrees, expected.lidOpenRotationDegrees);
  expect(actual.lidOpenScale, expected.lidOpenScale);
  expect(actual.glowX, expected.glowX);
  expect(actual.glowY, expected.glowY);
  expect(actual.glowScale, expected.glowScale);
  expect(actual.rewardX, expected.rewardX);
  expect(actual.rewardY, expected.rewardY);
  expect(actual.rewardScale, expected.rewardScale);
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('final Standard and Premium visual values are baked exactly', () {
    _expectConfig(
      GachaBoxVisualConfigs.finalized.standard,
      const GachaBoxVisualConfig(
        baseScale: 0.94,
        baseX: 0,
        baseY: 0.08,
        lidScale: 0.78,
        lidX: 0,
        lidY: -0.01,
        lidOpenX: 0,
        lidOpenY: -0.20,
        lidOpenRotationDegrees: 0,
        lidOpenScale: 0.80,
        glowX: 0,
        glowY: -0.04,
        glowScale: 1.45,
        rewardX: 0,
        rewardY: 0,
        rewardScale: 1,
      ),
    );
    _expectConfig(
      GachaBoxVisualConfigs.finalized.premium,
      const GachaBoxVisualConfig(
        baseScale: 0.91,
        baseX: 0,
        baseY: 0.09,
        lidScale: 0.82,
        lidX: 0,
        lidY: -0.14,
        lidOpenX: 0,
        lidOpenY: -0.30,
        lidOpenRotationDegrees: 0,
        lidOpenScale: 0.82,
        glowX: 0,
        glowY: -0.03,
        glowScale: 1.08,
        rewardX: 0,
        rewardY: 0.02,
        rewardScale: 1.03,
      ),
    );
  });

  testWidgets(
    'Shop and reveal use baked values and ignore retired local overrides',
    (tester) async {
      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        'gachaVisualConfig.standard.v1',
        '{"baseScale":1.80,"lidY":0.60}',
      );
      await preferences.setString(
        'gachaVisualConfig.premium.v1',
        '{"baseScale":0.40,"lidY":0.60}',
      );

      await tester.pumpWidget(
        _app(
          Shop(
            coinStore: _MemoryCoinStore(),
            cosmeticStore: MemoryCosmeticStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final standard = tester.widget<GachaBoxVisual>(
        find.byKey(const Key('shopGachaBoxVisual-standard')),
      );
      final premium = tester.widget<GachaBoxVisual>(
        find.byKey(const Key('shopGachaBoxVisual-premium')),
      );
      expect(standard.config, same(GachaBoxVisualConfigs.finalized.standard));
      expect(premium.config, same(GachaBoxVisualConfigs.finalized.premium));
      expect(find.text('Adjust Gacha Visuals'), findsNothing);
      expect(find.byKey(const Key('adjustGachaVisuals')), findsNothing);
      expect(find.byKey(const Key('gachaCalibrationPreview')), findsNothing);

      final item = CosmeticCatalog.find('cowboy_hat')!;
      await tester.pumpWidget(
        _app(
          GachaOpeningOverlay(
            result: GachaPurchaseResult(
              status: GachaPurchaseStatus.newUnlock,
              boxType: GachaBoxType.standard,
              coinBalance: 400,
              item: item,
            ),
            onContinue: () {},
          ),
        ),
      );
      await tester.pump();
      final reveal = tester.widget<GachaBoxVisual>(
        find.byKey(const Key('gachaOpeningVisual')),
      );
      expect(reveal.config, same(GachaBoxVisualConfigs.finalized.standard));
    },
  );

  testWidgets('odds buttons stay top-right in every target portrait size', (
    tester,
  ) async {
    const sizes = [
      Size(320, 568),
      Size(360, 640),
      Size(390, 844),
      Size(412, 915),
      Size(430, 932),
    ];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in sizes) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        _app(
          Shop(
            coinStore: _MemoryCoinStore(),
            cosmeticStore: MemoryCosmeticStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Rect? previousArtwork;
      for (final type in const ['standard', 'premium']) {
        final artwork = find.byKey(Key('gachaArtworkArea-$type'));
        final button = find.byKey(Key('odds-help-$type'));
        final artworkRect = tester.getRect(artwork);
        final buttonRect = tester.getRect(button);

        expect(buttonRect.width, greaterThanOrEqualTo(48));
        expect(buttonRect.height, greaterThanOrEqualTo(48));
        expect(buttonRect.left, greaterThan(artworkRect.center.dx));
        expect(buttonRect.top, greaterThanOrEqualTo(artworkRect.top));
        expect(buttonRect.right, lessThanOrEqualTo(artworkRect.right));
        expect(
          buttonRect.center.dy,
          lessThan(artworkRect.top + artworkRect.height * 0.30),
        );
        expect(buttonRect.left, greaterThanOrEqualTo(0));
        expect(buttonRect.right, lessThanOrEqualTo(size.width));
        if (previousArtwork case final previous?) {
          expect(artworkRect.top, greaterThanOrEqualTo(previous.bottom));
        }
        previousArtwork = artworkRect;
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('each top-right odds button opens its unchanged odds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(
        Shop(
          coinStore: _MemoryCoinStore(),
          cosmeticStore: MemoryCosmeticStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final type in GachaBoxType.values) {
      final button = find.byKey(Key('odds-help-${type.name}'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.byKey(Key('oddsDialog-${type.name}')), findsOneWidget);
      final config = GachaConfiguration.forType(type);
      for (final rarity in CosmeticRarity.values) {
        final row = find.byKey(Key('odds-${type.name}-${rarity.name}'));
        expect(
          find.descendant(
            of: row,
            matching: find.text('${config.rarityOdds[rarity]}%'),
          ),
          findsOneWidget,
        );
      }
      await tester.tap(find.byKey(Key('close-${type.name}-odds')));
      await tester.pumpAndSettle();
    }

    expect(GachaConfiguration.standard.cost, 100);
    expect(GachaConfiguration.premium.cost, 300);
    expect(GachaConfiguration.standard.rarityOdds.values.toList(), [
      45,
      30,
      15,
      8,
      2,
    ]);
    expect(GachaConfiguration.premium.rarityOdds.values.toList(), [
      10,
      20,
      30,
      25,
      15,
    ]);
  });
}
