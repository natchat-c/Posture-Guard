import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/models/cosmetics.dart';
import 'package:postureguard/widgets/slime_character.dart';

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.item});

  final CosmeticItem item;

  @override
  Widget build(BuildContext context) {
    final selection = CosmeticSelection.none.withCategory(
      item.category,
      item.id,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFB7C9D1)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Expanded(child: SlimeCharacter(selection: selection)),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              item.englishName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpressionTile extends StatelessWidget {
  const _ExpressionTile({required this.expression});

  final SlimeExpression expression;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFB7C9D1)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Expanded(
            child: SlimeCharacter(
              expression: expression,
              selection: const CosmeticSelection(
                backId: 'angle_wings',
                hatId: 'crown',
                eyewearId: 'sunglasses',
                holdingId: 'magic_wand',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              expression.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _section(String title, List<CosmeticItem> items) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
      Expanded(
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _ContactTile(item: items[index]),
        ),
      ),
    ],
  );
}

Widget _expressionSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text(
          'Expression stress test',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
      Expanded(
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: SlimeExpression.values.length,
          itemBuilder: (context, index) =>
              _ExpressionTile(expression: SlimeExpression.values[index]),
        ),
      ),
    ],
  );
}

void main() {
  testWidgets('all supplied cosmetics align on the shared character renderer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: const Key('cosmeticContactSheet'),
          child: ColoredBox(
            color: const Color(0xFFF3F8FA),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Expanded(
                    flex: 4,
                    child: _section('Hats', CosmeticCatalog.hats),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    flex: 4,
                    child: _section('Eyewear', CosmeticCatalog.eyewear),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    flex: 4,
                    child: _section('Holding', CosmeticCatalog.holding),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    flex: 4,
                    child: _section('Back', CosmeticCatalog.back),
                  ),
                  const SizedBox(height: 14),
                  Expanded(flex: 3, child: _expressionSection()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    for (final expression in SlimeExpression.values) {
      await tester.runAsync(() async {
        await precacheImage(
          AssetImage(SlimeCharacter.assetFor(expression)),
          tester.element(find.byType(MaterialApp)),
        );
      });
    }
    for (final item in CosmeticCatalog.all) {
      await tester.runAsync(() async {
        await precacheImage(
          AssetImage(item.assetPath),
          tester.element(find.byType(MaterialApp)),
        );
      });
    }
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('cosmeticContactSheet')),
      matchesGoldenFile('goldens/cosmetic_contact_sheet.png'),
    );
    expect(tester.takeException(), isNull);
  });
}
