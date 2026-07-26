import 'package:flutter_test/flutter_test.dart';

import 'package:postureguard/main.dart';

void main() {
  testWidgets('first launch opens the tutorial', (tester) async {
    await tester.pumpWidget(const MyApp(initialTutorialCompleted: false));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Posture Guard'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}
