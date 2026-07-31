import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../functions/posture_check.dart';
import '../models/calibration.dart';
import '../models/home_live_times.dart';
import '../models/posture_thresholds.dart';
import '../models/statistics_summary.dart';
import '../services/device_screen_time_service.dart';
import '../services/monitoring_service.dart';
import '../services/preferences_service.dart';
import '../services/statistics_repository.dart';
import 'customize_page.dart';
import 'settings_page.dart';
import 'statistics_page.dart';
import 'tutorial_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  static const Duration cameraDetectionInterval = Duration(milliseconds: 500);
  static const Duration deviceScreenTimeRefreshInterval = Duration(minutes: 1);

  final SettingsRepository _settingsRepository = SettingsRepository();
  final CalibrationRepository _calibrationRepository = CalibrationRepository();
  final StatisticsRepository _statisticsRepository = StatisticsRepository();
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final CameraFrameStability _cameraFrameStability = CameraFrameStability();
  final DeviceScreenTimeProvider _deviceScreenTimeProvider =
      const AndroidDeviceScreenTimeProvider();
  final PresentationTicker _presentationTicker = PresentationTicker();
  late final HomeLiveTimes _liveTimes;

  StreamSubscription<DailyStats>? _statsSubscription;
  Timer? _serviceStateTimer;
  Timer? _deviceScreenTimeRefreshTimer;

  Calibration? _calibration;
  DailyStats _stats = const DailyStats();
  String _activeDateKey = postureDateKey();

  bool _initializing = true;
  bool _monitoringActive = false;
  bool _screenInteractive = true;
  bool _changingMonitoringState = false;
  String _postureStatus = 'GOOD';
  double _phoneAngle = 0;
  bool _hasPhoneAngle = false;
  final List<({DateTime timestamp, double angle})> _recentPhoneAngles = [];
  String? _monitoringError;
  bool _deviceScreenTimeSupported = false;
  bool _hasUsageAccess = false;
  int? _lastSavedDeviceScreenTime;

  int _totalCoins = 0;
  int _coinsEarnedToday = 0;
  String? _lastAwardedDate;

  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _cameraActive = false;
  bool _cameraStarting = false;
  bool _cameraStopping = false;
  bool _processingCameraFrame = false;
  bool _cameraPermissionGranted = false;
  bool _cameraUnavailableForSession = false;
  bool _cameraDataReliable = false;
  DateTime _lastFaceDetectionTime = DateTime.fromMillisecondsSinceEpoch(0);
  String? _cameraStatusMessage;
  double? _headX;
  double? _headY;
  double? _headZ;

  bool get _appIsVisible {
    return WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  bool get _homeIsVisible {
    return _appIsVisible && (ModalRoute.of(context)?.isCurrent ?? true);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _liveTimes = HomeLiveTimes(dateKey: _activeDateKey);
    FlutterForegroundTask.addTaskDataCallback(_onServiceData);
    _subscribeToTodayStats();
    _initialize();
    _presentationTicker.start(_onPresentationTick);
    _serviceStateTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshServiceState(),
    );
    _deviceScreenTimeRefreshTimer = Timer.periodic(
      deviceScreenTimeRefreshInterval,
      (_) => unawaited(_refreshDeviceScreenTime()),
    );
  }

  Future<void> _initialize() async {
    final settingsResult = await _settingsRepository.load();
    final calibrationResult = await _calibrationRepository.load();
    await _loadCoinsAndAwardCompletedDays();
    await _refreshCameraPermissionStatus();
    await _refreshDeviceScreenTime();
    final running = await MonitoringService.isRunning();

    if (!mounted) return;
    setState(() {
      _calibration = calibrationResult.calibration;
      _monitoringActive = running;
      _initializing = false;
    });

    final warning = calibrationResult.warning ?? settingsResult.warning;
    if (warning != null) _showMessage(warning);
    if (_calibration == null) {
      _showMessage(
        'Calibrate your upright phone position before starting monitoring.',
      );
    }
    if (running) {
      MonitoringService.requestState();
      await _manageCamera();
    }
  }

  void _subscribeToTodayStats() {
    _statsSubscription?.cancel();
    final nextDateKey = postureDateKey();
    final changedDate = nextDateKey != _activeDateKey;
    _activeDateKey = nextDateKey;
    if (changedDate && mounted) {
      setState(() {
        _stats = const DailyStats();
        _liveTimes
          ..dateKey = nextDateKey
          ..monitoredSeconds = 0
          ..badPostureSeconds = 0
          ..deviceScreenTimeSeconds = null;
        _lastSavedDeviceScreenTime = null;
      });
    }
    _statsSubscription = _statisticsRepository
        .watch(_activeDateKey)
        .listen(
          (stats) {
            if (mounted) {
              setState(() {
                _stats = stats;
                _liveTimes.reconcile(stats);
              });
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (mounted) {
              _showMessage(
                'Statistics are temporarily unavailable. Monitoring will keep retrying.',
              );
            }
          },
        );
  }

  void _onPresentationTick() {
    if (!mounted) return;
    final crossedMidnight = _liveTimes.advance(
      now: DateTime.now(),
      monitoringActive:
          _monitoringActive && _screenInteractive && _homeIsVisible,
      postureStatus: _postureStatus,
      incrementDeviceScreenTime:
          _deviceScreenTimeSupported && _hasUsageAccess && _homeIsVisible,
    );
    setState(() {});
    if (crossedMidnight) {
      _subscribeToTodayStats();
      unawaited(_refreshDeviceScreenTime());
      unawaited(_loadCoinsAndAwardCompletedDays());
    }
  }

  Future<void> _refreshDeviceScreenTime() async {
    final supported = await _deviceScreenTimeProvider.isSupported();
    final hasAccess =
        supported && await _deviceScreenTimeProvider.hasUsageAccess();
    final seconds = hasAccess
        ? await _deviceScreenTimeProvider.getTodayScreenTimeSeconds()
        : null;
    if (!mounted) return;
    setState(() {
      _deviceScreenTimeSupported = supported;
      _hasUsageAccess = hasAccess;
      if (seconds != null) _liveTimes.reconcileDeviceScreenTime(seconds);
    });

    if (seconds != null &&
        (_lastSavedDeviceScreenTime == null ||
            (seconds - _lastSavedDeviceScreenTime!).abs() >= 30)) {
      _lastSavedDeviceScreenTime = seconds;
      unawaited(
        _statisticsRepository
            .saveDeviceScreenTime(_activeDateKey, seconds)
            .catchError((Object error) {
              debugPrint('Could not save device screen time: $error');
            }),
      );
    }
  }

  Future<void> _refreshPresentationSources() async {
    final today = postureDateKey();
    if (today != _activeDateKey) _subscribeToTodayStats();
    await _refreshServiceState();
    MonitoringService.requestState();
    await _refreshDeviceScreenTime();
  }

  Future<void> _refreshServiceState() async {
    final today = postureDateKey();
    if (today != _activeDateKey) {
      _subscribeToTodayStats();
      unawaited(_loadCoinsAndAwardCompletedDays());
    }

    final running = await MonitoringService.isRunning();
    if (!mounted) return;
    if (running != _monitoringActive) {
      setState(() {
        _monitoringActive = running;
        if (!running) {
          _postureStatus = 'GOOD';
          _monitoringError =
              'Monitoring stopped unexpectedly. Open Settings to restart it.';
        }
      });
      if (!running) {
        await _stopCamera();
      } else {
        MonitoringService.requestState();
        await _manageCamera();
      }
    }
  }

  void _onServiceData(Object data) {
    if (!mounted || data is! Map) return;
    if (data['type'] == 'monitoringError') {
      final message = data['message']?.toString();
      if (message != null) {
        setState(() => _monitoringError = message);
        _showMessage(message);
      }
      return;
    }

    if (data['type'] != 'monitoringState') return;
    final active = data['active'] == true;
    final angle = (data['phoneAngle'] as num?)?.toDouble();
    final hasSensorReading = data['hasSensorReading'] == true;
    final screenInteractive = data['screenInteractive'] != false;
    setState(() {
      _monitoringActive = active;
      _screenInteractive = screenInteractive;
      _postureStatus = active
          ? data['postureStatus']?.toString() ?? 'GOOD'
          : 'GOOD';
      if (angle != null &&
          isValidSensorPhoneAngle(angle) &&
          active &&
          screenInteractive &&
          hasSensorReading) {
        _phoneAngle = angle;
        _hasPhoneAngle = true;
        final now = DateTime.now();
        _recentPhoneAngles.add((timestamp: now, angle: angle));
        _recentPhoneAngles.removeWhere(
          (sample) => now.difference(sample.timestamp).inSeconds > 8,
        );
        if (_recentPhoneAngles.length > 8) {
          _recentPhoneAngles.removeRange(0, _recentPhoneAngles.length - 8);
        }
      } else if (!screenInteractive || !active) {
        _hasPhoneAngle = false;
        _recentPhoneAngles.clear();
      }
      if (active) _monitoringError = null;
    });
    unawaited(active ? _manageCamera() : _stopCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      MonitoringService.updateCameraSupplement(available: false);
      unawaited(_stopCamera());
      return;
    }

    unawaited(
      _refreshCameraPermissionStatus().then((_) async {
        _cameraUnavailableForSession = false;
        await _refreshPresentationSources();
        await _manageCamera();
      }),
    );
  }

  Future<MonitoringControlResult> _startMonitoring() async {
    if (_monitoringActive) {
      return const MonitoringControlResult(success: true, isActive: true);
    }
    if (_changingMonitoringState) {
      return const MonitoringControlResult(
        success: false,
        isActive: false,
        message: 'A monitoring action is already in progress.',
      );
    }
    setState(() {
      _changingMonitoringState = true;
      _monitoringError = null;
      _cameraUnavailableForSession = false;
    });

    await _requestCameraPermissionOnce();
    final result = await MonitoringService.start();
    if (!mounted) {
      return MonitoringControlResult(
        success: result.success,
        isActive: result.success && result.isRunning,
      );
    }

    setState(() {
      _changingMonitoringState = false;
      _monitoringActive = result.success && result.isRunning;
      if (!result.success) {
        _monitoringError =
            'Foreground monitoring could not start: ${result.error}';
      }
    });

    if (!result.success) {
      return MonitoringControlResult(
        success: false,
        isActive: false,
        message: _monitoringError,
      );
    }

    MonitoringService.requestState();
    await _manageCamera();
    return MonitoringControlResult(
      success: true,
      isActive: true,
      message: result.notificationPermission != NotificationPermission.granted
          ? 'Monitoring is active, but Android notifications are disabled. '
                'Enable notifications in system settings to receive posture alerts.'
          : 'Monitoring started.',
    );
  }

  Future<MonitoringControlResult> _stopMonitoring() async {
    if (!_monitoringActive) {
      return const MonitoringControlResult(success: true, isActive: false);
    }
    if (_changingMonitoringState) {
      return const MonitoringControlResult(
        success: false,
        isActive: true,
        message: 'A monitoring action is already in progress.',
      );
    }

    setState(() => _changingMonitoringState = true);
    await _stopCamera();
    MonitoringService.updateCameraSupplement(available: false);
    final result = await MonitoringService.stop();
    if (!mounted) {
      return MonitoringControlResult(
        success: result.success,
        isActive: result.isRunning,
      );
    }

    setState(() {
      _changingMonitoringState = false;
      _monitoringActive = result.isRunning;
      if (!result.isRunning) {
        _postureStatus = 'GOOD';
        _monitoringError = null;
      } else {
        _monitoringError = 'Monitoring could not be stopped: ${result.error}';
      }
    });
    return MonitoringControlResult(
      success: result.success,
      isActive: result.isRunning,
      message: result.success
          ? 'Monitoring stopped.'
          : 'Monitoring could not be stopped: ${result.error}',
    );
  }

  Future<bool> _calibrateNeutral() async {
    double? angle;
    if (_monitoringActive && _hasPhoneAngle) {
      final now = DateTime.now();
      final recent = _recentPhoneAngles
          .where((sample) => now.difference(sample.timestamp).inSeconds <= 5)
          .map((sample) => sample.angle);
      angle = stablePhoneAngle(recent);
      if (angle == null) {
        _showMessage(
          'Hold the phone steady in your viewing position for a few seconds, then try again.',
        );
        return false;
      }
    } else if (_monitoringActive) {
      _showMessage(
        'Waiting for the orientation sensor. Hold the phone steady and try again.',
      );
      return false;
    } else {
      angle = await _readCalibrationAngle();
    }

    if (angle == null || !isValidSensorPhoneAngle(angle)) {
      _showMessage(
        'Calibration failed because a stable phone angle was not available.',
      );
      return false;
    }
    if (!isValidCalibrationPhoneAngle(angle)) {
      _showMessage(
        'Calibration needs a stable phone-angle reading. Hold the phone still in '
        'your usual viewing position, then try again.',
      );
      return false;
    }

    final calibration = Calibration(
      neutralPhoneAngle: angle,
      neutralHeadX:
          _cameraDataReliable &&
              _headX != null &&
              Calibration.isValidHeadAngle(_headX!)
          ? _headX
          : _calibration?.neutralHeadX,
    );

    try {
      final result = await _calibrationRepository.save(calibration);
      if (!mounted) return result.savedLocally;
      setState(() {
        _calibration = calibration;
        _postureStatus = 'GOOD';
        _recentPhoneAngles.clear();
      });
      MonitoringService.updateCalibration(calibration);
      if (!result.savedToFirebase) {
        _showMessage(
          'Calibration was saved on this device, but Firebase sync failed.',
        );
      }
      return result.savedLocally;
    } catch (error) {
      _showMessage('Could not save calibration: $error');
      return false;
    }
  }

  Future<double?> _readCalibrationAngle() async {
    final filter = PhoneAngleFilter();
    final samples = <double>[];
    try {
      await for (final event
          in accelerometerEventStream()
              .take(10)
              .timeout(const Duration(seconds: 4))) {
        final rawAngle = phoneAngleFromAccelerometer(
          x: event.x,
          y: event.y,
          z: event.z,
        );
        if (rawAngle == null) continue;
        final smoothed = filter.add(rawAngle);
        if (smoothed != null) samples.add(smoothed);
      }
      return stablePhoneAngle(samples);
    } catch (error) {
      debugPrint('Calibration sensor error: $error');
      return null;
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => Settings(
          store: _settingsRepository,
          screenTimeProvider: _deviceScreenTimeProvider,
          onCalibrateNeutral: _calibrateNeutral,
          initialCalibration: _calibration,
          currentCalibration: () => _calibration,
          initialHasCalibration: _calibration != null,
          loadMonitoringState: _loadMonitoringStateForSettings,
          onMonitoringEnabledChanged: (enabled) {
            return enabled ? _startMonitoring() : _stopMonitoring();
          },
          onSettingsSaved: (settings) async {
            MonitoringService.updateSettings(settings);
          },
        ),
      ),
    );

    final result = await _settingsRepository.load();
    if (!mounted) return;
    MonitoringService.updateSettings(result.settings);
    await _refreshPresentationSources();
  }

  Future<bool> _loadMonitoringStateForSettings() async {
    await _refreshServiceState();
    return _monitoringActive;
  }

  Future<void> _requestCameraPermissionOnce() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      if (mounted) setState(() => _cameraPermissionGranted = true);
      return;
    }

    final alreadyRequested =
        await _preferences.getBool(PreferenceKeys.cameraPermissionRequested) ??
        false;
    if (alreadyRequested || status.isPermanentlyDenied || !mounted) {
      if (mounted) setState(() => _cameraPermissionGranted = false);
      return;
    }

    await _preferences.setBool(PreferenceKeys.cameraPermissionRequested, true);
    final requested = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _cameraPermissionGranted = requested.isGranted);
    if (!requested.isGranted) {
      _showMessage(
        'Camera access was not granted. Phone-angle monitoring will continue normally.',
      );
    }
  }

  Future<void> _refreshCameraPermissionStatus() async {
    try {
      final status = await Permission.camera.status;
      if (mounted) {
        setState(() => _cameraPermissionGranted = status.isGranted);
      } else {
        _cameraPermissionGranted = status.isGranted;
      }
    } catch (error) {
      debugPrint('Could not check camera permission: $error');
      _cameraPermissionGranted = false;
    }
  }

  Future<void> _manageCamera() async {
    if (!mounted) return;
    final calibration = _calibration;
    final allowed =
        _monitoringActive &&
        _appIsVisible &&
        _screenInteractive &&
        _hasPhoneAngle &&
        _cameraPermissionGranted &&
        calibration != null;
    if (!allowed) {
      await _stopCamera();
      return;
    }

    final thresholds = calculatePostureThresholds(
      calibration.neutralPhoneAngle,
    );
    if (_phoneAngle <= thresholds.badEnterAngle && !_cameraActive) {
      await _startCamera();
    } else if (_phoneAngle >= thresholds.goodExitAngle && _cameraActive) {
      await _stopCamera();
    }
  }

  Future<void> _startCamera() async {
    if (_cameraActive ||
        _cameraStarting ||
        _cameraStopping ||
        _cameraUnavailableForSession) {
      return;
    }
    if (!_monitoringActive || !_appIsVisible || !_cameraPermissionGranted) {
      return;
    }

    _cameraStarting = true;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _markCameraUnavailable('Camera unavailable; using phone angle.');
        return;
      }

      final front = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();

      if (!mounted ||
          !_monitoringActive ||
          !_appIsVisible ||
          !_cameraPermissionGranted) {
        await controller.dispose();
        return;
      }

      _faceDetector ??= FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.fast,
          enableLandmarks: true,
          enableContours: false,
          enableTracking: true,
        ),
      );
      _cameraController = controller;
      _cameraActive = true;
      _cameraStatusMessage = null;
      await controller.startImageStream(_processCameraImage);
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('Camera initialization failed: $error');
      await _disposeCurrentCameraController();
      _markCameraUnavailable(
        'Camera could not start; monitoring continues with phone angle.',
      );
    } finally {
      _cameraStarting = false;
    }
  }

  Future<void> _stopCamera() async {
    if (_cameraStopping) return;
    _cameraStopping = true;
    _cameraActive = false;
    MonitoringService.updateCameraSupplement(available: false);
    try {
      await _disposeCurrentCameraController();
    } finally {
      _cameraStopping = false;
      _clearCameraData();
      if (mounted) setState(() {});
    }
  }

  Future<void> _disposeCurrentCameraController() async {
    final controller = _cameraController;
    _cameraController = null;
    _cameraActive = false;
    if (controller == null) return;

    try {
      if (controller.value.isInitialized &&
          controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.dispose();
    } catch (error) {
      debugPrint('Camera disposal failed: $error');
    }
  }

  void _clearCameraData() {
    _cameraDataReliable = false;
    _cameraFrameStability.reset();
    _headX = null;
    _headY = null;
    _headZ = null;
  }

  void _markCameraUnavailable(String message, {bool disableRetry = true}) {
    final firstFailure = _cameraStatusMessage == null;
    _cameraStatusMessage = message;
    if (disableRetry) _cameraUnavailableForSession = true;
    _clearCameraData();
    MonitoringService.updateCameraSupplement(available: false);
    if (firstFailure) MonitoringService.reportCameraUnavailable();
    if (mounted) setState(() {});
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_cameraActive || _processingCameraFrame) return;
    final now = DateTime.now();
    if (now.difference(_lastFaceDetectionTime) < cameraDetectionInterval) {
      return;
    }

    final detector = _faceDetector;
    if (detector == null) return;
    _lastFaceDetectionTime = now;
    _processingCameraFrame = true;
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      // Frames are processed on-device and are never saved or uploaded.
      final faces = await detector.processImage(inputImage);
      if (!mounted || !_cameraActive) return;
      if (faces.isEmpty) {
        _markCameraUnavailable(
          'Face not detected; using phone angle.',
          disableRetry: false,
        );
        return;
      }

      final face = faces.first;
      _headX = face.headEulerAngleX;
      _headY = face.headEulerAngleY;
      _headZ = face.headEulerAngleZ;
      _cameraDataReliable = _cameraFrameStability.addFrame(
        faceWidth: face.boundingBox.width,
        faceHeight: face.boundingBox.height,
        imageWidth: image.width.toDouble(),
        imageHeight: image.height.toDouble(),
        headX: _headX,
        headY: _headY,
        headZ: _headZ,
      );

      if (!_cameraDataReliable) {
        setState(() => _cameraStatusMessage = 'Checking camera position…');
        MonitoringService.updateCameraSupplement(available: false);
        return;
      }

      _headX = _cameraFrameStability.averageHeadX;
      _headY = _cameraFrameStability.averageHeadY;
      _headZ = _cameraFrameStability.averageHeadZ;
      setState(() => _cameraStatusMessage = null);

      final calibration = _calibration;
      if (calibration == null) return;
      final phoneAngleDrop = max(
        0.0,
        calibration.neutralPhoneAngle - _phoneAngle,
      );
      final facingCamera = _headY == null || _headY!.abs() < 25;
      final headNotSideways = _headZ == null || _headZ!.abs() < 25;
      var estimatedNeckFlexion = phoneAngleDrop;
      if (_headX != null) {
        estimatedNeckFlexion += (_headX! - (calibration.neutralHeadX ?? 0))
            .abs();
      }
      final suggestsGoodPosture =
          !facingCamera || !headNotSideways || estimatedNeckFlexion <= 15;
      MonitoringService.updateCameraSupplement(
        available: true,
        suggestsGoodPosture: suggestsGoodPosture,
      );
    } catch (error) {
      debugPrint('Face detection failed: $error');
      _markCameraUnavailable('Camera detection failed; using phone angle.');
    } finally {
      _processingCameraFrame = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final controller = _cameraController;
    if (controller == null || image.planes.isEmpty) return null;
    final rotation = InputImageRotationValue.fromRawValue(
      controller.description.sensorOrientation,
    );
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null) return null;

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

  Future<void> _loadCoinsAndAwardCompletedDays() async {
    final coinsRef = FirebaseDatabase.instance.ref('users/demo_user/coins');
    try {
      final snapshot = await coinsRef.get();
      if (!snapshot.exists || snapshot.value == null) {
        _totalCoins = 0;
        _coinsEarnedToday = 0;
        _lastAwardedDate = postureDateKey(
          DateTime.now().subtract(const Duration(days: 1)),
        );
        await _saveCoins();
      } else {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        _totalCoins = (data['totalCoins'] as num?)?.toInt() ?? 0;
        _coinsEarnedToday = 0;
        _lastAwardedDate =
            data['lastAwardedDate'] as String? ??
            postureDateKey(DateTime.now().subtract(const Duration(days: 1)));
      }
      await _awardCoinsForCompletedDays();
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('Coin loading failed: $error');
    }
  }

  Future<void> _awardCoinsForCompletedDays() async {
    final today = DateTime.parse(postureDateKey());
    final fallback = today.subtract(const Duration(days: 1));
    DateTime lastAwarded;
    try {
      lastAwarded = DateTime.parse(_lastAwardedDate ?? '');
    } catch (_) {
      lastAwarded = fallback;
    }

    var date = lastAwarded.add(const Duration(days: 1));
    while (date.isBefore(today)) {
      final dateKey = postureDateKey(date);
      final ref = FirebaseDatabase.instance.ref(
        'users/demo_user/daily_stats/$dateKey',
      );
      final snapshot = await ref.get();
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        final alreadyAwarded = data['coinsAwarded'] as bool? ?? false;
        if (!alreadyAwarded) {
          final score =
              ((data['score'] as num?)?.toInt() ??
                      (data['scorePercent'] as num?)?.toInt() ??
                      0)
                  .clamp(0, 100);
          _totalCoins = max(0, _totalCoins + score);
          await ref.update({
            'coinsEarned': score,
            'coinsAwarded': true,
            'coinsAwardedAt': ServerValue.timestamp,
          });
        }
      }
      _lastAwardedDate = dateKey;
      date = date.add(const Duration(days: 1));
    }
    await _saveCoins();
  }

  Future<void> _saveCoins() async {
    try {
      await FirebaseDatabase.instance.ref('users/demo_user/coins').set({
        'totalCoins': _totalCoins,
        'coinsEarnedToday': _coinsEarnedToday,
        'lastAwardedDate': _lastAwardedDate,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (error) {
      debugPrint('Coin saving failed: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatTime(int seconds) {
    return formatCompactDuration(seconds);
  }

  bool get _showDeviceScreenTime {
    return _deviceScreenTimeSupported &&
        _hasUsageAccess &&
        _liveTimes.deviceScreenTimeSeconds != null;
  }

  Color _statusColor() {
    if (!_monitoringActive) return Colors.grey;
    return switch (_postureStatus) {
      'GOOD' => Colors.green,
      'WARNING' => Colors.orange,
      _ => Colors.red,
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onServiceData);
    _statsSubscription?.cancel();
    _serviceStateTimer?.cancel();
    _deviceScreenTimeRefreshTimer?.cancel();
    _presentationTicker.dispose();
    unawaited(_disposeCameraResources());
    super.dispose();
  }

  Future<void> _disposeCameraResources() async {
    await _stopCamera();
    final detector = _faceDetector;
    _faceDetector = null;
    await detector?.close();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          key: const Key('homeScrollView'),
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 35, left: 25, right: 25),
              child: Row(
                children: [
                  SizedBox(
                    width: 75,
                    height: 40,
                    child: FloatingActionButton.extended(
                      heroTag: 'homeCoinsButton',
                      onPressed: null,
                      icon: const Icon(Icons.monetization_on_rounded),
                      label: Text('$_totalCoins'),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: FloatingActionButton(
                      heroTag: 'homeHelpButton',
                      tooltip: 'How to use Posture Guard',
                      onPressed: () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const TutorialPage(isReplay: true),
                          ),
                        );
                        if (mounted) await _refreshPresentationSources();
                      },
                      child: const Icon(Icons.question_mark),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: FloatingActionButton(
                      heroTag: 'homeSettingsButton',
                      tooltip: 'Settings',
                      onPressed: _openSettings,
                      child: const Icon(Icons.settings),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'STATUS',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20),
            ),
            Text(
              _postureStatus,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.bold,
                color: _statusColor(),
              ),
            ),
            Text(
              'Score: ${_stats.dailyScore.round()}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            if (_cameraStatusMessage != null)
              Text(
                _cameraStatusMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            const SizedBox(height: 20),
            Image.asset('images/happy slime.png', width: 300, height: 300),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time_filled, size: 35),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _showDeviceScreenTime
                                    ? 'Device screen time'
                                    : 'Monitored time',
                                style: const TextStyle(fontSize: 11),
                              ),
                              Text(
                                _formatTime(
                                  _showDeviceScreenTime
                                      ? _liveTimes.deviceScreenTimeSeconds!
                                      : _liveTimes.monitoredSeconds,
                                ),
                                style: const TextStyle(fontSize: 20),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.sentiment_dissatisfied_sharp,
                          size: 35,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bad posture',
                                style: TextStyle(fontSize: 11),
                              ),
                              Text(
                                _formatTime(_liveTimes.badPostureSeconds),
                                style: const TextStyle(fontSize: 20),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: FloatingActionButton(
                        heroTag: 'homeCustomizeButton',
                        onPressed: () async {
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const Customizes(),
                            ),
                          );
                          if (mounted) await _refreshPresentationSources();
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
                  ),
                  const SizedBox(width: 15),
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: FloatingActionButton(
                      heroTag: 'homeStatisticsButton',
                      tooltip: 'Statistics',
                      onPressed: () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Statistics(
                              screenTimeProvider: _deviceScreenTimeProvider,
                            ),
                          ),
                        );
                        if (mounted) await _refreshPresentationSources();
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
