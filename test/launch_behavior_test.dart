import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/main.dart';
import 'package:postureguard/services/preferences_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _ControlledLanguagePreferences extends LanguagePreferences {
  final Completer<String?> completer = Completer<String?>();

  @override
  Future<String?> load() => completer.future;

  @override
  Future<void> save(String code) async {}
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('previous Flutter launch path uses its original progress gate', (
    tester,
  ) async {
    final preferences = _ControlledLanguagePreferences();

    await tester.pumpWidget(MyApp(languagePreferences: preferences));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('appLaunchScreen')), findsNothing);
    expect(find.byKey(const Key('appLaunchLogo')), findsNothing);

    preferences.completer.complete(null);
    await tester.pumpAndSettle();

    expect(find.text('Choose your language'), findsOneWidget);
  });

  test('custom splash files and native overrides no longer exist', () {
    expect(File('lib/widgets/app_launch_screen.dart').existsSync(), isFalse);
    expect(
      File('android/app/src/main/res/values-v31/styles.xml').existsSync(),
      isFalse,
    );
    expect(
      File('android/app/src/main/res/values-night-v31/styles.xml').existsSync(),
      isFalse,
    );

    final pubspec = File('pubspec.yaml').readAsStringSync();
    final lightStyles = File(
      'android/app/src/main/res/values/styles.xml',
    ).readAsStringSync();
    final nightStyles = File(
      'android/app/src/main/res/values-night/styles.xml',
    ).readAsStringSync();
    final v21Background = File(
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    ).readAsStringSync();

    expect(pubspec, isNot(contains('images/app icon/app icon.png')));
    expect(lightStyles, contains('?android:colorBackground'));
    expect(nightStyles, contains('@android:style/Theme.Black.NoTitleBar'));
    expect(v21Background, contains('?android:colorBackground'));
  });
}
