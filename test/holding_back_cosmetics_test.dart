import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/l10n/app_localizations.dart';
import 'package:postureguard/models/cosmetics.dart';
import 'package:postureguard/pages/customize_page.dart';
import 'package:postureguard/pages/home_page.dart';
import 'package:postureguard/pages/shop_page.dart';
import 'package:postureguard/services/cosmetic_repository.dart';
import 'package:postureguard/services/preferences_service.dart';
import 'package:postureguard/widgets/slime_character.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

CosmeticTransform _transform(
  double scale,
  double x,
  double y,
  double rotation,
) => CosmeticTransform(
  scale: scale,
  offsetX: x,
  offsetY: y,
  rotationDegrees: rotation,
);

final _expectedFinalizedTransforms = <String, CosmeticExpressionTransforms>{
  'brush': {
    SlimeExpression.happy: _transform(0.58, 0.21, 0.00, -1.0),
    SlimeExpression.neutral: _transform(0.58, 0.21, 0.00, -1.0),
    SlimeExpression.sad: _transform(0.58, 0.21, 0.03, 16.0),
    SlimeExpression.verySad: _transform(0.58, 0.21, 0.01, 16.0),
  },
  'candy': {
    SlimeExpression.happy: _transform(0.53, 0.22, 0.00, 0.0),
    SlimeExpression.neutral: _transform(0.53, 0.25, 0.00, -15.0),
    SlimeExpression.sad: _transform(0.53, 0.22, 0.06, 20.0),
    SlimeExpression.verySad: _transform(0.49, 0.25, 0.07, 20.0),
  },
  'coffee': {
    SlimeExpression.happy: _transform(0.50, 0.22, 0.03, 0.0),
    SlimeExpression.neutral: _transform(0.50, 0.22, 0.03, -12.0),
    SlimeExpression.sad: _transform(0.50, 0.22, 0.03, 0.0),
    SlimeExpression.verySad: _transform(0.40, 0.22, 0.04, -11.0),
  },
  'flowers': {
    SlimeExpression.happy: _transform(0.48, 0.23, -0.01, 0.0),
    SlimeExpression.neutral: _transform(0.48, 0.26, -0.04, -12.0),
    SlimeExpression.sad: _transform(0.48, 0.23, 0.02, 20.0),
    SlimeExpression.verySad: _transform(0.49, 0.27, 0.03, 20.0),
  },
  'gaming_controller': {
    SlimeExpression.happy: _transform(0.40, 0.23, 0.00, 20.0),
    SlimeExpression.neutral: _transform(0.40, 0.23, 0.00, 18.0),
    SlimeExpression.sad: _transform(0.40, 0.23, 0.04, 8.0),
    SlimeExpression.verySad: _transform(0.40, 0.23, 0.05, 6.0),
  },
  'magic_book': {
    SlimeExpression.happy: _transform(0.49, 0.00, 0.10, 2.0),
    SlimeExpression.neutral: _transform(0.54, 0.06, 0.10, -2.0),
    SlimeExpression.sad: _transform(0.40, 0.03, 0.12, 3.0),
    SlimeExpression.verySad: _transform(0.44, 0.04, 0.14, 3.0),
  },
  'magic_wand': {
    SlimeExpression.happy: _transform(0.59, 0.19, -0.01, 0.0),
    SlimeExpression.neutral: _transform(0.59, 0.19, -0.01, -13.0),
    SlimeExpression.sad: _transform(0.59, 0.19, 0.04, 20.0),
    SlimeExpression.verySad: _transform(0.59, 0.19, 0.05, 20.0),
  },
  'microphone': {
    SlimeExpression.happy: _transform(0.65, 0.21, -0.02, 1.0),
    SlimeExpression.neutral: _transform(0.65, 0.25, -0.08, -18.0),
    SlimeExpression.sad: _transform(0.65, 0.24, 0.01, 20.0),
    SlimeExpression.verySad: _transform(0.65, 0.24, 0.03, 20.0),
  },
  'teddy_bear': {
    SlimeExpression.happy: _transform(0.49, -0.23, 0.00, 10.0),
    SlimeExpression.neutral: _transform(0.50, -0.23, 0.02, 2.0),
    SlimeExpression.sad: _transform(0.40, -0.25, 0.01, 9.0),
    SlimeExpression.verySad: _transform(0.59, -0.26, -0.01, 17.0),
  },
  'angle_wings': {
    SlimeExpression.happy: _transform(1.00, 0.00, 0.00, 0.0),
    SlimeExpression.neutral: _transform(0.96, 0.00, 0.00, -5.0),
    SlimeExpression.sad: _transform(1.00, 0.00, 0.00, 0.0),
    SlimeExpression.verySad: _transform(0.99, 0.00, 0.00, 0.0),
  },
  'backpack': {
    SlimeExpression.happy: _transform(1.11, 0.00, -0.02, 0.0),
    SlimeExpression.neutral: _transform(1.07, 0.00, -0.04, -5.0),
    SlimeExpression.sad: _transform(1.04, 0.00, 0.01, 0.0),
    SlimeExpression.verySad: _transform(1.12, 0.00, 0.00, 0.0),
  },
  'bat_wings': {
    SlimeExpression.happy: _transform(0.91, 0.00, -0.11, 0.0),
    SlimeExpression.neutral: _transform(0.91, -0.02, -0.11, -6.0),
    SlimeExpression.sad: _transform(0.91, 0.00, -0.11, 0.0),
    SlimeExpression.verySad: _transform(0.93, 0.00, -0.14, 0.0),
  },
  'butterfly_wings': {
    SlimeExpression.happy: _transform(0.89, 0.00, -0.11, 0.0),
    SlimeExpression.neutral: _transform(0.85, 0.00, -0.10, -7.0),
    SlimeExpression.sad: _transform(0.86, 0.00, -0.10, 0.0),
    SlimeExpression.verySad: _transform(0.88, 0.00, -0.11, -2.0),
  },
  'devil_wings': {
    SlimeExpression.happy: _transform(1.06, 0.00, 0.00, 0.0),
    SlimeExpression.neutral: _transform(1.06, 0.00, 0.00, -5.0),
    SlimeExpression.sad: _transform(1.06, 0.00, 0.00, 0.0),
    SlimeExpression.verySad: _transform(1.07, 0.00, 0.00, 0.0),
  },
  'dragon_wings': {
    SlimeExpression.happy: _transform(0.87, 0.00, -0.10, 0.0),
    SlimeExpression.neutral: _transform(0.87, -0.01, -0.10, -7.0),
    SlimeExpression.sad: _transform(0.87, 0.00, -0.10, 0.0),
    SlimeExpression.verySad: _transform(0.87, 0.00, -0.15, 0.0),
  },
  'fairy_wings': {
    SlimeExpression.happy: _transform(0.95, 0.00, 0.00, 0.0),
    SlimeExpression.neutral: _transform(0.92, 0.00, 0.00, -4.0),
    SlimeExpression.sad: _transform(0.95, 0.00, 0.00, 0.0),
    SlimeExpression.verySad: _transform(0.94, 0.00, 0.00, -1.0),
  },
};

