import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'settings_page.dart';
import 'statistics_page.dart';
import 'customize_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  static const String modePhoneOrientationOnly = 'phone_orientation_only';
  static const String modePhoneOrientationCamera = 'phone_orientation_camera';
  static const String modeCameraInAppOnly = 'camera_in_app_only';

  static const double cameraStartAngle = 30;
  static const double cameraStopAngle = 25;

  CameraController? cameraController;
  FaceDetector? faceDetector;

  StreamSubscription<AccelerometerEvent>? accelerometerSubscription;

  bool isProcessing = false;

  bool cameraIsActive = false;
  bool isStartingCamera = false;
  bool isStoppingCamera = false;

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

  int totalCoins = 0;
  int coinsEarnedToday = 0;

  String activeDateKey = '';
  String? lastAwardedDate;

  bool isBadPostureNow = false;

  Timer? usageTimer;
  Timer? cameraControlTimer;

  int alertDelaySeconds = 10;
  int alertFrequencySeconds = 60;
  bool alertsEnabled = true;

  String detectionMode = modePhoneOrientationOnly;

  DateTime lastFaceDetectionTime = DateTime.now();
  DateTime? lastBadPostureNotificationTime;

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool get appIsInForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == AppLifecycleState.resumed;
  }

  bool get cameraAllowedInThisState {
    return detectionMode == modePhoneOrientationCamera && appIsInForeground;
  }

  String normaliseDetectionMode(String mode) {
    if (mode == modePhoneOrientationCamera) {
      return modePhoneOrientationCamera;
    }

    if (mode == modeCameraInAppOnly) {
      return modePhoneOrientationCamera;
    }

    return modePhoneOrientationOnly;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableLandmarks: true,
        enableContours: false,
        enableTracking: true,
      ),
    );

    initNotifications();

    loadSettings();
    loadInitialStatsAndCoins();

    startUsageTimer();
    startAccelerometer();

    startCameraControlTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      stopCamera();
      return;
    }

    manageCameraBasedOnPhoneAngle();
  }

  Future<void> initNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await notificationsPlugin.initialize(
      settings: initializationSettings,
    );

    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showBadPostureNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'posture_alerts',
      'Posture Alerts',
      channelDescription: 'Alerts when bad posture is detected',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await notificationsPlugin.show(
      id: 1,
      title: 'Bad posture detected',
      body: 'Sit up straight to protect your neck.',
      notificationDetails: notificationDetails,
    );
  }

  void maybeSendBadPostureNotification(String newStatus) {
    if (!alertsEnabled) return;

    if (newStatus != 'BAD') {
      lastBadPostureNotificationTime = null;
      return;
    }

    final now = DateTime.now();

    final shouldSendNotification =
        lastBadPostureNotificationTime == null ||
        now.difference(lastBadPostureNotificationTime!).inSeconds >=
            alertFrequencySeconds;

    if (!shouldSendNotification) return;

    lastBadPostureNotificationTime = now;

    showBadPostureNotification();
  }

  String getDateKey(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String getTodayKey() {
    return getDateKey(DateTime.now());
  }

  DateTime? parseDateKey(String? dateKey) {
    if (dateKey == null || dateKey.isEmpty) return null;

    try {
      return DateTime.parse(dateKey);
    } catch (e) {
      return null;
    }
  }

  DatabaseReference dailyStatsRef(String dateKey) {
    return FirebaseDatabase.instance.ref(
      'users/demo_user/daily_stats/$dateKey',
    );
  }

  DatabaseReference get todayStatsRef {
    final dateKey = activeDateKey.isEmpty ? getTodayKey() : activeDateKey;

    return dailyStatsRef(dateKey);
  }

  DatabaseReference get settingsRef {
    return FirebaseDatabase.instance.ref(
      'users/demo_user/settings',
    );
  }

  DatabaseReference get coinsRef {
    return FirebaseDatabase.instance.ref(
      'users/demo_user/coins',
    );
  }

  double get dailyScore {
    if (totalScreenTime == 0) return 100.0;

    final score = 100 * (1 - (totalBadPostureTime / totalScreenTime));

    return score.clamp(0.0, 100.0);
  }

  int get calculatedCoinsForToday {
    return dailyScore.round();
  }

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    if (minutes == 0) {
      return '${remainingSeconds}s';
    }

    return '${minutes}m ${remainingSeconds}s';
  }

  Future<void> loadInitialStatsAndCoins() async {
    activeDateKey = getTodayKey();

    await loadCoins();
    await awardCoinsForCompletedDays();
    await loadTodayStats();
  }

  Future<void> loadSettings() async {
    try {
      final snapshot = await settingsRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        await saveSettings();
        return;
      }

      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);

      final loadedAlertDelaySeconds =
          (data['alertDelaySeconds'] as num?)?.toInt() ?? 10;

      final loadedAlertFrequencySeconds =
          (data['alertFrequencySeconds'] as num?)?.toInt() ?? 60;

      final loadedAlertsEnabled = data['alertsEnabled'] as bool? ?? true;

      final rawDetectionMode =
          data['detectionMode'] as String? ?? modePhoneOrientationOnly;

      String loadedDetectionMode = normaliseDetectionMode(rawDetectionMode);

      if (data['detectionMode'] == null && data['useCameraMode'] != null) {
        final oldUseCameraMode = data['useCameraMode'] as bool? ?? false;

        loadedDetectionMode = oldUseCameraMode
            ? modePhoneOrientationCamera
            : modePhoneOrientationOnly;
      }

      final shouldRewriteSettings = rawDetectionMode == modeCameraInAppOnly;

      if (!mounted) return;

      setState(() {
        alertDelaySeconds = loadedAlertDelaySeconds;
        alertFrequencySeconds = loadedAlertFrequencySeconds;
        alertsEnabled = loadedAlertsEnabled;
        detectionMode = loadedDetectionMode;
      });

      if (shouldRewriteSettings) {
        await saveSettings();
      }

      await manageCameraBasedOnPhoneAngle();
    } catch (e) {
      print('Load settings Firebase error: $e');
    }
  }

  Future<void> saveSettings() async {
    try {
      detectionMode = normaliseDetectionMode(detectionMode);

      await settingsRef.set({
        'alertDelaySeconds': alertDelaySeconds,
        'alertFrequencySeconds': alertFrequencySeconds,
        'alertsEnabled': alertsEnabled,
        'detectionMode': detectionMode,
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
      final coinsAlreadyAwarded = data['coinsAwarded'] as bool? ?? false;

      if (!mounted) return;

      setState(() {
        totalScreenTime =
            (data['totalScreenTimeSeconds'] as num?)?.toInt() ?? 0;

        totalBadPostureTime =
            (data['totalBadPostureSeconds'] as num?)?.toInt() ?? 0;

        coinsEarnedToday = coinsAlreadyAwarded
            ? (data['coinsEarned'] as num?)?.toInt() ?? 0
            : 0;
      });
    } catch (e) {
      print('Load Firebase error: $e');
    }
  }

  Future<void> loadCoins() async {
    try {
      final snapshot = await coinsRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        final yesterdayKey = getDateKey(
          DateTime.now().subtract(const Duration(days: 1)),
        );

        if (mounted) {
          setState(() {
            totalCoins = 0;
            coinsEarnedToday = 0;
            lastAwardedDate = yesterdayKey;
          });
        } else {
          totalCoins = 0;
          coinsEarnedToday = 0;
          lastAwardedDate = yesterdayKey;
        }

        await saveCoins();
        return;
      }

      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);

      final loadedLastAwardedDate = data['lastAwardedDate'] as String? ??
          getDateKey(DateTime.now().subtract(const Duration(days: 1)));

      if (!mounted) return;

      setState(() {
        totalCoins = (data['totalCoins'] as num?)?.toInt() ?? 0;
        coinsEarnedToday = 0;
        lastAwardedDate = loadedLastAwardedDate;
      });
    } catch (e) {
      print('Load coins Firebase error: $e');
    }
  }

  Future<void> saveCoins() async {
    try {
      await coinsRef.set({
        'totalCoins': totalCoins,
        'coinsEarnedToday': coinsEarnedToday,
        'lastAwardedDate': lastAwardedDate,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (e) {
      print('Save coins Firebase error: $e');
    }
  }

  Future<void> awardCoinsForCompletedDays() async {
    try {
      final todayDate = DateTime.parse(getTodayKey());

      final defaultLastAwardedDate = todayDate.subtract(
        const Duration(days: 1),
      );

      final parsedLastAwardedDate =
          parseDateKey(lastAwardedDate) ?? defaultLastAwardedDate;

      DateTime dateToCheck = parsedLastAwardedDate.add(
        const Duration(days: 1),
      );

      while (dateToCheck.isBefore(todayDate)) {
        final dateKey = getDateKey(dateToCheck);
        final snapshot = await dailyStatsRef(dateKey).get();

        if (snapshot.exists && snapshot.value != null) {
          final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
          final alreadyAwarded = data['coinsAwarded'] as bool? ?? false;

          if (!alreadyAwarded) {
            final rawScore = (data['score'] as num?)?.toInt() ??
                (data['scorePercent'] as num?)?.toInt() ??
                0;

            final coinsToAward = rawScore.clamp(0, 100).toInt();

            totalCoins = max(0, totalCoins + coinsToAward);
            coinsEarnedToday = 0;

            await dailyStatsRef(dateKey).update({
              'coinsEarned': coinsToAward,
              'coinsAwarded': true,
              'coinsAwardedAt': ServerValue.timestamp,
            });
          }
        }

        lastAwardedDate = dateKey;
        dateToCheck = dateToCheck.add(const Duration(days: 1));
      }

      await saveCoins();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Award coins Firebase error: $e');
    }
  }

  Future<void> handleDayChangeIfNeeded() async {
    final todayKey = getTodayKey();

    if (activeDateKey.isEmpty) {
      activeDateKey = todayKey;
      return;
    }

    if (activeDateKey == todayKey) {
      return;
    }

    await saveTodayStats(dateKey: activeDateKey);
    await awardCoinsForCompletedDays();

    if (mounted) {
      setState(() {
        activeDateKey = todayKey;
        totalScreenTime = 0;
        totalBadPostureTime = 0;
        coinsEarnedToday = 0;
      });
    } else {
      activeDateKey = todayKey;
      totalScreenTime = 0;
      totalBadPostureTime = 0;
      coinsEarnedToday = 0;
    }

    resetBadPostureTimer();

    await loadTodayStats();
    await saveTodayStats();
  }

  Future<void> saveTodayStats({String? dateKey}) async {
    try {
      final targetDateKey = dateKey ??
          (activeDateKey.isEmpty ? getTodayKey() : activeDateKey);

      final goodPostureTime = max(
        0,
        totalScreenTime - totalBadPostureTime,
      ).toInt();

      await dailyStatsRef(targetDateKey).set({
        'date': targetDateKey,
        'updatedAt': ServerValue.timestamp,
        'totalScreenTimeSeconds': totalScreenTime,
        'totalBadPostureSeconds': totalBadPostureTime,
        'goodPostureSeconds': goodPostureTime,
        'score': dailyScore.round(),
        'scorePercent': dailyScore.round(),
        'coinsEarned': coinsEarnedToday,
        'coinsAwarded': false,
      });
    } catch (e) {
      print('Save Firebase error: $e');
    }
  }

  void startUsageTimer() {
    usageTimer?.cancel();

    usageTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await handleDayChangeIfNeeded();

      if (!mounted) return;

      setState(() {
        totalScreenTime++;

        if (postureStatus == 'BAD') {
          totalBadPostureTime++;
        }
      });

      if (totalScreenTime % 5 == 0) {
        saveTodayStats();
      }
    });
  }

  void startCameraControlTimer() {
    cameraControlTimer?.cancel();

    cameraControlTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      manageCameraBasedOnPhoneAngle();
    });
  }

  void startAccelerometer() {
    accelerometerSubscription?.cancel();

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

  Future<void> manageCameraBasedOnPhoneAngle() async {
    if (!mounted) return;

    if (!cameraAllowedInThisState) {
      if (cameraIsActive && !isProcessing) {
        await stopCamera();
      }

      return;
    }

    if (phoneAngle >= cameraStartAngle &&
        !cameraIsActive &&
        !isStartingCamera &&
        !isStoppingCamera) {
      await startCamera();
      return;
    }

    if (phoneAngle <= cameraStopAngle &&
        cameraIsActive &&
        !isProcessing &&
        !isStartingCamera &&
        !isStoppingCamera) {
      await stopCamera();
    }
  }

  Future<void> startCamera() async {
    if (cameraIsActive || isStartingCamera || isStoppingCamera) return;
    if (!cameraAllowedInThisState) return;

    isStartingCamera = true;

    try {
      final cameras = await availableCameras();

      if (!mounted || !cameraAllowedInThisState) return;

      if (cameras.isEmpty) {
        cameraController = null;
        cameraIsActive = false;
        updatePostureStatus();
        return;
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();

      if (!mounted || !cameraAllowedInThisState) {
        await controller.dispose();
        return;
      }

      cameraController = controller;

      await cameraController!.startImageStream(processCameraImage);

      cameraIsActive = true;

      updatePostureStatus();
    } catch (e) {
      print('Camera error: $e');

      cameraController = null;
      cameraIsActive = false;

      if (mounted) {
        updatePostureStatus();
      }
    } finally {
      isStartingCamera = false;
    }
  }

  Future<void> stopCamera() async {
    if (isStoppingCamera || isStartingCamera || isProcessing) return;

    final controller = cameraController;

    if (controller == null) {
      cameraIsActive = false;
      clearFaceData();

      if (mounted) {
        updatePostureStatus();
      }

      return;
    }

    isStoppingCamera = true;
    cameraIsActive = false;

    try {
      if (controller.value.isInitialized &&
          controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }

      await controller.dispose();
    } catch (e) {
      print('Stop camera error: $e');
    } finally {
      cameraController = null;
      isStoppingCamera = false;
      isProcessing = false;

      clearFaceData();

      if (mounted) {
        updatePostureStatus();
      }
    }
  }

  void clearFaceData() {
    faceScore = 0;
    headX = null;
    headY = null;
    headZ = null;
  }

  Future<void> processCameraImage(CameraImage image) async {
    if (!cameraIsActive) return;
    if (isProcessing) return;

    final detector = faceDetector;
    if (detector == null) return;

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

      final faces = await detector.processImage(inputImage);

      if (!mounted || !cameraIsActive) return;

      if (faces.isEmpty) {
        clearFaceData();
      } else {
        final face = faces.first;

        faceScore = getFaceCompletenessScore(face);
        headX = face.headEulerAngleX;
        headY = face.headEulerAngleY;
        headZ = face.headEulerAngleZ;
      }

      updatePostureStatus();
    } catch (e) {
      print('Face detection error: $e');
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
    String newStatus;

    final phoneAngleIsBad = phoneAngle > 30;

    if (detectionMode == modePhoneOrientationOnly) {
      if (!phoneAngleIsBad) {
        isBadPostureNow = false;
        newStatus = 'GOOD';
        resetBadPostureTimer();
      } else {
        isBadPostureNow = true;
        startOrContinueBadPostureTimer();

        if (badPostureSeconds >= alertDelaySeconds) {
          newStatus = 'BAD';
        } else {
          newStatus = 'WARNING';
        }
      }

      if (mounted) {
        setState(() {
          postureStatus = newStatus;
        });

        maybeSendBadPostureNotification(newStatus);
      }

      return;
    }

    if (detectionMode == modePhoneOrientationCamera) {
      if (!phoneAngleIsBad) {
        isBadPostureNow = false;
        newStatus = 'GOOD';
        resetBadPostureTimer();
      } else if (!cameraIsActive) {
        isBadPostureNow = false;
        newStatus = 'GOOD';
        resetBadPostureTimer();
      } else {
        final fullFace = faceScore >= 4;

        final facingCamera = headY == null || headY!.abs() < 25;
        final headNotTooSideways = headZ == null || headZ!.abs() < 25;

        double estimatedNeckFlexion = phoneAngle;

        if (headX != null) {
          final calibratedHeadX = headX! - neutralHeadX;
          estimatedNeckFlexion = phoneAngle + calibratedHeadX.abs();
        }

        if (!fullFace) {
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
        } else if (estimatedNeckFlexion <= 15) {
          isBadPostureNow = false;
          newStatus = 'GOOD';
          resetBadPostureTimer();
        } else {
          isBadPostureNow = true;
          startOrContinueBadPostureTimer();

          if (badPostureSeconds >= alertDelaySeconds) {
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

        maybeSendBadPostureNotification(newStatus);
      }

      return;
    }

    isBadPostureNow = false;
    newStatus = 'GOOD';
    resetBadPostureTimer();

    if (mounted) {
      setState(() {
        postureStatus = newStatus;
      });

      maybeSendBadPostureNotification(newStatus);
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
    WidgetsBinding.instance.removeObserver(this);

    saveTodayStats();
    saveSettings();
    saveCoins();

    usageTimer?.cancel();
    cameraControlTimer?.cancel();
    accelerometerSubscription?.cancel();

    cameraIsActive = false;

    final controller = cameraController;
    cameraController = null;

    if (controller != null) {
      if (controller.value.isInitialized &&
          controller.value.isStreamingImages) {
        controller.stopImageStream().then((_) {
          controller.dispose();
        }).catchError((e) {
          print('Dispose camera error: $e');
        });
      } else {
        controller.dispose().catchError((e) {
          print('Dispose camera error: $e');
        });
      }
    }

    final detector = faceDetector;
    faceDetector = null;
    detector?.close();

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
                    width: 75,
                    height: 40,
                    child: FloatingActionButton.extended(
                      onPressed: null,
                      icon: const Icon(Icons.monetization_on_rounded),
                      label: Text('$totalCoins'),
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
                              initialDetectionMode: detectionMode,
                            ),
                          ),
                        );

                        if (result != null) {
                          setState(() {
                            alertDelaySeconds = result.alertDelaySeconds;
                            alertFrequencySeconds =
                                result.alertFrequencySeconds;
                            alertsEnabled = result.alertsEnabled;
                            detectionMode =
                                normaliseDetectionMode(result.detectionMode);
                          });

                          await saveSettings();
                          await manageCameraBasedOnPhoneAngle();
                          updatePostureStatus();
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
            Image.asset('images/happy slime.png', width: 300, height: 300),
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