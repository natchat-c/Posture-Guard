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
      expect(gradle, contains('com.google.mlkit:common:18.11.0'));
      expect(manifest, isNot(contains('com.google.mlkit.vision.DEPENDENCIES')));
      expect(
        manifest,
        contains('com.google.mlkit.common.internal.MlKitInitProvider'),
      );
      expect(manifest, contains(r'${applicationId}.mlkitinitprovider'));
      expect(manifest, contains('tools:node="remove"'));
    },
  );

  test(
    'ML Kit is initialized only through the demand-driven native bridge',
    () {
      final mainActivity = File(
        'android/app/src/main/kotlin/com/postureguard/app/MainActivity.kt',
      ).readAsStringSync();
      final main = File('lib/main.dart').readAsStringSync();
      final home = File('lib/pages/home_page.dart').readAsStringSync();
      final lifecycle = File(
        'lib/services/face_detector_lifecycle.dart',
      ).readAsStringSync();

      expect(mainActivity, contains('"postureguard/ml_kit"'));
      expect(mainActivity, contains('"initializeMlKit"'));
      expect(mainActivity, contains('MlKit.initialize(applicationContext)'));
      expect(main, isNot(contains('MlKitInitializer')));
      expect(main, isNot(contains('FaceDetector')));
      expect(home, contains('await _faceDetectorLifecycle.start()'));
      expect(home, contains('_screenInteractive &&'));
      expect(lifecycle, contains('if (!await _initializer.initialize())'));

      final initialization = home.indexOf(
        'if (!await _faceDetectorLifecycle.start())',
      );
      final cameraDiscovery = home.indexOf(
        'final cameras = await availableCameras()',
        initialization,
      );
      final streamStart = home.indexOf(
        'await controller.startImageStream(_processCameraImage)',
        cameraDiscovery,
      );
      final cameraActive = home.indexOf('_cameraActive = true', streamStart);
      expect(initialization, greaterThanOrEqualTo(0));
      expect(cameraDiscovery, greaterThan(initialization));
      expect(streamStart, greaterThan(cameraDiscovery));
      expect(cameraActive, greaterThan(streamStart));
    },
  );
}
