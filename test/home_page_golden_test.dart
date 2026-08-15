import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/l10n/app_localizations.dart';
import 'package:postureguard/pages/home_page.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Widget _goldenHome({required String status, required bool monitoringActive}) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: RepaintBoundary(
      key: const Key('homeGoldenSurface'),
      child: MyHomePage(
        key: ValueKey('$status-$monitoringActive'),
        testMode: true,
        initialPostureStatus: status,
        initialMonitoringActive: monitoringActive,
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('compact Home visual states match the 390x844 baselines', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final scenario in const [
      (name: 'good', status: 'GOOD', monitoringActive: true),
      (name: 'warning', status: 'WARNING', monitoringActive: true),
      (name: 'bad', status: 'BAD', monitoringActive: true),
      (name: 'monitoring_off', status: 'GOOD', monitoringActive: false),
    ]) {
      await tester.pumpWidget(
        _goldenHome(
          status: scenario.status,
          monitoringActive: scenario.monitoringActive,
        ),
      );
      for (final asset in const [
        'images/slimes/happy_slime.png',
        'images/slimes/neutral_slime.png',
        'images/slimes/sad_slime.png',
        'images/slimes/very_sad_slime.png',
      ]) {
        await tester.runAsync(() async {
          await precacheImage(
            AssetImage(asset),
            tester.element(find.byType(MyHomePage)),
          );
        });
      }
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const Key('homeGoldenSurface')),
        matchesGoldenFile('goldens/home_${scenario.name}_390x844.png'),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
