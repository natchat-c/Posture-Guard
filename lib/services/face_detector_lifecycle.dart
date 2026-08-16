import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'mlkit_initializer.dart';

abstract interface class FaceDetectorClient {
  Future<List<Face>> processImage(InputImage image);

  Future<void> close();
}

class MlKitFaceDetectorClient implements FaceDetectorClient {
  MlKitFaceDetectorClient()
    : _detector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.fast,
          enableLandmarks: true,
          enableContours: false,
          enableTracking: true,
        ),
      );

  final FaceDetector _detector;

  @override
  Future<List<Face>> processImage(InputImage image) {
    return _detector.processImage(image);
  }

  @override
  Future<void> close() => _detector.close();
}

typedef FaceDetectorClientFactory = FaceDetectorClient Function();

class FaceDetectorLifecycle {
  FaceDetectorLifecycle({
    FaceDetectorClientFactory? factory,
    MlKitInitialization? initializer,
  }) : _factory = factory ?? MlKitFaceDetectorClient.new,
       _initializer = initializer ?? MlKitInitializer.instance;

  final FaceDetectorClientFactory _factory;
  final MlKitInitialization _initializer;
  FaceDetectorClient? _detector;
  bool _faulted = false;
  Future<bool>? _startInFlight;

  bool get isStarted => _detector != null;

  bool get isFaulted => _faulted;

  Future<bool> start() {
    if (_faulted) return Future<bool>.value(false);
    if (_detector != null) return Future<bool>.value(true);
    final existing = _startInFlight;
    if (existing != null) return existing;

    late final Future<bool> operation;
    operation = _startOnce().whenComplete(() {
      if (identical(_startInFlight, operation)) _startInFlight = null;
    });
    _startInFlight = operation;
    return operation;
  }

  Future<bool> _startOnce() async {
    if (!await _initializer.initialize()) {
      _faulted = true;
      return false;
    }
    try {
      _detector = _factory();
      return true;
    } catch (error) {
      _faulted = true;
      if (kDebugMode) debugPrint('Face detector creation failed: $error');
      return false;
    }
  }

  Future<List<Face>> processImage(InputImage image) async {
    final detector = _detector;
    if (detector == null || _faulted) {
      throw StateError('Face detector is not available.');
    }
    try {
      return await detector.processImage(image);
    } catch (_) {
      await markFaulted();
      rethrow;
    }
  }

  Future<void> markFaulted() async {
    _faulted = true;
    await _closeDetector();
  }

  Future<void> stop() => _closeDetector();

  void allowRetry() => _faulted = false;

  Future<void> _closeDetector() async {
    final detector = _detector;
    _detector = null;
    if (detector == null) return;
    try {
      await detector.close();
    } catch (error) {
      if (kDebugMode) debugPrint('Face detector disposal failed: $error');
    }
  }
}
