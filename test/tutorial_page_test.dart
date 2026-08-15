import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/l10n/app_localizations.dart';
import 'package:postureguard/pages/tutorial_page.dart';
import 'package:postureguard/services/calibration_service.dart';
import 'package:postureguard/services/preferences_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Widget _tutorialApp(Widget page, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: page,
  );
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('welcome and current calibration step lead to posture states', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      _tutorialApp(TutorialPage(onCompleted: () async => completed = true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Posture Guard'), findsOneWidget);
    expect(find.byIcon(Icons.health_and_safety_outlined), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorialNextButton')));
    await tester.pumpAndSettle();
    expect(find.text('Set your normal position'), findsOneWidget);
    expect(find.byKey(const Key('tutorialCalibrationButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorialNextButton')));
    await tester.pumpAndSettle();
    expect(find.text('Know your posture'), findsOneWidget);
    expect(find.byKey(const Key('tutorialGoodState')), findsOneWidget);
    expect(find.byKey(const Key('tutorialWarningState')), findsOneWidget);
    expect(find.byKey(const Key('tutorialBadState')), findsOneWidget);
    for (final key in const [
      Key('tutorialGoodState'),
      Key('tutorialWarningState'),
      Key('tutorialBadState'),
    ]) {
      expect(
        find.descendant(of: find.byKey(key), matching: find.byType(Card)),
        findsNothing,
      );
    }
    expect(
      find.text('Good — your phone position looks comfortable.'),
      findsOneWidget,
    );
    expect(
      find.text('Warning — your phone is starting to tilt too low.'),
      findsOneWidget,
    );
    expect(
      find.text('Bad — raise your phone or adjust your position.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('tutorialNextButton')));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });

  testWidgets('calibration step performs real calibration and shows success', (
    tester,
  ) async {
    final service = PostureCalibrationService(
      repository: CalibrationRepository(remoteUpdater: (_) async {}),
      readAngle: () async => 60,
    );
    await tester.pumpWidget(
      _tutorialApp(TutorialPage(calibrationService: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tutorialNextButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tutorialCalibrationButton')));
    await tester.pumpAndSettle();
    expect(find.text('Position saved'), findsOneWidget);
  });

  testWidgets('replay starts with useful guidance and preserves user data', (
    tester,
  ) async {
    final preferences = TutorialPreferences();
    await preferences.markCompleted();
    var completionCalls = 0;

    await tester.pumpWidget(
      _tutorialApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TutorialPage(
                      isReplay: true,
                      onCompleted: () async => completionCalls++,
                    ),
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
    expect(find.text('Know your posture'), findsOneWidget);
    expect(find.text('Welcome to Posture Guard'), findsNothing);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorialNextButton')));
    await tester.pumpAndSettle();
    expect(find.text('Open help'), findsOneWidget);
    expect(completionCalls, 0);
    expect(await preferences.hasCompletedTutorial(), isTrue);
  });

  testWidgets('Thai posture guidance fits a phone-sized viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.25;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      _tutorialApp(
        const TutorialPage(isReplay: true),
        locale: const Locale('th'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ดูสถานะท่าทาง'), findsOneWidget);
    expect(find.textContaining('โทรศัพท์เริ่มอยู่ต่ำเกินไป'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
