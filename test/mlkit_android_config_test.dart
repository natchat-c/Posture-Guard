import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android app selects the bundled ML Kit plugin without download metadata',
    () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(pubspec, contains('google_mlkit_face_detection:'));
      expect(gradle, isNot(contains('play-services-mlkit-face-detection')));
      expect(gradle, isNot(contains('com.google.mlkit:face-detection')));
      expect(manifest, isNot(contains('com.google.mlkit.vision.DEPENDENCIES')));
    },
  );
}
