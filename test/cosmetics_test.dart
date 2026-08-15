import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/l10n/app_localizations.dart';
import 'package:postureguard/models/cosmetics.dart';
import 'package:postureguard/pages/customize_page.dart';
import 'package:postureguard/pages/home_page.dart';
import 'package:postureguard/pages/shop_page.dart';
import 'package:postureguard/services/coin_repository.dart';
import 'package:postureguard/services/cosmetic_repository.dart';
import 'package:postureguard/services/preferences_service.dart';
import 'package:postureguard/widgets/slime_character.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _OfflineCoinStore implements CoinRemoteStore {
  @override
  Future<CoinState> load() => Future.error(StateError('offline'));

  @override
  Future<CoinState> merge(CoinState local) =>
      Future.error(StateError('offline'));
}

Widget _localizedApp(Widget home, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
}

String _formatTransforms(Iterable<CosmeticItem> items) {
  return items
      .expand(
        (item) => SlimeExpression.values.map((expression) {
          final transform = item.transformFor(expression);
          return '${item.id}.${expression.name}: '
              'scale=${transform.scale.toStringAsFixed(2)}, '
              'x=${transform.offsetX.toStringAsFixed(2)}, '
              'y=${transform.offsetY.toStringAsFixed(2)}, '
              'rotation=${transform.rotationDegrees.toStringAsFixed(1)}';
        }),
      )
      .join('\n');
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'catalog keeps the original 56 Hat and Eyewear transforms exact',
    () async {
      const expected = '''
cat_ears.happy: scale=1.02, x=0.00, y=-0.05, rotation=0.0
cat_ears.neutral: scale=1.05, x=0.00, y=-0.07, rotation=-3.0
cat_ears.sad: scale=1.02, x=0.00, y=-0.03, rotation=0.0
cat_ears.verySad: scale=1.08, x=0.00, y=-0.04, rotation=0.0
cowboy_hat.happy: scale=0.64, x=-0.02, y=-0.18, rotation=3.0
cowboy_hat.neutral: scale=0.64, x=-0.04, y=-0.20, rotation=-1.0
cowboy_hat.sad: scale=0.57, x=-0.02, y=-0.15, rotation=3.0
cowboy_hat.verySad: scale=0.64, x=-0.02, y=-0.16, rotation=4.0
crown.happy: scale=0.94, x=-0.09, y=-0.31, rotation=-14.0
crown.neutral: scale=0.95, x=-0.09, y=-0.33, rotation=-13.0
crown.sad: scale=0.95, x=-0.09, y=-0.28, rotation=-13.0
crown.verySad: scale=0.94, x=-0.09, y=-0.30, rotation=-13.0
flower_hat.happy: scale=0.74, x=0.00, y=-0.17, rotation=0.0
flower_hat.neutral: scale=0.83, x=-0.02, y=-0.18, rotation=-4.0
flower_hat.sad: scale=0.74, x=-0.01, y=-0.14, rotation=-1.0
flower_hat.verySad: scale=0.81, x=0.00, y=-0.16, rotation=0.0
halo.happy: scale=0.75, x=-0.01, y=-0.24, rotation=-3.0
halo.neutral: scale=0.75, x=-0.03, y=-0.25, rotation=-3.0
halo.sad: scale=0.75, x=-0.01, y=-0.19, rotation=0.0
halo.verySad: scale=0.79, x=-0.01, y=-0.24, rotation=0.0
santa_hat.happy: scale=0.90, x=-0.07, y=-0.21, rotation=1.0
santa_hat.neutral: scale=0.94, x=-0.07, y=-0.23, rotation=-1.0
santa_hat.sad: scale=0.92, x=-0.07, y=-0.18, rotation=1.0
santa_hat.verySad: scale=1.02, x=-0.06, y=-0.19, rotation=1.0
scholar_hat.happy: scale=0.53, x=-0.06, y=-0.18, rotation=-13.0
scholar_hat.neutral: scale=0.55, x=-0.06, y=-0.20, rotation=-13.0
scholar_hat.sad: scale=0.53, x=-0.06, y=-0.14, rotation=-8.0
scholar_hat.verySad: scale=0.56, x=-0.06, y=-0.18, rotation=-11.0
glasses.happy: scale=0.67, x=0.02, y=-0.01, rotation=0.0
glasses.neutral: scale=0.67, x=0.02, y=-0.01, rotation=-3.0
glasses.sad: scale=0.58, x=0.03, y=0.04, rotation=-8.0
glasses.verySad: scale=0.66, x=0.04, y=0.03, rotation=-3.0
glasses2.happy: scale=0.77, x=0.01, y=-0.03, rotation=-7.0
glasses2.neutral: scale=0.72, x=0.01, y=-0.02, rotation=-8.0
glasses2.sad: scale=0.77, x=0.01, y=0.00, rotation=-4.0
glasses2.verySad: scale=0.78, x=0.01, y=-0.01, rotation=-4.0
glasses3.happy: scale=0.59, x=0.01, y=-0.03, rotation=-5.0
glasses3.neutral: scale=0.59, x=0.01, y=-0.03, rotation=-6.0
glasses3.sad: scale=0.63, x=0.01, y=0.00, rotation=-5.0
glasses3.verySad: scale=0.62, x=0.01, y=-0.01, rotation=-4.0
glasses4.happy: scale=0.60, x=0.00, y=-0.03, rotation=-6.0
glasses4.neutral: scale=0.61, x=0.01, y=-0.02, rotation=-7.0
glasses4.sad: scale=0.61, x=0.00, y=0.01, rotation=-5.0
glasses4.verySad: scale=0.67, x=0.01, y=0.00, rotation=-5.0
heart_glasses.happy: scale=1.05, x=0.01, y=0.00, rotation=-3.0
heart_glasses.neutral: scale=1.09, x=0.01, y=0.00, rotation=-6.0
heart_glasses.sad: scale=1.05, x=0.01, y=0.00, rotation=-3.0
heart_glasses.verySad: scale=1.09, x=0.01, y=0.00, rotation=-2.0
star_glasses.happy: scale=0.72, x=0.01, y=-0.02, rotation=-4.0
star_glasses.neutral: scale=0.79, x=0.02, y=-0.02, rotation=-8.0
star_glasses.sad: scale=0.79, x=0.01, y=0.01, rotation=-4.0
star_glasses.verySad: scale=0.82, x=0.01, y=0.00, rotation=-4.0
sunglasses.happy: scale=0.79, x=0.01, y=-0.04, rotation=-5.0
sunglasses.neutral: scale=0.82, x=0.02, y=-0.04, rotation=-7.0
sunglasses.sad: scale=0.82, x=0.01, y=-0.01, rotation=-4.0
sunglasses.verySad: scale=0.84, x=0.01, y=-0.02, rotation=-4.0
''';
      final finalized = CosmeticCatalog.finalizedTransforms;
      const removed = {
        'beanie',
        'cap',
        'wizard_hat',
        'future_glasses',
        'goggles',
        'sleep_mask',
        'cape',
      };
      expect(CosmeticCatalog.hats, hasLength(7));
      expect(CosmeticCatalog.eyewear, hasLength(7));
      expect(CosmeticCatalog.holding, hasLength(9));
      expect(CosmeticCatalog.back, hasLength(7));
      expect(CosmeticCatalog.all, hasLength(30));
      expect(finalized, hasLength(30));
      expect(
        finalized.values.expand((values) => values.values),
        hasLength(120),
      );
      expect(
        CosmeticCatalog.all.map((item) => item.id).toSet(),
        finalized.keys.toSet(),
      );
      expect(
        CosmeticCatalog.all.map((item) => item.id),
        isNot(contains(anyOf(removed))),
      );

      for (final expression in SlimeExpression.values) {
        expect(
          await rootBundle.load(SlimeCharacter.assetFor(expression)),
          isNotNull,
        );
      }
      for (final item in CosmeticCatalog.all) {
        expect(await rootBundle.load(item.assetPath), isNotNull);
        expect(item.isAlignmentLocked, isTrue);
        expect(finalized[item.id], hasLength(4));
        for (final expression in SlimeExpression.values) {
          expect(
            item.transformFor(expression),
            finalized[item.id]![expression],
            reason: '${item.id}.${expression.name}',
          );
        }
        expect(item.isStarter, CosmeticCatalog.starterIds.contains(item.id));
      }
      expect(
        _formatTransforms([
          ...CosmeticCatalog.hats,
          ...CosmeticCatalog.eyewear,
        ]),
        expected.trim(),
      );
    },
  );

  test(
    'hat and eyewear persist independently and invalid ids are ignored',
    () async {
      final repository = CosmeticRepository();
      await repository.unlock('crown');
      await repository.unlock('sunglasses');
      await repository.unlock('glasses4');
      const selected = CosmeticSelection(
        hatId: 'crown',
        eyewearId: 'sunglasses',
      );
      await repository.save(selected);

      expect(await CosmeticRepository().load(), selected);

      await repository.save(
        const CosmeticSelection(hatId: 'not-an-asset', eyewearId: 'glasses4'),
      );
      expect(
        await repository.load(),
        const CosmeticSelection(eyewearId: 'glasses4'),
      );
    },
  );

  test('removed saved equipment is cleared and falls back to none', () async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString(PreferenceKeys.equippedHatId, 'beanie');
    await preferences.setString(PreferenceKeys.equippedEyewearId, 'sleep_mask');

    final selection = await CosmeticRepository(preferences: preferences).load();

    expect(selection, CosmeticSelection.none);
    expect(await preferences.getString(PreferenceKeys.equippedHatId), isNull);
    expect(
      await preferences.getString(PreferenceKeys.equippedEyewearId),
      isNull,
    );
  });

  test('equipping free cosmetics never changes the coin balance', () async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString(
      'localCoinStateV2',
      jsonEncode(const CoinState(totalCoins: 1025).toMap()),
    );
    final coins = CoinRepository(
      preferences: preferences,
      remoteStore: _OfflineCoinStore(),
    );
    final cosmetics = CosmeticRepository(preferences: preferences);

    await cosmetics.save(
      const CosmeticSelection(hatId: 'cowboy_hat', eyewearId: 'glasses3'),
    );

    expect((await coins.load()).totalCoins, 1025);
  });

  testWidgets('invalid equipment ids fail soft and keep the base character', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.square(
          dimension: 240,
          child: SlimeCharacter(
            baseAssetOverride: 'images/slimes/not_found.png',
            selection: CosmeticSelection(
              hatId: 'missing-hat',
              eyewearId: 'missing-eyewear',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('slime-happy')), findsOneWidget);
    expect(find.byKey(const Key('equipped-hat-missing-hat')), findsNothing);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Customize equips None, hats, and eyewear immediately', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryCosmeticStore(
      CosmeticSelection.none,
      CosmeticCatalog.all.map((item) => item.id).toSet(),
    );
    await tester.pumpWidget(_localizedApp(Customizes(cosmeticStore: store)));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('customizeCharacterArtwork')),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
    for (final id in const ['beanie', 'cap', 'wizard_hat']) {
      expect(find.byKey(Key('customize-hat-$id')), findsNothing);
    }

    final catEars = find.byKey(const Key('customize-hat-cat_ears'));
    await tester.ensureVisible(catEars);
    await tester.pumpAndSettle();
    await tester.tap(catEars);
    await tester.pump();
    expect(find.byKey(const Key('equipped-hat-cat_ears')), findsWidgets);

    await tester.drag(
      find.byKey(const Key('customizeScrollView')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    for (final id in const ['future_glasses', 'goggles', 'sleep_mask']) {
      expect(find.byKey(Key('customize-eyewear-$id')), findsNothing);
    }
    await tester.tap(find.byKey(const Key('customize-eyewear-glasses')));
    await tester.pumpAndSettle();
    expect(
      store.selection,
      const CosmeticSelection(hatId: 'cat_ears', eyewearId: 'glasses'),
    );

    await tester.pumpWidget(
      _localizedApp(
        Customizes(key: const ValueKey('deselect-hat'), cosmeticStore: store),
      ),
    );
    await tester.pumpAndSettle();
    final noHat = find.byKey(const Key('customize-hat-none'));
    await tester.ensureVisible(noHat);
    await tester.pumpAndSettle();
    await tester.tap(noHat);
    await tester.pumpAndSettle();
    expect(store.selection, const CosmeticSelection(eyewearId: 'glasses'));

    await tester.drag(
      find.byKey(const Key('customizeScrollView')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customize-eyewear-none')));
    await tester.pumpAndSettle();
    expect(store.selection, CosmeticSelection.none);
    expect(tester.takeException(), isNull);
  });

  testWidgets('normalized cosmetic offsets scale with character bounds', (
    tester,
  ) async {
    Future<Offset> translationAt(double dimension) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: dimension,
              child: const SlimeCharacter(
                selection: CosmeticSelection(hatId: 'crown'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final translation = tester.widget<Transform>(
        find
            .descendant(
              of: find.byKey(const Key('equipped-hat-crown')),
              matching: find.byType(Transform),
            )
            .first,
      );
      return Offset(
        translation.transform.storage[12],
        translation.transform.storage[13],
      );
    }

    final small = await translationAt(160);
    final large = await translationAt(320);
    expect(large.dx, closeTo(small.dx * 2, 0.01));
    expect(large.dy, closeTo(small.dy * 2, 0.01));
  });

  testWidgets(
    'Shop shows gacha boxes and the full collection without direct buys',
    (tester) async {
      final preferences = SharedPreferencesAsync();
      final coins = CoinRepository(
        preferences: preferences,
        remoteStore: _OfflineCoinStore(),
      );
      await coins.setTotalCoins(const CoinState(), 500);
      final store = MemoryCosmeticStore();
      await tester.pumpWidget(
        _localizedApp(Shop(cosmeticStore: store, coinStore: coins)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('gachaBox-standard')), findsOneWidget);
      expect(find.byKey(const Key('gachaBox-premium')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('gachaBox-standard')),
          matching: find.byType(Card),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const Key('shopGachaBox-base-standard')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('shopGachaBox-lid-standard')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('shopGachaBox-base-premium')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('shopGachaBox-lid-premium')), findsOneWidget);
      expect(find.byKey(const Key('open-standard-box')), findsOneWidget);
      expect(find.byKey(const Key('open-premium-box')), findsOneWidget);
      expect(find.byKey(const Key('shopBuyButton')), findsNothing);
      for (final id in const ['beanie', 'cap', 'wizard_hat']) {
        expect(find.byKey(Key('shop-item-$id')), findsNothing);
      }
      expect(find.byKey(const Key('shop-item-cape')), findsNothing);
      expect(find.text('FREE'), findsNothing);
    },
  );

  testWidgets('cosmetic pages localize their controls in Thai', (tester) async {
    await tester.pumpWidget(
      _localizedApp(const Customizes(), locale: const Locale('th')),
    );
    await tester.pumpAndSettle();

    expect(find.text('หมวก'), findsOneWidget);
    expect(find.text('ไม่ใส่'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('customizeScrollView')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    expect(find.text('แว่นตา'), findsOneWidget);
    expect(find.text('ไม่ใส่'), findsAtLeastNWidgets(2));
  });

  testWidgets('Home keeps equipment layered across posture expressions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _localizedApp(
        const MyHomePage(
          testMode: true,
          initialPostureStatus: 'WARNING',
          initialCosmetics: CosmeticSelection(
            hatId: 'crown',
            eyewearId: 'sunglasses',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('slime-sad')), findsOneWidget);
    expect(find.byKey(const Key('equipped-hat-crown')), findsOneWidget);
    expect(
      find.byKey(const Key('equipped-eyewear-sunglasses')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('homeCharacterArtwork')),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
    expect(
      find.text(
        'Move into view if you want camera help. '
        'Posture monitoring is still working.',
      ),
      findsNothing,
    );
    final bounds = tester.getRect(
      find.byKey(const Key('homeCharacterArtwork')),
    );
    expect(bounds.width / bounds.height, closeTo(765 / 611, 0.02));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tall and wide cosmetics never change Home outer bounds', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final size in const [
      Size(320, 568),
      Size(360, 640),
      Size(390, 844),
      Size(412, 915),
    ]) {
      for (final locale in const [Locale('en'), Locale('th')]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          _localizedApp(
            MyHomePage(
              key: ValueKey('plain-${size.width}-${locale.languageCode}'),
              testMode: true,
              initialPostureStatus: 'BAD',
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        final plain = tester.getRect(
          find.byKey(const Key('homeCharacterArtwork')),
        );

        await tester.pumpWidget(
          _localizedApp(
            MyHomePage(
              key: ValueKey('dressed-${size.width}-${locale.languageCode}'),
              testMode: true,
              initialPostureStatus: 'BAD',
              initialCosmetics: const CosmeticSelection(
                hatId: 'crown',
                eyewearId: 'glasses3',
              ),
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        final dressed = tester.getRect(
          find.byKey(const Key('homeCharacterArtwork')),
        );

        expect(dressed, plain);
        expect(dressed.left, greaterThanOrEqualTo(0));
        expect(dressed.right, lessThanOrEqualTo(size.width));
        expect(tester.takeException(), isNull);
      }
    }
  });
}
