import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/l10n/app_localizations.dart';
import 'package:postureguard/pages/home_page.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Widget _home({required String status, Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: MyHomePage(
      key: ValueKey('${locale.languageCode}-$status'),
      testMode: true,
      initialPostureStatus: status,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('English Home shows compact Good, Warning, and Bad wording', (
    tester,
  ) async {
    for (final entry in {
      'GOOD': ('Good posture', 'Keep it up'),
      'WARNING': ('Warning', 'Raise your phone a little'),
      'BAD': ('Bad posture', 'Adjust your position'),
    }.entries) {
      await tester.pumpWidget(_home(status: entry.key));
      await tester.pumpAndSettle();
      expect(find.text(entry.value.$1), findsOneWidget);
      expect(find.text(entry.value.$2), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Thai Home shows compact Good, Warning, and Bad wording', (
    tester,
  ) async {
    for (final entry in {
      'GOOD': ('ท่าทางดี', 'ทำได้ดีมาก'),
      'WARNING': ('ระวัง', 'ยกโทรศัพท์ขึ้นอีกนิด'),
      'BAD': ('ท่าทางไม่ดี', 'ลองปรับท่าทาง'),
    }.entries) {
      await tester.pumpWidget(
        _home(status: entry.key, locale: const Locale('th')),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.value.$1), findsOneWidget);
      expect(find.text(entry.value.$2), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Home stays compact and keeps its real navigation controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_home(status: 'GOOD'));
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('homeScrollView')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, lessThanOrEqualTo(40));
    expect(find.byKey(const Key('homeCharacterArtwork')), findsOneWidget);
    expect(find.byKey(const Key('homeCoinBalance')), findsOneWidget);
    expect(find.byKey(const Key('homeHelpButton')), findsOneWidget);
    expect(find.byKey(const Key('homeSettingsButton')), findsOneWidget);
    expect(find.byKey(const Key('homeCustomizeButton')), findsOneWidget);
    expect(find.byKey(const Key('homeStatisticsButton')), findsOneWidget);
    expect(find.byKey(const Key('calibrationDiagnostics')), findsNothing);
    expect(find.textContaining('°'), findsNothing);
    expect(find.textContaining('threshold'), findsNothing);
  });

  testWidgets('Thai Home tolerates text scaling without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.35;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      _home(status: 'WARNING', locale: const Locale('th')),
    );
    await tester.pumpAndSettle();

    expect(find.text('ยกโทรศัพท์ขึ้นอีกนิด'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
