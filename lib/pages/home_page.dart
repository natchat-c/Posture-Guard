import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:firebase_database/firebase_database.dart';

import 'settings_page.dart';
import 'statistics_page.dart';
import 'customize_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

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

  String postureStatus = 'GOOD';

  DateTime? badPostureStartTime;
  int badPostureSeconds = 0;

  int totalBadPostureTime = 0;
  int totalScreenTime = 0;

  bool isBadPostureNow = false;

  Timer? usageTimer;

  int alertDelaySeconds = 10;
  int alertFrequencySeconds = 60;
  bool alertsEnabled = true;

  DateTime lastFaceDetectionTime = DateTime.now();

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

    loadSettings();
    loadTodayStats();

    startUsageTimer();
    startAccelerometer();
    startCamera();
  }

  String getTodayKey() {
    final now = DateTime.now();

    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  DatabaseReference get todayStatsRef {
    return FirebaseDatabase.instance.ref(
      'users/demo_user/daily_stats/${getTodayKey()}',
    );
  }

  DatabaseReference get settingsRef {
    return FirebaseDatabase.instance.ref(
      'users/demo_user/settings',
    );
  }

  double get dailyScore {
    if (totalScreenTime == 0) return 100.0;

    final score = 100 * (1 - (totalBadPostureTime / totalScreenTime));

    return score.clamp(0.0, 100.0);
  }

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    if (minutes == 0) {
      return '${remainingSeconds}s';
    }

    return '${minutes}m ${remainingSeconds}s';
  }

  Future<void> loadSettings() async {
    try {
      final snapshot = await settingsRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        await saveSettings();
        return;
      }

      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);

      if (!mounted) return;

      setState(() {
        alertDelaySeconds =
            (data['alertDelaySeconds'] as num?)?.toInt() ?? 10;

        alertFrequencySeconds =
            (data['alertFrequencySeconds'] as num?)?.toInt() ?? 60;

        alertsEnabled = data['alertsEnabled'] as bool? ?? true;
      });
    } catch (e) {
      print('Load settings Firebase error: $e');
    }
  }

  Future<void> saveSettings() async {
    try {
      await settingsRef.set({
        'alertDelaySeconds': alertDelaySeconds,
        'alertFrequencySeconds': alertFrequencySeconds,
        'alertsEnabled': alertsEnabled,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (e) {
      print('Save settings Firebase error: $e');
    }
  }

  Future<void> loadTodayStats() async {
    try {
      final snapshot = await todayStatsRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        await saveTodayStats();
        return;
      }

      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);

      if (!mounted) return;

      setState(() {
        totalScreenTime =
            (data['totalScreenTimeSeconds'] as num?)?.toInt() ?? 0;

        totalBadPostureTime =
            (data['totalBadPostureSeconds'] as num?)?.toInt() ?? 0;
      });
    } catch (e) {
      print('Load Firebase error: $e');
    }
  }

  Future<void> saveTodayStats() async {
    try {
      final goodPostureTime = max(
        0,
        totalScreenTime - totalBadPostureTime,
      ).toInt();

      await todayStatsRef.set({
        'date': getTodayKey(),
        'updatedAt': ServerValue.timestamp,
        'totalScreenTimeSeconds': totalScreenTime,
        'totalBadPostureSeconds': totalBadPostureTime,
        'goodPostureSeconds': goodPostureTime,
        'score': dailyScore.round(),
        'scorePercent': dailyScore.round(),
      });
    } catch (e) {
      print('Save Firebase error: $e');
    }
  }

  void startUsageTimer() {
    usageTimer?.cancel();

    usageTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        totalScreenTime++;

        // Warning time does NOT count as bad posture time.
        if (postureStatus == 'BAD') {
          totalBadPostureTime++;
        }
      });

      if (totalScreenTime % 5 == 0) {
        saveTodayStats();
      }
    });
  }

  void startAccelerometer() {
    accelerometerSubscription = accelerometerEventStream().listen((event) {
      final angle = calculatePhoneAngle(event.x, event.y, event.z);

      phoneAngle = angle;

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
        if (!mounted) return;

        setState(() {
          postureStatus = 'GOOD';
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
    } catch (e) {
      if (!mounted) return;

      setState(() {
        postureStatus = 'GOOD';
      });

      print('Camera error: $e');
    }
  }

  Future<void> processCameraImage(CameraImage image) async {
    if (isProcessing) return;

    final now = DateTime.now();

    if (now.difference(lastFaceDetectionTime).inMilliseconds < 350) {
      return;
    }

    lastFaceDetectionTime = now;
    isProcessing = true;

    try {
      final inputImage = inputImageFromCameraImage(image);

      if (inputImage == null) {
        return;
      }

      final faces = await faceDetector!.processImage(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        faceScore = 0;
        headX = null;
        headY = null;
        headZ = null;
      } else {
        final face = faces.first;

        final score = getFaceCompletenessScore(face);

        faceScore = score;
        headX = face.headEulerAngleX;
        headY = face.headEulerAngleY;
        headZ = face.headEulerAngleZ;
      }

      updatePostureStatus();
    } catch (e) {
      // Detection errors are ignored so the main screen can keep running.
    } finally {
      isProcessing = false;
    }
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
      isBadPostureNow = false;
      newStatus = 'GOOD';
      resetBadPostureTimer();
    } else if (!fullFace) {
      isBadPostureNow = false;
      newStatus = 'GOOD';
      resetBadPostureTimer();
    } else if (!facingCamera) {
      isBadPostureNow = false;
      newStatus = 'GOOD';
      resetBadPostureTimer();
    } else if (!headNotTooSideways) {
      isBadPostureNow = false;
      newStatus = 'GOOD';
      resetBadPostureTimer();
    } else {
      if (estimatedNeckFlexion <= 15) {
        isBadPostureNow = false;
        newStatus = 'GOOD';
        resetBadPostureTimer();
      } else {
        isBadPostureNow = true;
        startOrContinueBadPostureTimer();

        if (!alertsEnabled) {
          newStatus = 'WARNING';
        } else if (badPostureSeconds >= alertDelaySeconds) {
          newStatus = 'BAD';
        } else {
          newStatus = 'WARNING';
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

    badPostureSeconds = DateTime.now()
        .difference(badPostureStartTime!)
        .inSeconds;
  }

  void resetBadPostureTimer() {
    badPostureStartTime = null;
    badPostureSeconds = 0;
  }

  InputImage? inputImageFromCameraImage(CameraImage image) {
    final controller = cameraController;

    if (controller == null) return null;

    final camera = controller.description;

    final rotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);

    if (format == null) return null;

    if (image.planes.isEmpty) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Color getStatusColor() {
    if (postureStatus == 'GOOD') {
      return Colors.green;
    } else if (postureStatus == 'WARNING') {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  void dispose() {
    saveTodayStats();
    saveSettings();

    usageTimer?.cancel();

    accelerometerSubscription?.cancel();

    cameraController?.stopImageStream();
    cameraController?.dispose();

    faceDetector?.close();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scorePercent = dailyScore.round();

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 35, left: 25, right: 25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 60,
                    height: 40,
                    child: FloatingActionButton.extended(
                      onPressed: null,
                      icon: const Icon(Icons.monetization_on_rounded),
                      label: Text('$_counter'),
                    ),
                  ),

                  SizedBox(
                    width: 40,
                    height: 40,
                    child: FloatingActionButton(
                      onPressed: () async {
                        final result = await Navigator.push<SettingsResult>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Settings(
                              initialAlertDelaySeconds: alertDelaySeconds,
                              initialAlertFrequencySeconds:
                                  alertFrequencySeconds,
                              initialAlertsEnabled: alertsEnabled,
                            ),
                          ),
                        );

                        if (result != null) {
                          setState(() {
                            alertDelaySeconds = result.alertDelaySeconds;
                            alertFrequencySeconds =
                                result.alertFrequencySeconds;
                            alertsEnabled = result.alertsEnabled;
                          });

                          await saveSettings();
                        }
                      },
                      child: const Icon(Icons.settings),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            const Text('STATUS', style: TextStyle(fontSize: 20)),

            Text(
              postureStatus,
              style: TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.bold,
                color: getStatusColor(),
              ),
            ),

            Text(
              'Score: $scorePercent',
              style: const TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 20),

            Image.asset(
              'images/happy slime.png',
              width: 300,
              height: 300,
            ),

            const Spacer(),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.access_time_filled, size: 35),
                const SizedBox(width: 10),
                Text(
                  formatTime(totalScreenTime),
                  style: const TextStyle(fontSize: 20),
                ),

                const SizedBox(width: 100),

                const Icon(Icons.sentiment_dissatisfied_sharp, size: 35),
                const SizedBox(width: 10),
                Text(
                  formatTime(totalBadPostureTime),
                  style: const TextStyle(fontSize: 20),
                ),
              ],
            ),

            const SizedBox(height: 30),

            Padding(
              padding: const EdgeInsets.only(bottom: 25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    height: 60,
                    child: FloatingActionButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const customizes(),
                          ),
                        );
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Text(
                        'CUSTOMIZE',
                        style: TextStyle(fontSize: 25),
                      ),
                    ),
                  ),

                  const SizedBox(width: 15),

                  SizedBox(
                    width: 60,
                    height: 60,
                    child: FloatingActionButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Statistics(),
                          ),
                        );
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Icon(Icons.equalizer),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}