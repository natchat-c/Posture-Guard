import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/pages/customize_page.dart';
import 'package:postureguard/pages/shop_page.dart';
import 'package:postureguard/pages/statistics_page.dart';
import 'package:postureguard/pages/tutorial_page.dart';
import 'package:postureguard/services/device_screen_time_service.dart';
import 'package:postureguard/services/statistics_repository.dart';
import 'package:postureguard/widgets/no_stretch_scroll_behavior.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _UnsupportedScreenTimeProvider extends DeviceScreenTimeProvider {
  @override
  Future<bool> isSupported() async => false;

  @override
  Future<bool> hasUsageAccess() async => false;

  @override
  Future<bool> openUsageAccessSettings() async => false;

  @override
  Future<int?> getScreenTimeSeconds({
    required DateTime start,
    required DateTime end,
  }) async => null;
}

Widget _app(Widget home) {
  return MaterialApp(
    scrollBehavior: const NoStretchScrollBehavior(),
    home: home,
  );
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('global behavior clamps and suppresses overscroll decoration', (
    tester,
  ) async {
    late BuildContext context;
    const child = SizedBox(key: Key('overscrollChild'));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return child;
          },
        ),
      ),
    );

    const behavior = NoStretchScrollBehavior();
    expect(behavior.getScrollPhysics(context), isA<ClampingScrollPhysics>());
    final decorated = behavior.buildOverscrollIndicator(
      context,
      child,
      const ScrollableDetails.vertical(),
    );
    expect(identical(decorated, child), isTrue);
  });

  testWidgets('Customize and Shop remain scrollable on a phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(const Customizes()));
    expect(
      tester
          .widget<ListView>(find.byKey(const Key('customizeScrollView')))
          .physics,
      isA<ClampingScrollPhysics>(),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_app(const Shop()));
    expect(
      tester.widget<ListView>(find.byKey(const Key('shopScrollView'))).physics,
      isA<ClampingScrollPhysics>(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Statistics scrolls without stretch on a phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        Statistics(
          recordsStream: Stream.value(const <String, DailyStats>{}),
          screenTimeProvider: _UnsupportedScreenTimeProvider(),
          clock: () => DateTime(2026, 7, 26),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scroll = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('statisticsScrollView')),
    );
    expect(scroll.physics, isA<ClampingScrollPhysics>());
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tutorial keeps horizontal navigation and clamped page content', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const TutorialPage()));

    final pageView = tester.widget<PageView>(
      find.byKey(const Key('tutorialPageView')),
    );
    expect(pageView.physics, isA<ClampingScrollPhysics>());
    final pageScroll = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('tutorialPageScroll0')),
    );
    expect(pageScroll.physics, isA<ClampingScrollPhysics>());

    await tester.drag(
      find.byKey(const Key('tutorialPageView')),
      const Offset(-700, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Set your normal position'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
