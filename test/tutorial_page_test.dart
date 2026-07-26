import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/pages/tutorial_page.dart';

Future<void> _advanceToLastPage(WidgetTester tester) async {
  for (var index = 0; index < 5; index++) {
    await tester.tap(find.byKey(const Key('tutorialNextButton')));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('first-run tutorial has six pages and Get Started', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TutorialPage(
          onCompleted: () async {
            completed = true;
          },
        ),
      ),
    );

    expect(find.text('Welcome to Posture Guard'), findsOneWidget);
    await _advanceToLastPage(tester);
    expect(find.text('Adjust your alerts'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorialNextButton')));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });

  testWidgets('replay tutorial says Done and returns to previous page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TutorialPage(isReplay: true),
                  ),
                );
              },
              child: const Text('Open help'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open help'));
    await tester.pumpAndSettle();
    await _advanceToLastPage(tester);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorialNextButton')));
    await tester.pumpAndSettle();
    expect(find.text('Open help'), findsOneWidget);
  });
}