Widget _app(Widget home) {
  return MaterialApp(
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
}

Finder _scrollableFor(Key key) {
  return find
      .descendant(of: find.byKey(key), matching: find.byType(Scrollable))
      .first;
}

List<Transform> _layerTransforms(WidgetTester tester, Key key) {
  return tester
      .widgetList<Transform>(
        find.descendant(of: find.byKey(key), matching: find.byType(Transform)),
      )
      .toList();
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('all 36 Holding and 28 Back transforms are baked exactly', () {
    final activeItems = [...CosmeticCatalog.holding, ...CosmeticCatalog.back];
    final actual = <String, CosmeticExpressionTransforms>{
      for (final item in activeItems)
        item.id: CosmeticCatalog.finalizedTransforms[item.id]!,
    };

    expect(CosmeticCatalog.holding, hasLength(9));
    expect(CosmeticCatalog.back, hasLength(7));
    expect(actual, _expectedFinalizedTransforms);
    expect(
      CosmeticCatalog.holding.expand(
        (item) => CosmeticCatalog.finalizedTransforms[item.id]!.values,
      ),
      hasLength(36),
    );
    expect(
      CosmeticCatalog.back.expand(
        (item) => CosmeticCatalog.finalizedTransforms[item.id]!.values,
      ),
      hasLength(28),
    );
    for (final item in activeItems) {
      expect(item.isAlignmentLocked, isTrue, reason: item.id);
    }
  });

  test(
    'real magic_wand resolver returns four independent final transforms',
    () {
      final item = CosmeticCatalog.find('magic_wand')!;
      for (final expression in SlimeExpression.values) {
        expect(
          resolveCosmeticTransform(item, expression),
          _expectedFinalizedTransforms['magic_wand']![expression],
          reason: 'magic_wand.${expression.name}',
        );
      }
    },
  );

  test(
    'real dragon_wings resolver returns four independent final transforms',
    () {
      final item = CosmeticCatalog.find('dragon_wings')!;
      for (final expression in SlimeExpression.values) {
        expect(
          resolveCosmeticTransform(item, expression),
          _expectedFinalizedTransforms['dragon_wings']![expression],
          reason: 'dragon_wings.${expression.name}',
        );
      }
    },
  );

  test('actual angel-wing ID is angle_wings and Cape stays inactive', () {
    expect(CosmeticCatalog.find('angle_wings'), isNotNull);
    expect(
      CosmeticCatalog.find('angle_wings')!.assetPath,
      'images/accessories/back/angle_wings.png',
    );
    expect(CosmeticCatalog.find('angel_wings'), isNull);
    expect(CosmeticCatalog.find('cape'), isNull);
    expect(CosmeticCatalog.finalizedTransforms, isNot(contains('cape')));
    expect(
      CosmeticCatalog.back.map((item) => item.id),
      isNot(contains('cape')),
    );
    expect(File('images/accessories/back/cape.png').existsSync(), isTrue);
  });

  test(
    'old Cape selection falls back to None without affecting other slots',
    () async {
      final preferences = SharedPreferencesAsync();
      await preferences.setInt(
        PreferenceKeys.cosmeticEconomyVersion,
        CosmeticRepository.currentEconomyVersion,
      );
      await preferences.setStringList(PreferenceKeys.ownedCosmeticIds, const [
        'crown',
        'sunglasses',
        'magic_wand',
      ]);
      await preferences.setString(PreferenceKeys.equippedHatId, 'crown');
      await preferences.setString(
        PreferenceKeys.equippedEyewearId,
        'sunglasses',
      );
      await preferences.setString(
        PreferenceKeys.equippedHoldingId,
        'magic_wand',
      );
      await preferences.setString(PreferenceKeys.equippedBackId, 'cape');

      final repository = CosmeticRepository(preferences: preferences);
      const expected = CosmeticSelection(
        hatId: 'crown',
        eyewearId: 'sunglasses',
        holdingId: 'magic_wand',
      );
      expect(await repository.load(), expected);
      expect(
        await preferences.getString(PreferenceKeys.equippedBackId),
        isNull,
      );
      expect(await repository.load(), expected);
      expect(
        await preferences.getString(PreferenceKeys.equippedHatId),
        'crown',
      );
      expect(
        await preferences.getString(PreferenceKeys.equippedEyewearId),
        'sunglasses',
      );
      expect(
        await preferences.getString(PreferenceKeys.equippedHoldingId),
        'magic_wand',
      );
    },
  );

  test(
    'four cosmetic categories persist independently and support None',
    () async {
      final preferences = SharedPreferencesAsync();
      final repository = CosmeticRepository(preferences: preferences);
      const equipped = CosmeticSelection(
        backId: 'angle_wings',
        hatId: 'crown',
        eyewearId: 'sunglasses',
        holdingId: 'magic_wand',
      );

      for (final id in const [
        'angle_wings',
        'crown',
        'sunglasses',
        'magic_wand',
      ]) {
        await repository.unlock(id);
      }
      await repository.save(equipped);
      expect(await repository.load(), equipped);
      await repository.save(equipped.withBack(null));
      expect(
        await repository.load(),
        const CosmeticSelection(
          hatId: 'crown',
          eyewearId: 'sunglasses',
          holdingId: 'magic_wand',
        ),
      );
      expect(
        await preferences.getString(PreferenceKeys.equippedBackId),
        isNull,
      );
    },
  );

  testWidgets('renderer layer order is Back, Slime, Hat, Eyewear, Holding', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.square(
          key: Key('fullCharacter'),
          dimension: 300,
          child: SlimeCharacter(
            selection: CosmeticSelection(
              backId: 'dragon_wings',
              hatId: 'crown',
              eyewearId: 'sunglasses',
              holdingId: 'magic_wand',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final stack = tester.widget<Stack>(
      find.descendant(
        of: find.byKey(const Key('fullCharacter')),
        matching: find.byType(Stack),
      ),
    );
    expect(stack.children.map((child) => child.key), const [
      Key('equipped-back-dragon_wings'),
      Key('slime-happy'),
      Key('equipped-hat-crown'),
      Key('equipped-eyewear-sunglasses'),
      Key('equipped-holding-magic_wand'),
    ]);
  });

  testWidgets('renderer changes baked Holding and Back transforms with mood', (
    tester,
  ) async {
    for (final expression in SlimeExpression.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: 300,
              child: SlimeCharacter(
                expression: expression,
                selection: const CosmeticSelection(
                  backId: 'dragon_wings',
                  holdingId: 'magic_wand',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final holding = _expectedFinalizedTransforms['magic_wand']![expression]!;
      final holdingLayers = _layerTransforms(
        tester,
        const Key('equipped-holding-magic_wand'),
      );
      expect(
        holdingLayers[0].transform.storage[12],
        closeTo(300 * holding.offsetX, 0.01),
      );
      expect(
        holdingLayers[0].transform.storage[13],
        closeTo(300 * holding.offsetY, 0.01),
      );
      expect(
        holdingLayers[2].transform.storage[0],
        closeTo(holding.scale, 0.0001),
      );

      final back = _expectedFinalizedTransforms['dragon_wings']![expression]!;
      final backLayers = _layerTransforms(
        tester,
        const Key('equipped-back-dragon_wings'),
      );
      expect(
        backLayers[0].transform.storage[12],
        closeTo(300 * back.offsetX, 0.01),
      );
      expect(
        backLayers[0].transform.storage[13],
        closeTo(300 * back.offsetY, 0.01),
      );
      expect(
        backLayers[1].transform.storage[0],
        closeTo(math.cos(back.rotationDegrees * math.pi / 180), 0.0001),
      );
    }
  });

  testWidgets(
    'Customize has no calibration UI, excludes Cape, and equips new slots',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryCosmeticStore(
        const CosmeticSelection(hatId: 'crown', eyewearId: 'sunglasses'),
        {'crown', 'sunglasses', 'brush', 'angle_wings'},
      );
      await tester.pumpWidget(_app(Customizes(cosmeticStore: store)));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('customizeAdjustAccessoryButton')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('customizeCopyAllValuesButton')),
        findsNothing,
      );
      expect(find.byKey(const Key('customize-back-cape')), findsNothing);

      final brush = find.byKey(const Key('customize-holding-brush'));
      await tester.scrollUntilVisible(
        brush,
        500,
        scrollable: _scrollableFor(const Key('customizeScrollView')),
      );
      await Scrollable.ensureVisible(tester.element(brush), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(brush);
      await tester.pumpAndSettle();
      final wings = find.byKey(const Key('customize-back-angle_wings'));
      await tester.scrollUntilVisible(
        wings,
        500,
        scrollable: _scrollableFor(const Key('customizeScrollView')),
      );
      await Scrollable.ensureVisible(tester.element(wings), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(wings);
      await tester.pumpAndSettle();

      expect(
        store.selection,
        const CosmeticSelection(
          hatId: 'crown',
          eyewearId: 'sunglasses',
          holdingId: 'brush',
          backId: 'angle_wings',
        ),
      );
    },
  );

  testWidgets('Shop excludes Cape and shows Holding and Back in collection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryCosmeticStore();
    await tester.pumpWidget(_app(Shop(cosmeticStore: store)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shop-item-cape')), findsNothing);
    expect(find.byKey(const Key('gachaBox-standard')), findsOneWidget);
    expect(find.byKey(const Key('gachaBox-premium')), findsOneWidget);
    expect(find.byKey(const Key('shopBuyButton')), findsNothing);
    expect(find.byKey(const Key('shop-item-cape')), findsNothing);
  });

  testWidgets(
    'Home renders current mood transforms and keeps portrait bounds',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _app(
          const MyHomePage(
            testMode: true,
            initialPostureStatus: 'WARNING',
            initialCosmetics: CosmeticSelection(
              backId: 'dragon_wings',
              hatId: 'crown',
              eyewearId: 'sunglasses',
              holdingId: 'magic_wand',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('slime-sad')), findsOneWidget);
      expect(
        find.byKey(const Key('equipped-back-dragon_wings')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('equipped-holding-magic_wand')),
        findsOneWidget,
      );
      final holdingLayers = _layerTransforms(
        tester,
        const Key('equipped-holding-magic_wand'),
      );
      final sadWand =
          _expectedFinalizedTransforms['magic_wand']![SlimeExpression.sad]!;
      expect(
        holdingLayers[2].transform.storage[0],
        closeTo(sadWand.scale, 0.0001),
      );
      expect(
        holdingLayers[1].transform.storage[0],
        closeTo(math.cos(sadWand.rotationDegrees * math.pi / 180), 0.0001),
      );
      final bounds = tester.getRect(
        find.byKey(const Key('homeCharacterArtwork')),
      );
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(390));
      expect(tester.takeException(), isNull);
    },
  );
}
