import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/widgets/coach_mark_overlay.dart';

Widget _overlayApp({
  required GlobalKey targetKey,
  required Widget page,
  required Object targetIdentity,
  EdgeInsets padding = EdgeInsets.zero,
  VoidCallback? onNext,
}) {
  return MaterialApp(
    builder: (context, child) {
      final mediaQuery = MediaQuery.of(context);
      return MediaQuery(
        data: mediaQuery.copyWith(padding: padding, viewPadding: padding),
        child: child!,
      );
    },
    home: Stack(
      children: [
        Positioned.fill(child: page),
        Positioned.fill(
          child: CoachMarkOverlay(
            targetKey: targetKey,
            targetIdentity: targetIdentity,
            title: 'Target',
            body: 'This explanation follows the rendered control.',
            currentStep: 0,
            totalSteps: 1,
            backLabel: 'Back',
            nextLabel: 'Next',
            skipLabel: 'Skip',
            onBack: null,
            onNext: onNext ?? () {},
            onSkip: () {},
            nextButtonKey: const Key('overlayTestNext'),
          ),
        ),
      ],
    ),
  );
}

void _expectSpotlightContainsTarget(WidgetTester tester, GlobalKey targetKey) {
  final target = tester.getRect(find.byKey(targetKey));
  final spotlight = tester.getRect(find.byKey(CoachMarkOverlay.spotlightKey));
  expect(
    spotlight.contains(target.topLeft),
    isTrue,
    reason: 'spotlight=$spotlight target=$target',
  );
  expect(
    spotlight.contains(target.bottomRight),
    isTrue,
    reason: 'spotlight=$spotlight target=$target',
  );
  expect(
    (spotlight.center - target.center).distance,
    lessThan(1),
    reason: 'spotlight=$spotlight target=$target',
  );
}

void main() {
  testWidgets('spotlight tracks targets across phone sizes and safe areas', (
    tester,
  ) async {
    final cases = <(Size, EdgeInsets)>[
      (const Size(320, 568), const EdgeInsets.only(top: 24)),
      (const Size(390, 844), const EdgeInsets.only(top: 47, bottom: 34)),
      (const Size(430, 932), const EdgeInsets.only(top: 54, bottom: 34)),
    ];
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final (size, padding) in cases) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final targetKey = GlobalKey();
      await tester.pumpWidget(
        _overlayApp(
          targetKey: targetKey,
          targetIdentity: size,
          padding: padding,
          page: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  top: padding.top + 32,
                  right: 20,
                  width: 72,
                  height: 48,
                  child: SizedBox(key: targetKey),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      _expectSpotlightContainsTarget(tester, targetKey);
      final spotlight = tester.getRect(
        find.byKey(CoachMarkOverlay.spotlightKey),
      );
      final card = tester.getRect(find.byKey(const Key('coachMarkCard')));
      expect(spotlight.left, greaterThanOrEqualTo(4));
      expect(spotlight.top, greaterThanOrEqualTo(4));
      expect(spotlight.right, lessThanOrEqualTo(size.width - 4));
      expect(spotlight.bottom, lessThanOrEqualTo(size.height - 4));
      expect(card.top, greaterThanOrEqualTo(padding.top + 12));
      expect(card.bottom, lessThanOrEqualTo(size.height - padding.bottom - 12));
      expect(card.overlaps(spotlight), isFalse);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('outside taps are blocked while the highlighted target works', (
    tester,
  ) async {
    final targetKey = GlobalKey();
    var targetTaps = 0;
    var outsideTaps = 0;
    await tester.pumpWidget(
      _overlayApp(
        targetKey: targetKey,
        targetIdentity: 0,
        page: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 20,
                top: 80,
                width: 80,
                height: 48,
                child: FilledButton(
                  key: targetKey,
                  onPressed: () => targetTaps++,
                  child: const Text('Target'),
                ),
              ),
              Positioned(
                right: 20,
                top: 80,
                width: 80,
                height: 48,
                child: FilledButton(
                  key: const Key('outsideControl'),
                  onPressed: () => outsideTaps++,
                  child: const Text('Other'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('outsideControl')),
      warnIfMissed: false,
    );
    await tester.tap(find.byKey(targetKey));
    expect(outsideTaps, 0);
    expect(targetTaps, 1);
  });

  testWidgets('off-screen target scrolls into view before measurement', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final targetKey = GlobalKey();
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _overlayApp(
        targetKey: targetKey,
        targetIdentity: 'scrolled-target',
        page: Scaffold(
          body: SingleChildScrollView(
            controller: controller,
            child: Column(
              children: [
                const SizedBox(height: 1000),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    key: targetKey,
                    width: double.infinity,
                    height: 64,
                  ),
                ),
                const SizedBox(height: 200),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
    _expectSpotlightContainsTarget(tester, targetKey);
    final target = tester.getRect(find.byKey(targetKey));
    expect(target.top, greaterThanOrEqualTo(0));
    expect(target.bottom, lessThanOrEqualTo(700));
  });

  testWidgets('changing steps invalidates the previous target rectangle', (
    tester,
  ) async {
    final firstKey = GlobalKey();
    final secondKey = GlobalKey();
    var step = 0;
    late StateSetter update;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          final targetKey = step == 0 ? firstKey : secondKey;
          return _overlayApp(
            targetKey: targetKey,
            targetIdentity: step,
            onNext: () => update(() => step = 1),
            page: Scaffold(
              body: Stack(
                children: [
                  Positioned(
                    left: 20,
                    top: 80,
                    width: 80,
                    height: 48,
                    child: SizedBox(key: firstKey),
                  ),
                  Positioned(
                    right: 20,
                    bottom: 80,
                    width: 120,
                    height: 56,
                    child: SizedBox(key: secondKey),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    final firstSpotlight = tester.getRect(
      find.byKey(CoachMarkOverlay.spotlightKey),
    );

    await tester.tap(find.byKey(const Key('overlayTestNext')));
    await tester.pumpAndSettle();

    _expectSpotlightContainsTarget(tester, secondKey);
    final secondSpotlight = tester.getRect(
      find.byKey(CoachMarkOverlay.spotlightKey),
    );
    expect(secondSpotlight.overlaps(firstSpotlight), isFalse);
  });
}
