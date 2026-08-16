import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:postureguard/services/face_detector_lifecycle.dart';
import 'package:postureguard/services/mlkit_initializer.dart';

class _FakeDetector implements FaceDetectorClient {
  _FakeDetector({this.processingError});

  final Object? processingError;
  int processCalls = 0;
  int closeCalls = 0;

  @override
  Future<void> close() async => closeCalls++;

  @override
  Future<List<Face>> processImage(InputImage image) async {
    processCalls++;
    if (processingError case final error?) throw error;
    return const [];
  }
}

InputImage _testImage() {
  return InputImage.fromBytes(
    bytes: Uint8List(16),
    metadata: InputImageMetadata(
      size: const Size(4, 4),
      rotation: InputImageRotation.rotation0deg,
      format: InputImageFormat.nv21,
      bytesPerRow: 4,
    ),
  );
}

void main() {
  test(
    'startup and background stop do not initialize ML Kit or create detector',
    () async {
      var initializationCount = 0;
      var creationCount = 0;
      final detector = _FakeDetector();
      final initializer = MlKitInitializer(
        requiresNativeInitialization: true,
        initializeNative: () async {
          initializationCount++;
        },
      );
      final lifecycle = FaceDetectorLifecycle(
        initializer: initializer,
        factory: () {
          creationCount++;
          return detector;
        },
      );

      expect(creationCount, 0);
      expect(initializationCount, 0);
      expect(lifecycle.isStarted, isFalse);
      await lifecycle.stop();
      expect(creationCount, 0);
      expect(initializationCount, 0);

      expect(await lifecycle.start(), isTrue);
      expect(await lifecycle.start(), isTrue);
      expect(initializationCount, 1);
      expect(creationCount, 1);
      await lifecycle.processImage(_testImage());
      expect(detector.processCalls, 1);

      await lifecycle.stop();
      expect(detector.closeCalls, 1);
      expect(lifecycle.isStarted, isFalse);
    },
  );

  test(
    'processing failure closes once and blocks recreate until user retry',
    () async {
      var initializationCount = 0;
      var creationCount = 0;
      final failing = _FakeDetector(
        processingError: StateError('ML Kit failed'),
      );
      final recovered = _FakeDetector();
      final initializer = MlKitInitializer(
        requiresNativeInitialization: true,
        initializeNative: () async {
          initializationCount++;
        },
      );
      final lifecycle = FaceDetectorLifecycle(
        initializer: initializer,
        factory: () => creationCount++ == 0 ? failing : recovered,
      );

      expect(await lifecycle.start(), isTrue);
      await expectLater(
        lifecycle.processImage(_testImage()),
        throwsA(isA<StateError>()),
      );
      expect(lifecycle.isFaulted, isTrue);
      expect(lifecycle.isStarted, isFalse);
      expect(failing.closeCalls, 1);
      expect(await lifecycle.start(), isFalse);
      expect(creationCount, 1);

      lifecycle.allowRetry();
      expect(await lifecycle.start(), isTrue);
      expect(initializationCount, 1);
      expect(creationCount, 2);
      await lifecycle.stop();
      expect(recovered.closeCalls, 1);
    },
  );

  test('camera demand initializes once before creating the detector', () async {
    final events = <String>[];
    final detector = _FakeDetector();
    final initializer = MlKitInitializer(
      requiresNativeInitialization: true,
      initializeNative: () async {
        events.add('initialize');
      },
    );
    final lifecycle = FaceDetectorLifecycle(
      initializer: initializer,
      factory: () {
        events.add('create detector');
        return detector;
      },
    );

    final starts = await Future.wait([lifecycle.start(), lifecycle.start()]);

    expect(starts, everyElement(isTrue));
    expect(events, ['initialize', 'create detector']);
    expect(initializer.state, MlKitInitializationState.initialized);
    await lifecycle.stop();
  });

  test(
    'ML Kit initialization failure prevents detector creation and locks retries',
    () async {
      var initializationCount = 0;
      var creationCount = 0;
      final initializer = MlKitInitializer(
        requiresNativeInitialization: true,
        initializeNative: () async {
          initializationCount++;
          throw StateError('Google services unavailable');
        },
      );
      final lifecycle = FaceDetectorLifecycle(
        initializer: initializer,
        factory: () {
          creationCount++;
          return _FakeDetector();
        },
      );

      expect(await lifecycle.start(), isFalse);
      expect(await lifecycle.start(), isFalse);
      expect(initializationCount, 1);
      expect(creationCount, 0);
      expect(lifecycle.isStarted, isFalse);
      expect(lifecycle.isFaulted, isTrue);
      expect(initializer.state, MlKitInitializationState.failedForSession);
      await lifecycle.stop();
      expect(initializationCount, 1);
    },
  );
}
