import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/l10n/app_localizations.dart';
import 'package:postureguard/pages/home_page.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Widget _home({
  required String status,
  Locale locale = const Locale('en'),
  bool monitoringActive = true,
  int coinBalance = 0,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: MyHomePage(
      key: ValueKey('${locale.languageCode}-$status'),
      testMode: true,
      initialPostureStatus: status,
      initialMonitoringActive: monitoringActive,
      initialCoinBalance: coinBalance,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('checking-position copy is absent in English and Thai', (
    tester,
  ) async {
    for (final locale in const [Locale('en'), Locale('th')]) {
      await tester.pumpWidget(_home(status: 'WARNING', locale: locale));
      await tester.pumpAndSettle();
      expect(find.textContaining('Checking your position'), findsNothing);
      expect(find.textContaining('กำลังตรวจท่าทาง'), findsNothing);
    }
  });

  testWidgets('posture state changes keep the character vertically stable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final positions = <double>[];
    for (final scenario in const [
      ('GOOD', true),
      ('WARNING', true),
      ('BAD', true),
      ('GOOD', false),
    ]) {
      await tester.pumpWidget(
        _home(status: scenario.$1, monitoringActive: scenario.$2),
      );
      await tester.pumpAndSettle();
      positions.add(
        tester.getRect(find.byKey(const Key('homeCharacterArtwork'))).top,
      );
    }

    expect(positions.reduce(max) - positions.reduce(min), lessThanOrEqualTo(1));
  });

  testWidgets('large coin balances remain readable without enlarging control', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_home(status: 'GOOD', coinBalance: 99999));
    await tester.pumpAndSettle();

    final balance = tester.widget<Text>(
      find.byKey(const Key('homeCoinBalanceText')),
    );
    expect(balance.data, '100K');
    expect(balance.style?.fontSize, 20);
    expect(
      tester.getRect(find.byKey(const Key('homeCoinBalance'))).width,
      lessThanOrEqualTo(104),
    );
    expect(tester.takeException(), isNull);
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

    expect(find.byKey(const Key('homeLayout')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('homeLayout')),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );
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

  testWidgets('monitoring-off state uses the same bounded compact layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_home(status: 'GOOD', monitoringActive: false));
    await tester.pumpAndSettle();

    final status = tester.widget<Text>(
      find.byKey(const Key('homePostureStatus')),
    );
    expect(status.data, 'Monitoring is off');
    expect(status.style?.fontSize, 40);
    expect(find.text('STATUS'), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('homeScore'))).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const Key('homeCharacterArtwork'))).top,
      ),
    );
    expect(find.byKey(const Key('homeCharacterArtwork')), findsOneWidget);
    expect(find.byKey(const Key('homeTimeMetrics')), findsOneWidget);
    expect(find.byKey(const Key('homeBottomActions')), findsOneWidget);
    expect(tester.takeException(), isNull);
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
