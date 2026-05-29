import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FaceDetectionTestPage(),
    );
  }
}

class FaceDetectionTestPage extends StatefulWidget {
  const FaceDetectionTestPage({super.key});

  @override
  State<FaceDetectionTestPage> createState() => _FaceDetectionTestPageState();
}

class _FaceDetectionTestPageState extends State<FaceDetectionTestPage> {
  CameraController? cameraController;
  FaceDetector? faceDetector;

  bool isProcessing = false;
  String statusText = 'Starting camera...';

  @override
  void initState() {
    super.initState();

    faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableLandmarks: true,
        enableContours: false,
        enableTracking: true,
      ),
    );

    startCamera();
  }

  Future<void> startCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        setState(() {
          statusText = 'No camera found';
        });
        return;
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await cameraController!.initialize();

      await cameraController!.startImageStream(processCameraImage);

      if (!mounted) return;

      setState(() {
        statusText = 'Camera ready';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        statusText = 'Camera error:\n$e';
      });
    }
  }

  Future<void> processCameraImage(CameraImage image) async {
    if (isProcessing) return;
    isProcessing = true;

    try {
      final inputImage = inputImageFromCameraImage(image);

      if (inputImage == null) {
        isProcessing = false;
        return;
      }

      final faces = await faceDetector!.processImage(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          statusText = 'No face';
        });
      } else {
        final face = faces.first;

        final score = getFaceCompletenessScore(face);
        final faceStatus = getFaceStatus(score);

        final xAngle = face.headEulerAngleX?.toStringAsFixed(1) ?? 'null';
        final yAngle = face.headEulerAngleY?.toStringAsFixed(1) ?? 'null';
        final zAngle = face.headEulerAngleZ?.toStringAsFixed(1) ?? 'null';

        setState(() {
          statusText = '''
$faceStatus

Completeness score: $score / 5

Head angle X: $xAngle
Head angle Y: $yAngle
Head angle Z: $zAngle
''';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          statusText = 'Detection error:\n$e';
        });
      }
    }

    isProcessing = false;
  }

  int getFaceCompletenessScore(Face face) {
    int score = 0;

    if (face.landmarks[FaceLandmarkType.leftEye] != null) score++;
    if (face.landmarks[FaceLandmarkType.rightEye] != null) score++;
    if (face.landmarks[FaceLandmarkType.noseBase] != null) score++;
    if (face.landmarks[FaceLandmarkType.leftMouth] != null) score++;
    if (face.landmarks[FaceLandmarkType.rightMouth] != null) score++;

    return score;
  }

  String getFaceStatus(int score) {
    if (score >= 4) {
      return 'Full face detected';
    } else if (score >= 1) {
      return 'Partial face detected';
    } else {
      return 'Face detected, but landmarks unclear';
    }
  }

  InputImage? inputImageFromCameraImage(CameraImage image) {
    final controller = cameraController;

    if (controller == null) return null;

    final camera = controller.description;

    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);

    if (format == null) return null;

    if (image.planes.isEmpty) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(
          image.width.toDouble(),
          image.height.toDouble(),
        ),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    cameraController?.stopImageStream();
    cameraController?.dispose();
    faceDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = cameraController;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Detection Test'),
      ),
      body: controller == null || !controller.value.isInitialized
          ? Center(
              child: Text(
                statusText,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: CameraPreview(controller),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.black.withOpacity(0.75),
                    child: Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}