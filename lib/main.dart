import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PostureTestPage(),
    );
  }
}

class PostureTestPage extends StatefulWidget {
  const PostureTestPage({super.key});

  @override
  State<PostureTestPage> createState() => _PostureTestPageState();
}

class _PostureTestPageState extends State<PostureTestPage> {
  CameraController? cameraController;
  FaceDetector? faceDetector;

  StreamSubscription<AccelerometerEvent>? accelerometerSubscription;

  bool isProcessing = false;

  double phoneAngle = 0;
  int faceScore = 0;

  double? headX;
  double? headY;
  double? headZ;

  double neutralHeadX = 0;

  String faceStatus = 'Starting camera...';
  String postureStatus = 'Starting...';

  DateTime? badPostureStartTime;
  int badPostureSeconds = 0;

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

    startAccelerometer();
    startCamera();
  }

  void startAccelerometer() {
    accelerometerSubscription = accelerometerEventStream().listen((event) {
      final angle = calculatePhoneAngle(
        event.x,
        event.y,
        event.z,
      );

      setState(() {
        phoneAngle = angle;
      });

      updatePostureStatus();
    });
  }

  double calculatePhoneAngle(double x, double y, double z) {
    final totalGravity = sqrt(x * x + y * y + z * z);

    if (totalGravity == 0) return 0;

    final zRatio = z.abs() / totalGravity;

    final safeZRatio = zRatio.clamp(0.0, 1.0);

    final angleRadians = asin(safeZRatio);
    final angleDegrees = angleRadians * 180 / pi;

    return angleDegrees;
  }

  Future<void> startCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        setState(() {
          faceStatus = 'No camera found';
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
        faceStatus = 'Camera ready';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        faceStatus = 'Camera error:\n$e';
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
          faceScore = 0;
          headX = null;
          headY = null;
          headZ = null;
          faceStatus = 'No face';
        });
      } else {
        final face = faces.first;

        final score = getFaceCompletenessScore(face);

        setState(() {
          faceScore = score;
          headX = face.headEulerAngleX;
          headY = face.headEulerAngleY;
          headZ = face.headEulerAngleZ;
          faceStatus = getFaceStatus(score);
        });
      }

      updatePostureStatus();
    } catch (e) {
      if (mounted) {
        setState(() {
          faceStatus = 'Detection error:\n$e';
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

  void updatePostureStatus() {
    final fullFace = faceScore >= 4;

    final facingCamera = headY == null || headY!.abs() < 25;
    final headNotTooSideways = headZ == null || headZ!.abs() < 25;

    final phoneIsFlat = phoneAngle > 30;

    double estimatedNeckFlexion = phoneAngle;

    if (headX != null) {
      final calibratedHeadX = headX! - neutralHeadX;
      estimatedNeckFlexion = phoneAngle + calibratedHeadX.abs();
    }

    String newStatus;

    if (!phoneIsFlat) {
      newStatus = 'Good posture';
      resetBadPostureTimer();
    } else if (!fullFace) {
      newStatus = 'Uncertain: phone is flat, but full face is not visible';
      resetBadPostureTimer();
    } else if (!facingCamera) {
      newStatus = 'Uncertain: face is turned sideways';
      resetBadPostureTimer();
    } else if (!headNotTooSideways) {
      newStatus = 'Uncertain: head is tilted sideways';
      resetBadPostureTimer();
    } else {
      if (estimatedNeckFlexion <= 15) {
        newStatus = 'Good posture';
        resetBadPostureTimer();
      } else if (estimatedNeckFlexion <= 30) {
        newStatus = 'Warning posture';
        resetBadPostureTimer();
      } else {
        startOrContinueBadPostureTimer();

        if (badPostureSeconds >= 30) {
          newStatus = 'Bad posture warning';
        } else {
          newStatus = 'Bad posture detected: ${30 - badPostureSeconds}s until warning';
        }
      }
    }

    if (mounted) {
      setState(() {
        postureStatus = newStatus;
      });
    }
  }

  void startOrContinueBadPostureTimer() {
    badPostureStartTime ??= DateTime.now();

    badPostureSeconds =
        DateTime.now().difference(badPostureStartTime!).inSeconds;
  }

  void resetBadPostureTimer() {
    badPostureStartTime = null;
    badPostureSeconds = 0;
  }

  void calibrateNeutralHeadX() {
    if (headX == null) return;

    setState(() {
      neutralHeadX = headX!;
    });
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
    accelerometerSubscription?.cancel();

    cameraController?.stopImageStream();
    cameraController?.dispose();

    faceDetector?.close();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = cameraController;

    final xText = headX?.toStringAsFixed(1) ?? 'null';
    final yText = headY?.toStringAsFixed(1) ?? 'null';
    final zText = headZ?.toStringAsFixed(1) ?? 'null';

    final estimatedNeckFlexion = headX == null
        ? phoneAngle
        : phoneAngle + (headX! - neutralHeadX).abs();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Posture Guard Test'),
      ),
      body: controller == null || !controller.value.isInitialized
          ? Center(
              child: Text(
                faceStatus,
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
                    color: Colors.black.withOpacity(0.78),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          postureStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '''
Phone angle: ${phoneAngle.toStringAsFixed(1)}°

Face: $faceStatus
Face completeness: $faceScore / 5

Head X up/down: $xText
Head Y left/right: $yText
Head Z sideways tilt: $zText

Neutral Head X: ${neutralHeadX.toStringAsFixed(1)}
Estimated neck flexion: ${estimatedNeckFlexion.toStringAsFixed(1)}°

Bad posture timer: $badPostureSeconds s
''',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: calibrateNeutralHeadX,
                          child: const Text('Calibrate neutral head angle'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}