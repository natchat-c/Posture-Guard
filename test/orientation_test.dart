import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/main.dart' as app;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'startup requests portrait-up as the only Flutter orientation',
    () async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await app.configurePreferredOrientations();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'SystemChrome.setPreferredOrientations');
      expect(calls.single.arguments, const ['DeviceOrientation.portraitUp']);
    },
  );

  test('Android main activity is fixed to portrait', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:name=".MainActivity"'));
    expect(manifest, contains('android:screenOrientation="portrait"'));
  });

  test('iPhone and iPad native configuration excludes landscape', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(infoPlist, contains('UIInterfaceOrientationPortrait'));
    expect(infoPlist, isNot(contains('UIInterfaceOrientationLandscape')));
    expect(
      infoPlist,
      isNot(contains('UIInterfaceOrientationPortraitUpsideDown')),
    );
  });
}
