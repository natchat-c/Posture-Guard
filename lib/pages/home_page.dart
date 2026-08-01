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
import '../l10n/locale_controller.dart';
import '../models/calibration.dart';
import '../models/home_live_times.dart';
import '../models/posture_thresholds.dart';
import '../services/device_screen_time_service.dart';
import '../services/monitoring_service.dart';
import '../services/preferences_service.dart';
import '../services/statistics_repository.dart';
import '../widgets/coach_mark_overlay.dart';
import '../widgets/responsive_layout.dart';
import 'customize_page.dart';
import 'settings_page.dart';
import 'statistics_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    this.showTourOnStart = false,
    @visibleForTesting this.testMode = false,
    @visibleForTesting this.settingsStore,
    @visibleForTesting this.screenTimeProvider,
    @visibleForTesting this.initialPostureStatus = 'GOOD',
    @visibleForTesting this.initialMonitoringActive = true,
  });

  final bool showTourOnStart;
  final bool testMode;
  final SettingsStore? settingsStore;
  final DeviceScreenTimeProvider? screenTimeProvider;
  final String initialPostureStatus;
  final bool initialMonitoringActive;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  static const Duration cameraDetectionInterval = Duration(milliseconds: 500);
  static const Duration deviceScreenTimeRefreshInterval = Duration(minutes: 1);

  late final SettingsStore _settingsRepository;
  final CalibrationRepository _calibrationRepository = CalibrationRepository();
  late final StatisticsRepository _statisticsRepository;
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final CameraFrameStability _cameraFrameStability = CameraFrameStability();
  late final DeviceScreenTimeProvider _deviceScreenTimeProvider;
  final PresentationTicker _presentationTicker = PresentationTicker();
  final GlobalKey _helpTourKey = GlobalKey();
  final GlobalKey _settingsTourKey = GlobalKey();
  final GlobalKey _statusTourKey = GlobalKey();
  final GlobalKey _coinTourKey = GlobalKey();
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
  int? _tourStep;
  int? _preparedTourStep;

  bool get _appIsVisible {
    return WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  bool get _homeIsVisible {
    return _appIsVisible && (ModalRoute.of(context)?.isCurrent ?? true);
  }

  @override
  void initState() {
    super.initState();
    _settingsRepository = widget.settingsStore ?? SettingsRepository();
    _deviceScreenTimeProvider =
        widget.screenTimeProvider ?? const AndroidDeviceScreenTimeProvider();
    _postureStatus = widget.initialPostureStatus;
    // First launch already explained the three posture states on the real
    // localized setup page. Replay starts at step 0 via the Help button.
    if (widget.showTourOnStart) _tourStep = 1;
    WidgetsBinding.instance.addObserver(this);
    _liveTimes = HomeLiveTimes(dateKey: _activeDateKey);
    if (widget.testMode) {
      _initializing = false;
      _monitoringActive = widget.initialMonitoringActive;
      return;
    }
    _statisticsRepository = StatisticsRepository();
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
    if (warning != null) _showMessage(context.l10n.dataLoadWarning);
    if (_calibration == null) {
      _showMessage(context.l10n.postureSetupNeeded);
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
              _showMessage(context.l10n.statisticsUnavailable);
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
          _monitoringError = context.l10n.monitoringStoppedUnexpectedly;
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
      final message = context.l10n.monitoringProblem;
      setState(() => _monitoringError = message);
      _showMessage(message);
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
    final l10n = context.l10n;
    if (_monitoringActive) {
      return const MonitoringControlResult(success: true, isActive: true);
    }
    if (_changingMonitoringState) {
      return MonitoringControlResult(
        success: false,
        isActive: false,
        message: l10n.actionInProgress,
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
        _monitoringError = l10n.monitoringStartFailed;
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
          ? l10n.notificationPermissionOff
          : l10n.monitoringStarted,
    );
  }

  Future<MonitoringControlResult> _stopMonitoring() async {
    if (!_monitoringActive) {
      return const MonitoringControlResult(success: true, isActive: false);
    }
    if (_changingMonitoringState) {
      return MonitoringControlResult(
        success: false,
        isActive: true,
        message: context.l10n.actionInProgress,
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
        _monitoringError = context.l10n.monitoringStopFailed;
      }
    });
    return MonitoringControlResult(
      success: result.success,
      isActive: result.isRunning,
      message: result.success
          ? context.l10n.monitoringStopped
          : context.l10n.monitoringStopFailed,
    );
  }

  Future<bool> _calibrateNeutral() async {
    final l10n = context.l10n;
    double? angle;
    if (_monitoringActive && _hasPhoneAngle) {
      final now = DateTime.now();
      final recent = _recentPhoneAngles
          .where((sample) => now.difference(sample.timestamp).inSeconds <= 5)
          .map((sample) => sample.angle);
      angle = stablePhoneAngle(recent);
      if (angle == null) {
        _showMessage(l10n.calibrationError);
        return false;
      }
    } else if (_monitoringActive) {
      _showMessage(l10n.calibrationError);
      return false;
    } else {
      angle = await _readCalibrationAngle();
    }

    if (angle == null || !isValidSensorPhoneAngle(angle)) {
      _showMessage(l10n.calibrationError);
      return false;
    }
    if (!isValidCalibrationPhoneAngle(angle)) {
      _showMessage(l10n.calibrationError);
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
        _showMessage(l10n.calibrationCloudWarning);
      }
      return result.savedLocally;
    } catch (error) {
      _showMessage(l10n.calibrationSaveFailed);
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
    final guided = _tourStep == 1;
    if (guided) setState(() => _tourStep = null);
    final tourResult = await Navigator.push<SettingsTourResult>(
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
          showGuidedTour: guided,
        ),
      ),
    );

    final result = await _settingsRepository.load();
    if (!mounted) return;
    MonitoringService.updateSettings(result.settings);
    await _refreshPresentationSources();
    if (!mounted || !guided) return;
    setState(() {
      _preparedTourStep = null;
      _tourStep = switch (tourResult) {
        SettingsTourResult.completed => 2,
        SettingsTourResult.skipped => null,
        SettingsTourResult.back || null => 1,
      };
    });
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
      _showMessage(context.l10n.cameraNotGranted);
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
    final l10n = context.l10n;
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
        _markCameraUnavailable(l10n.cameraUnavailable);
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
      _markCameraUnavailable(l10n.cameraUnavailable);
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
          context.l10n.cameraFaceNotFound,
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
        setState(() => _cameraStatusMessage = context.l10n.cameraChecking);
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
      _markCameraUnavailable(context.l10n.cameraUnavailable);
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

  void _startHomeTour() {
    setState(() {
      _tourStep = 0;
      _preparedTourStep = null;
    });
  }

  GlobalKey? _tourKeyForStep(int step) {
    return switch (step) {
      0 => _statusTourKey,
      1 => _settingsTourKey,
      2 => _coinTourKey,
      3 => _helpTourKey,
      _ => null,
    };
  }

  Future<void> _prepareTourTarget() async {
    final step = _tourStep;
    if (step == null || _preparedTourStep == step) return;
    _preparedTourStep = step;
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) setState(() {});
  }

  Rect? _tourTargetRect() {
    final step = _tourStep;
    if (step == null) return null;
    final renderObject = _tourKeyForStep(
      step,
    )?.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  void _moveTour(int delta) {
    final current = _tourStep;
    if (current == null) return;
    final next = current + delta;
    if (next < 0) return;
    if (next > 4) {
      setState(() => _tourStep = null);
      return;
    }
    setState(() {
      _tourStep = next;
      _preparedTourStep = null;
    });
  }

  String _formatTime(int seconds) {
    return localizedDuration(context.l10n, seconds);
  }

  String _localizedPostureStatus() {
    if (!_monitoringActive) return context.l10n.monitoringOff;
    return switch (_postureStatus) {
      'GOOD' => context.l10n.goodPosture,
      'WARNING' => context.l10n.warningPosture,
      _ => context.l10n.badPostureStatus,
    };
  }

  String _localizedPostureHint() {
    if (!_monitoringActive) return '';
    return switch (_postureStatus) {
      'GOOD' => context.l10n.goodPostureHint,
      'WARNING' => context.l10n.warningPostureHint,
      _ => context.l10n.badPostureHint,
    };
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

    final l10n = context.l10n;
    if (_tourStep != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prepareTourTarget());
    }
    final tourContent = switch (_tourStep) {
      0 => (l10n.guidePostureTitle, l10n.guidePostureBody),
      1 => (l10n.guideSettingsTitle, l10n.guideSettingsBody),
      2 => (l10n.guideCoinsTitle, l10n.guideCoinsBody),
      3 => (l10n.guideHelpTitle, l10n.guideHelpBody),
      _ => (l10n.guideFinishTitle, l10n.guideFinishBody),
    };

    final home = Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          key: const Key('homeLayout'),
          builder: (context, constraints) {
            final horizontalPadding = constraints.responsiveHorizontalPadding;
            final isShort = constraints.isShortPhone;
            const controlHeight = 48.0;
            final actionHeight = isShort ? 64.0 : 68.0;
            final sectionGap = isShort ? 6.0 : 10.0;
            final metricIconSize = constraints.isVerySmallPhone ? 24.0 : 26.0;
            final metricLabelSize = constraints.isVerySmallPhone ? 12.0 : 13.0;
            final metricValueSize = isShort ? 22.0 : 24.0;

            Widget timeMetric({
              required IconData icon,
              required String label,
              required String value,
            }) {
              return Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: metricIconSize),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: metricLabelSize,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            value,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: metricValueSize,
                              height: 1.05,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                children: [
                  Padding(
                    key: const Key('homeTopControls'),
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        ConstrainedBox(
                          key: _coinTourKey,
                          constraints: const BoxConstraints(maxWidth: 104),
                          child: SizedBox(
                            height: controlHeight,
                            child: FloatingActionButton.extended(
                              key: const Key('homeCoinBalance'),
                              heroTag: 'homeCoinsButton',
                              onPressed: null,
                              icon: const Icon(Icons.monetization_on_rounded),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('$_totalCoins'),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          key: _helpTourKey,
                          width: controlHeight,
                          height: controlHeight,
                          child: FloatingActionButton(
                            key: const Key('homeHelpButton'),
                            heroTag: 'homeHelpButton',
                            tooltip: l10n.helpTooltip,
                            onPressed: () {
                              if (_tourStep == 3) {
                                _moveTour(1);
                              } else {
                                _startHomeTour();
                              }
                            },
                            child: const Icon(Icons.question_mark),
                          ),
                        ),
                        SizedBox(width: constraints.isVerySmallPhone ? 6 : 10),
                        SizedBox(
                          key: _settingsTourKey,
                          width: controlHeight,
                          height: controlHeight,
                          child: FloatingActionButton(
                            key: const Key('homeSettingsButton'),
                            heroTag: 'homeSettingsButton',
                            tooltip: l10n.settings,
                            onPressed: _openSettings,
                            child: const Icon(Icons.settings),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  Expanded(
                    key: const Key('homeMiddleContent'),
                    child: LayoutBuilder(
                      builder: (context, middleConstraints) {
                        const characterAspectRatio = 765 / 611;
                        final textScale = MediaQuery.textScalerOf(
                          context,
                        ).scale(1);
                        final statusFontSize = switch (constraints.maxHeight) {
                          < 620 => 32.0,
                          < 760 => 36.0,
                          _ => 40.0,
                        };
                        final scoreFontSize = isShort ? 20.0 : 22.0;
                        final helperFontSize = isShort ? 13.0 : 15.0;
                        final hint = _localizedPostureHint();
                        final statusLines = _monitoringActive ? 1.0 : 2.0;
                        final statusBudget =
                            17 * textScale +
                            3 +
                            statusFontSize * 1.05 * statusLines * textScale +
                            5 +
                            scoreFontSize * 1.15 * textScale +
                            (hint.isEmpty
                                ? 0
                                : 4 + helperFontSize * 2.2 * textScale);
                        final metricsBudget = max(58.0, 54 * textScale);
                        final cameraBudget = _cameraStatusMessage == null
                            ? 0.0
                            : 34 * textScale;
                        final imageGap = isShort ? 6.0 : 16.0;
                        final metricsGap = isShort ? 6.0 : 12.0;
                        final accessibilityReserve = max(
                          0.0,
                          min(48.0, (textScale - 1) * 112),
                        );
                        final characterRoom = max(
                          0.0,
                          middleConstraints.maxHeight -
                              statusBudget -
                              metricsBudget -
                              cameraBudget -
                              imageGap -
                              metricsGap -
                              accessibilityReserve,
                        );
                        final characterHeight = min(
                          min(
                            constraints.maxHeight * (isShort ? 0.36 : 0.42),
                            constraints.maxWidth / characterAspectRatio,
                          ),
                          min(330.0, characterRoom),
                        );

                        return Align(
                          alignment: isShort
                              ? Alignment.topCenter
                              : const Alignment(0, -0.4),
                          child: Column(
                            key: const Key('homeCompactContent'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              KeyedSubtree(
                                key: _statusTourKey,
                                child: Column(
                                  key: const Key('homeStatusSection'),
                                  children: [
                                    Text(
                                      l10n.status.toUpperCase(),
                                      key: const Key('homeStatusHeading'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 360,
                                      ),
                                      child: Text(
                                        _localizedPostureStatus(),
                                        key: const Key('homePostureStatus'),
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: statusFontSize,
                                          height: 1.05,
                                          fontWeight: FontWeight.bold,
                                          color: _statusColor(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      l10n.score(_stats.dailyScore.round()),
                                      key: const Key('homeScore'),
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: scoreFontSize,
                                        height: 1.05,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (hint.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          hint,
                                          key: const Key('homePostureHint'),
                                          maxLines: 2,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: helperFontSize,
                                            height: 1.1,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (_cameraStatusMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    _cameraStatusMessage!,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              SizedBox(height: imageGap),
                              SizedBox(
                                height: max(0, characterHeight),
                                child: OverflowBox(
                                  maxWidth: constraints.maxWidth,
                                  child: SizedBox(
                                    key: const Key('homeCharacterArtwork'),
                                    width:
                                        max(0, characterHeight) *
                                        characterAspectRatio,
                                    height: max(0, characterHeight),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: _statusColor().withValues(
                                          alpha: 0.08,
                                        ),
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                      child: Image.asset(
                                        'images/happy slime.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: metricsGap),
                              Row(
                                key: const Key('homeTimeMetrics'),
                                children: [
                                  timeMetric(
                                    icon: Icons.access_time_filled,
                                    label: _showDeviceScreenTime
                                        ? l10n.deviceScreenTime
                                        : l10n.monitoredTime,
                                    value: _formatTime(
                                      _showDeviceScreenTime
                                          ? _liveTimes.deviceScreenTimeSeconds!
                                          : _liveTimes.monitoredSeconds,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  timeMetric(
                                    icon: Icons.sentiment_dissatisfied_sharp,
                                    label: l10n.badPosture,
                                    value: _formatTime(
                                      _liveTimes.badPostureSeconds,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    key: const Key('homeBottomActions'),
                    padding: EdgeInsets.only(bottom: isShort ? 4 : 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: SizedBox(
                            height: actionHeight,
                            child: FloatingActionButton(
                              key: const Key('homeCustomizeButton'),
                              heroTag: 'homeCustomizeButton',
                              onPressed: () async {
                                await Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const Customizes(),
                                  ),
                                );
                                if (mounted) {
                                  await _refreshPresentationSources();
                                }
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  l10n.customize.toUpperCase(),
                                  style: const TextStyle(fontSize: 19),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: actionHeight,
                            child: FloatingActionButton(
                              key: const Key('homeStatisticsButton'),
                              heroTag: 'homeStatisticsButton',
                              tooltip: l10n.statistics,
                              onPressed: () async {
                                await Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => Statistics(
                                      screenTimeProvider:
                                          _deviceScreenTimeProvider,
                                    ),
                                  ),
                                );
                                if (mounted) {
                                  await _refreshPresentationSources();
                                }
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: const Icon(Icons.equalizer),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    final step = _tourStep;
    if (step == null) return home;
    return Stack(
      children: [
        home,
        Positioned.fill(
          child: CoachMarkOverlay(
            target: _tourTargetRect(),
            title: tourContent.$1,
            body: tourContent.$2,
            content: step == 0
                ? _PostureTourLegend(
                    good: l10n.goodPostureExplanation,
                    warning: l10n.warningPostureExplanation,
                    bad: l10n.badPostureExplanation,
                  )
                : null,
            currentStep: step,
            totalSteps: 5,
            backLabel: l10n.back,
            nextLabel: step == 4 ? l10n.done : l10n.next,
            skipLabel: l10n.skipForNow,
            onBack: step == 0 ? null : () => _moveTour(-1),
            onNext: step == 1 ? null : () => _moveTour(1),
            onSkip: () => setState(() => _tourStep = null),
            nextButtonKey: const Key('homeTourNextButton'),
            backButtonKey: const Key('homeTourBackButton'),
            skipButtonKey: const Key('homeTourSkipButton'),
          ),
        ),
      ],
    );
  }
}

class _PostureTourLegend extends StatelessWidget {
  const _PostureTourLegend({
    required this.good,
    required this.warning,
    required this.bad,
  });

  final String good;
  final String warning;
  final String bad;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PostureLegendRow(color: Colors.green, text: good),
        const SizedBox(height: 8),
        _PostureLegendRow(color: Colors.orange, text: warning),
        const SizedBox(height: 8),
        _PostureLegendRow(color: Colors.red, text: bad),
      ],
    );
  }
}

class _PostureLegendRow extends StatelessWidget {
  const _PostureLegendRow({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.circle, size: 14, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}
