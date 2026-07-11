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
import '../functions/posture_check.dart';
import '../functions/camera_func.dart';

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
  double smoothedPhoneAngle = 0;
  double neutralPhoneAngle = 0;
  final PhoneAngleFilter phoneAngleFilter = PhoneAngleFilter();
  final PostureHysteresis phoneAngleHysteresis = PostureHysteresis();
  final CameraFrameStability cameraFrameStability = CameraFrameStability();
  bool cameraDataIsReliable = false;
  final PhoneMovementDetector movementDetector = PhoneMovementDetector();
  bool isMovingTooMuch = false;
  String? cameraStatusMessage;

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
  int notificationBackoffLevel = 0;

  // Non-sensitive tuning counters; no sensor samples or images are stored.
  int badDetectionCount = 0;
  int goodDetectionCount = 0;
  int alertsSentCount = 0;
  int cameraUnavailableCount = 0;
  int movementPausedCount = 0;
  String? lastCountedPostureStatus;

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool get appIsInForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == AppLifecycleState.resumed;
  }

  bool get cameraAllowedInThisState {
    return detectionMode != modePhoneOrientationOnly && appIsInForeground;
  }

  String normaliseDetectionMode(String mode) {
    if (mode == modePhoneOrientationCamera) {
      return modePhoneOrientationCamera;
    }

    if (mode == modeCameraInAppOnly) return modeCameraInAppOnly;

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

    await notificationsPlugin.initialize(settings: initializationSettings);

    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
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

    if (newStatus == 'GOOD') {
      lastBadPostureNotificationTime = null;
      notificationBackoffLevel = 0;
      return;
    }
    if (newStatus != 'BAD') return;

    final now = DateTime.now();

    final backoffMultiplier = 1 << notificationBackoffLevel.clamp(0, 3);
    final currentInterval = alertFrequencySeconds * backoffMultiplier;
    final shouldSendNotification =
        lastBadPostureNotificationTime == null ||
        now.difference(lastBadPostureNotificationTime!).inSeconds >=
            currentInterval;

    if (!shouldSendNotification) return;

    final isRepeatedAlert = lastBadPostureNotificationTime != null;
    lastBadPostureNotificationTime = now;
    alertsSentCount++;
    if (isRepeatedAlert) {
      notificationBackoffLevel = (notificationBackoffLevel + 1)
          .clamp(0, 3)
          .toInt();
    }

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
    return FirebaseDatabase.instance.ref('users/demo_user/settings');
  }

  DatabaseReference get coinsRef {
    return FirebaseDatabase.instance.ref('users/demo_user/coins');
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
      final loadedNeutralPhoneAngle =
          (data['neutralPhoneAngle'] as num?)?.toDouble() ?? 0;
      final loadedNeutralHeadX =
          (data['neutralHeadX'] as num?)?.toDouble() ?? 0;

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
        neutralPhoneAngle = loadedNeutralPhoneAngle;
        neutralHeadX = loadedNeutralHeadX;
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

      // Merge ordinary preferences so calibration and threshold fields are not
      // replaced when another setting is saved.
      await settingsRef.update({
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
        badDetectionCount = (data['badDetectionCount'] as num?)?.toInt() ?? 0;
        goodDetectionCount = (data['goodDetectionCount'] as num?)?.toInt() ?? 0;
        alertsSentCount = (data['alertsSentCount'] as num?)?.toInt() ?? 0;
        cameraUnavailableCount =
            (data['cameraUnavailableCount'] as num?)?.toInt() ?? 0;
        movementPausedCount =
            (data['movementPausedCount'] as num?)?.toInt() ?? 0;
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

      final loadedLastAwardedDate =
          data['lastAwardedDate'] as String? ??
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

      DateTime dateToCheck = parsedLastAwardedDate.add(const Duration(days: 1));

      while (dateToCheck.isBefore(todayDate)) {
        final dateKey = getDateKey(dateToCheck);
        final snapshot = await dailyStatsRef(dateKey).get();

        if (snapshot.exists && snapshot.value != null) {
          final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
          final alreadyAwarded = data['coinsAwarded'] as bool? ?? false;

          if (!alreadyAwarded) {
            final rawScore =
                (data['score'] as num?)?.toInt() ??
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
        resetTuningCounters();
      });
    } else {
      activeDateKey = todayKey;
      totalScreenTime = 0;
      totalBadPostureTime = 0;
      coinsEarnedToday = 0;
      resetTuningCounters();
    }

    resetBadPostureTimer();

    await loadTodayStats();
    await saveTodayStats();
  }

  void resetTuningCounters() {
    badDetectionCount = 0;
    goodDetectionCount = 0;
    alertsSentCount = 0;
    cameraUnavailableCount = 0;
    movementPausedCount = 0;
    lastCountedPostureStatus = null;
  }

  Future<void> saveTodayStats({String? dateKey}) async {
    try {
      final targetDateKey =
          dateKey ?? (activeDateKey.isEmpty ? getTodayKey() : activeDateKey);

      final goodPostureTime = max(
        0,
        totalScreenTime - totalBadPostureTime,
      ).toInt();

      final existingSnapshot = await dailyStatsRef(targetDateKey).get();
      final existingData =
          existingSnapshot.exists && existingSnapshot.value != null
              ? Map<dynamic, dynamic>.from(existingSnapshot.value as Map)
              : <dynamic, dynamic>{};

      await dailyStatsRef(targetDateKey).update({
        'date': targetDateKey,
        'updatedAt': ServerValue.timestamp,
        'totalScreenTimeSeconds': totalScreenTime,
        'totalBadPostureSeconds': totalBadPostureTime,
        'goodPostureSeconds': goodPostureTime,
        'score': dailyScore.round(),
        'scorePercent': dailyScore.round(),
        'coinsEarned': existingData['coinsEarned'] as num? ?? coinsEarnedToday,
        'coinsAwarded': existingData['coinsAwarded'] as bool? ?? false,
        'badDetectionCount': badDetectionCount,
        'goodDetectionCount': goodDetectionCount,
        'alertsSentCount': alertsSentCount,
        'cameraUnavailableCount': cameraUnavailableCount,
        'movementPausedCount': movementPausedCount,
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
      smoothedPhoneAngle = phoneAngleFilter.add(angle);
      final wasMovingTooMuch = isMovingTooMuch;
      isMovingTooMuch = movementDetector.add(angle);
      if (isMovingTooMuch && !wasMovingTooMuch) movementPausedCount++;

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

    final effectiveAngle = calibratedPhoneAngle(
      smoothedPhoneAngle,
      neutralPhoneAngle,
    );

    if (effectiveAngle >= cameraStartAngle &&
        !cameraIsActive &&
        !isStartingCamera &&
        !isStoppingCamera) {
      await startCamera();
      return;
    }

    if (effectiveAngle <= cameraStopAngle &&
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
        markCameraUnavailable('Camera detection unavailable');
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
      cameraStatusMessage = null;

      updatePostureStatus();
    } catch (e) {
      print('Camera error: $e');

      cameraController = null;
      cameraIsActive = false;
      markCameraUnavailable('Camera unavailable; using phone angle');

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
    cameraDataIsReliable = false;
    cameraFrameStability.reset();
    headX = null;
    headY = null;
    headZ = null;
  }

  void markCameraUnavailable(String message) {
    if (cameraStatusMessage == null) cameraUnavailableCount++;
    cameraStatusMessage = message;
  }

  Future<void> processCameraImage(CameraImage image) async {
    if (!cameraIsActive) return;
    if (isProcessing) return;

    final detector = faceDetector;
    if (detector == null) return;

    final now = DateTime.now();

    if (now.difference(lastFaceDetectionTime) < cameraDetectionInterval) {
      return;
    }

    lastFaceDetectionTime = now;
    isProcessing = true;

    try {
      final inputImage = inputImageFromCameraImage(image);

      if (inputImage == null) {
        return;
      }

      // ML Kit processes frames on-device. This app never uploads camera
      // frames, face images, or biometric image data.
      final faces = await detector.processImage(inputImage);

      if (!mounted || !cameraIsActive) return;

      if (faces.isEmpty) {
        clearFaceData();
        markCameraUnavailable('Face not detected; using phone angle');
      } else {
        final face = faces.first;

        headX = face.headEulerAngleX;
        headY = face.headEulerAngleY;
        headZ = face.headEulerAngleZ;
        cameraDataIsReliable = cameraFrameStability.addFrame(
          faceWidth: face.boundingBox.width,
          faceHeight: face.boundingBox.height,
          imageWidth: image.width.toDouble(),
          imageHeight: image.height.toDouble(),
          headX: headX,
          headY: headY,
          headZ: headZ,
        );
        if (cameraDataIsReliable) {
          headX = cameraFrameStability.averageHeadX;
          headY = cameraFrameStability.averageHeadY;
          headZ = cameraFrameStability.averageHeadZ;
          cameraStatusMessage = null;
        } else {
          cameraStatusMessage = 'Checking camera position…';
        }
      }

      updatePostureStatus();
    } catch (e) {
      print('Face detection error: $e');
    } finally {
      isProcessing = false;
    }
  }

  void updatePostureStatus() {
    String newStatus;

    // Large movements usually mean the phone is being carried or repositioned.
    if (isMovingTooMuch) {
      resetBadPostureTimer();
      if (mounted && postureStatus != 'BAD') {
        setPostureStatus('WARNING');
      }
      return;
    }

    final effectivePhoneAngle = calibratedPhoneAngle(
      smoothedPhoneAngle,
      neutralPhoneAngle,
    );
    final phoneAngleIsBad = phoneAngleHysteresis.update(effectivePhoneAngle);

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
        setPostureStatus(newStatus);
      }

      return;
    }

    if (detectionMode == modePhoneOrientationCamera ||
        detectionMode == modeCameraInAppOnly) {
      if (!phoneAngleIsBad) {
        isBadPostureNow = false;
        newStatus = 'GOOD';
        resetBadPostureTimer();
      } else if (!cameraIsActive || !cameraDataIsReliable) {
        // Missing or weak camera data must not turn a bad phone reading GOOD.
        isBadPostureNow = true;
        startOrContinueBadPostureTimer();
        newStatus = badPostureSeconds >= alertDelaySeconds ? 'BAD' : 'WARNING';
      } else {
        final facingCamera = headY == null || headY!.abs() < 25;
        final headNotTooSideways = headZ == null || headZ!.abs() < 25;

        double estimatedNeckFlexion = effectivePhoneAngle;

        if (headX != null) {
          final calibratedHeadX = headX! - neutralHeadX;
          estimatedNeckFlexion = effectivePhoneAngle + calibratedHeadX.abs();
        }

        if (!facingCamera) {
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
        setPostureStatus(newStatus);
      }

      return;
    }

    isBadPostureNow = false;
    newStatus = 'GOOD';
    resetBadPostureTimer();

    if (mounted) {
      setPostureStatus(newStatus);
    }
  }

  void setPostureStatus(String newStatus) {
    if (lastCountedPostureStatus != newStatus) {
      if (newStatus == 'BAD') badDetectionCount++;
      if (newStatus == 'GOOD') goodDetectionCount++;
      lastCountedPostureStatus = newStatus;
    }
    setState(() => postureStatus = newStatus);
    maybeSendBadPostureNotification(newStatus);
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

  Future<bool> calibrateNeutral() async {
    final calibratedPhoneAngle = smoothedPhoneAngle;
    final calibratedHeadX = cameraDataIsReliable ? headX : null;

    final calibrationUpdate = <String, Object?>{
      'neutralPhoneAngle': calibratedPhoneAngle,
      'updatedAt': ServerValue.timestamp,
    };
    if (calibratedHeadX != null) {
      calibrationUpdate['neutralHeadX'] = calibratedHeadX;
    }

    try {
      // Calibration has its own write so normal settings saves cannot replace it.
      await settingsRef.update(calibrationUpdate);
      if (!mounted) return true;

      setState(() {
        neutralPhoneAngle = calibratedPhoneAngle;
        if (calibratedHeadX != null) neutralHeadX = calibratedHeadX;
        resetBadPostureTimer();
        postureStatus = 'GOOD';
      });
      updatePostureStatus();
      await manageCameraBasedOnPhoneAngle();
      return true;
    } catch (e) {
      debugPrint('Save neutral calibration Firebase error: $e');
      return false;
    }
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
        controller
            .stopImageStream()
            .then((_) {
              controller.dispose();
            })
            .catchError((e) {
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
                              onCalibrateNeutral: calibrateNeutral,
                            ),
                          ),
                        );

                        if (result != null) {
                          setState(() {
                            alertDelaySeconds = result.alertDelaySeconds;
                            alertFrequencySeconds =
                                result.alertFrequencySeconds;
                            alertsEnabled = result.alertsEnabled;
                            detectionMode = normaliseDetectionMode(
                              result.detectionMode,
                            );
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
            Text('Score: $scorePercent', style: const TextStyle(fontSize: 18)),
            if (isMovingTooMuch)
              const Text('Movement detected — posture check paused')
            else if (cameraStatusMessage != null &&
                detectionMode != modePhoneOrientationOnly)
              Text(cameraStatusMessage!, style: const TextStyle(fontSize: 13)),
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
