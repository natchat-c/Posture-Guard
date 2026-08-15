import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:postureguard/services/face_detector_lifecycle.dart';

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
    'detector is lazy, created once per camera run, and closed on stop',
    () async {
      var creationCount = 0;
      final detector = _FakeDetector();
      final lifecycle = FaceDetectorLifecycle(
        factory: () {
          creationCount++;
          return detector;
        },
      );

      expect(creationCount, 0);
      expect(lifecycle.isStarted, isFalse);
      await lifecycle.stop();
      expect(creationCount, 0);

      expect(lifecycle.start(), isTrue);
      expect(lifecycle.start(), isTrue);
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
      var creationCount = 0;
      final failing = _FakeDetector(
        processingError: StateError('ML Kit failed'),
      );
      final recovered = _FakeDetector();
      final lifecycle = FaceDetectorLifecycle(
        factory: () => creationCount++ == 0 ? failing : recovered,
      );

      expect(lifecycle.start(), isTrue);
      await expectLater(
        lifecycle.processImage(_testImage()),
        throwsA(isA<StateError>()),
      );
      expect(lifecycle.isFaulted, isTrue);
      expect(lifecycle.isStarted, isFalse);
      expect(failing.closeCalls, 1);
      expect(lifecycle.start(), isFalse);
      expect(creationCount, 1);

      lifecycle.allowRetry();
      expect(lifecycle.start(), isTrue);
      expect(creationCount, 2);
      await lifecycle.stop();
      expect(recovered.closeCalls, 1);
    },
  );
}
