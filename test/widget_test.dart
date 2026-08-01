import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:postureguard/main.dart';

void main() {
  testWidgets('first launch chooses a language before the tutorial', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await tester.pumpWidget(const MyApp(initialTutorialCompleted: false));
    await tester.pumpAndSettle();

    expect(find.text('Choose your language'), findsOneWidget);
    expect(find.text('เลือกภาษา'), findsOneWidget);
    await tester.tap(find.byKey(const Key('languageContinueButton')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Posture Guard'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}
