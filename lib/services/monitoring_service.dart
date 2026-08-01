import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../functions/posture_check.dart';
import '../models/app_settings.dart';
import '../models/calibration.dart';
import '../models/posture_thresholds.dart';
import 'notification_service.dart';
import 'preferences_service.dart';
import 'alert_mute_service.dart';
import 'screen_state_service.dart';
import 'statistics_repository.dart';

const String _pendingStatsKey = 'pendingMonitoringStats';

@pragma('vm:entry-point')
void startPostureMonitoringCallback() {
  FlutterForegroundTask.setTaskHandler(PostureMonitoringTaskHandler());
}

class MonitoringActionResult {
  const MonitoringActionResult({
    required this.success,
    required this.isRunning,
    this.error,
    this.notificationPermission,
  });

  final bool success;
  final bool isRunning;
  final Object? error;
  final NotificationPermission? notificationPermission;
}

class MonitoringService {
  MonitoringService._();

  static bool _initialized = false;
  static Future<MonitoringActionResult>? _startInFlight;
  static Future<MonitoringActionResult>? _stopInFlight;

  static bool get isSupported => Platform.isAndroid;

  static void initialize() {
    if (_initialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'posture_guard_monitoring',
        channelName: 'Posture Guard',
        channelDescription: 'Posture Guard reminders and status',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        showWhen: true,
        showBadge: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
    _initialized = true;
  }

  static Future<bool> isRunning() async {
    if (!isSupported) return false;
    try {
      return await FlutterForegroundTask.isRunningService;
    } catch (_) {
      return false;
    }
  }

  static Future<NotificationPermission> notificationPermission() async {
    if (!isSupported) return NotificationPermission.denied;
    return FlutterForegroundTask.checkNotificationPermission();
  }

  static Future<NotificationPermission>
  requestNotificationPermissionIfAppropriate() async {
    if (!isSupported) return NotificationPermission.denied;

    final current = await notificationPermission();
    if (current == NotificationPermission.granted ||
        current == NotificationPermission.permanently_denied) {
      return current;
    }

    final preferences = SharedPreferencesAsync();
    final alreadyRequested =
        await preferences.getBool(
          PreferenceKeys.notificationPermissionRequested,
        ) ??
        false;
    if (alreadyRequested) return current;

    await preferences.setBool(
      PreferenceKeys.notificationPermissionRequested,
      true,
    );
    return FlutterForegroundTask.requestNotificationPermission();
  }

  static Future<MonitoringActionResult> start() {
    final existing = _startInFlight;
    if (existing != null) return existing;

    late final Future<MonitoringActionResult> operation;
    operation = _start().whenComplete(() {
      if (identical(_startInFlight, operation)) _startInFlight = null;
    });
    _startInFlight = operation;
    return operation;
  }

  static Future<MonitoringActionResult> _start() async {
    final stopOperation = _stopInFlight;
    if (stopOperation != null) await stopOperation;

    if (!isSupported) {
      return const MonitoringActionResult(
        success: false,
        isRunning: false,
        error: 'Background monitoring is currently available on Android.',
      );
    }

    initialize();
    if (await isRunning()) {
      requestState();
      return MonitoringActionResult(
        success: true,
        isRunning: true,
        notificationPermission: await notificationPermission(),
      );
    }

    final permission = await notificationPermission();
    final notificationText = await PostureNotificationService.foregroundText(
      screenInteractive: true,
    );

    final result = await FlutterForegroundTask.startService(
      serviceId: PostureNotificationService.foregroundServiceNotificationId,
      serviceTypes: const [ForegroundServiceTypes.specialUse],
      notificationTitle: notificationText.title,
      notificationText: notificationText.body,
      callback: startPostureMonitoringCallback,
    );

    if (result is ServiceRequestFailure) {
      return MonitoringActionResult(
        success: false,
        isRunning: false,
        error: result.error,
        notificationPermission: permission,
      );
    }

    return MonitoringActionResult(
      success: true,
      isRunning: true,
      notificationPermission: permission,
    );
  }

  static Future<MonitoringActionResult> stop() {
    final existing = _stopInFlight;
    if (existing != null) return existing;

    late final Future<MonitoringActionResult> operation;
    operation = _stop().whenComplete(() {
      if (identical(_stopInFlight, operation)) _stopInFlight = null;
    });
    _stopInFlight = operation;
    return operation;
  }

  static Future<MonitoringActionResult> _stop() async {
    final startOperation = _startInFlight;
    if (startOperation != null) await startOperation;

    if (!isSupported || !await isRunning()) {
      await PostureNotificationService.cancelPostureAlert();
      return const MonitoringActionResult(success: true, isRunning: false);
    }

    FlutterForegroundTask.sendDataToTask(const {'command': 'prepareStop'});
    final result = await FlutterForegroundTask.stopService();
    await PostureNotificationService.cancelPostureAlert();

    if (result is ServiceRequestFailure) {
      return MonitoringActionResult(
        success: false,
        isRunning: await isRunning(),
        error: result.error,
      );
    }
    return const MonitoringActionResult(success: true, isRunning: false);
  }

  static void updateSettings(AppSettings settings) {
    if (!isSupported) return;
    FlutterForegroundTask.sendDataToTask({
      'command': 'settings',
      ...settings.toMap(),
    });
  }

  static void updateCalibration(Calibration calibration) {
    if (!isSupported) return;
    FlutterForegroundTask.sendDataToTask({
      'command': 'calibration',
      'neutralPhoneAngle': calibration.neutralPhoneAngle,
    });
  }

  static void updateCameraSupplement({
    required bool available,
    bool suggestsGoodPosture = false,
  }) {
    if (!isSupported) return;
    FlutterForegroundTask.sendDataToTask({
      'command': 'camera',
      'available': available,
      'suggestsGoodPosture': suggestsGoodPosture,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static void reportCameraUnavailable() {
    if (!isSupported) return;
    FlutterForegroundTask.sendDataToTask(const {
      'command': 'cameraUnavailable',
    });
  }

  static void requestState() {
    if (!isSupported) return;
    FlutterForegroundTask.sendDataToTask(const {'command': 'state'});
  }

  static void alertMuteChanged() {
    if (!isSupported) return;
    FlutterForegroundTask.sendDataToTask(const {'command': 'alertMuteChanged'});
  }

  static void updateLanguage(String languageCode) {
    if (!isSupported) return;
    FlutterForegroundTask.sendDataToTask({
      'command': 'language',
      'languageCode': languageCode,
    });
  }
}

class _MutableStatsDelta {
  _MutableStatsDelta();

  int screenSeconds = 0;
  int badSeconds = 0;
  int badDetections = 0;
  int goodDetections = 0;
  int alertsSent = 0;
  int cameraUnavailable = 0;
  int movementPaused = 0;

  bool get isEmpty {
    return screenSeconds == 0 &&
        badSeconds == 0 &&
        badDetections == 0 &&
        goodDetections == 0 &&
        alertsSent == 0 &&
        cameraUnavailable == 0 &&
        movementPaused == 0;
  }

  StatsDelta toDelta() {
    return StatsDelta(
      screenSeconds: screenSeconds,
      badSeconds: badSeconds,
      badDetections: badDetections,
      goodDetections: goodDetections,
      alertsSent: alertsSent,
      cameraUnavailable: cameraUnavailable,
      movementPaused: movementPaused,
    );
  }

  Map<String, int> toMap() {
    return {
      'screenSeconds': screenSeconds,
      'badSeconds': badSeconds,
      'badDetections': badDetections,
      'goodDetections': goodDetections,
      'alertsSent': alertsSent,
      'cameraUnavailable': cameraUnavailable,
      'movementPaused': movementPaused,
    };
  }

  factory _MutableStatsDelta.fromMap(Map<dynamic, dynamic> map) {
    return _MutableStatsDelta()
      ..screenSeconds = (map['screenSeconds'] as num?)?.toInt() ?? 0
      ..badSeconds = (map['badSeconds'] as num?)?.toInt() ?? 0
      ..badDetections = (map['badDetections'] as num?)?.toInt() ?? 0
      ..goodDetections = (map['goodDetections'] as num?)?.toInt() ?? 0
      ..alertsSent = (map['alertsSent'] as num?)?.toInt() ?? 0
      ..cameraUnavailable = (map['cameraUnavailable'] as num?)?.toInt() ?? 0
      ..movementPaused = (map['movementPaused'] as num?)?.toInt() ?? 0;
  }
}

class PostureMonitoringTaskHandler extends TaskHandler {
  PostureMonitoringTaskHandler({
    ScreenStateProvider? screenStateProvider,
    AlertMuteController? alertMuteController,
  }) : _screenStateProvider =
           screenStateProvider ?? const AndroidScreenStateProvider(),
       _alertMuteController = alertMuteController ?? AlertMuteController();

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final ScreenStateProvider _screenStateProvider;
  final AlertMuteController _alertMuteController;
  final PhoneAngleFilter _phoneAngleFilter = PhoneAngleFilter();
  final PostureHysteresis _hysteresis = PostureHysteresis();
  final PhoneMovementDetector _movementDetector = PhoneMovementDetector();
  final PostureAlertScheduler _alertScheduler = PostureAlertScheduler();
  final Map<String, _MutableStatsDelta> _pendingStats = {};

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<bool>? _screenStateSubscription;
  StatisticsRepository? _statisticsRepository;
  AppSettings _settings = AppSettings.defaults;
  Calibration? _calibration;

  String _postureStatus = 'GOOD';
  String? _previousCountedStatus;
  DateTime? _badPostureStart;
  DateTime? _lastTick;
  DateTime? _lastStatsFlush;
  DateTime? _cameraSignalAt;
  bool _cameraAvailable = false;
  bool _cameraSuggestsGoodPosture = false;
  bool _isMoving = false;
  bool _tickInProgress = false;
  Future<void> _screenTransition = Future<void>.value();
  bool _screenInteractive = true;
  bool _alertsMuted = false;
  bool _hasSensorReading = false;
  int _alertEventSequence = 0;
  double _smoothedPhoneAngle = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    DartPluginRegistrant.ensureInitialized();

    _settings =
        await SettingsRepository.loadCachedSettings(_preferences) ??
        AppSettings.defaults;
    if (!_settings.monitoringEnabled) {
      unawaited(FlutterForegroundTask.stopService());
      return;
    }
    _calibration = await CalibrationRepository.loadCachedCalibration(
      _preferences,
    );
    await _loadPendingStats();

    try {
      await PostureNotificationService.initialize();
    } catch (error) {
      _sendError('Posture alert notifications could not be initialized.');
      debugPrint('Notification initialization failed in service: $error');
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _statisticsRepository = StatisticsRepository();
    } catch (error) {
      _sendError(
        'Firebase is unavailable. Monitoring will continue and statistics will retry later.',
      );
      debugPrint('Firebase initialization failed in service: $error');
    }

    if (_calibration == null) {
      _calibration = const Calibration(
        neutralPhoneAngle: maximumSensorAngleDegrees,
      );
      _sendError(
        'Monitoring is using the standard phone-angle baseline. '
        'Calibrate in Settings for personalized posture detection.',
      );
    }

    _screenInteractive = await _screenStateProvider.isInteractive();
    _screenStateSubscription = _screenStateProvider.changes.listen(
      (interactive) {
        _screenTransition = _screenTransition
            .then((_) => _setScreenInteractive(interactive))
            .catchError((Object error, StackTrace stackTrace) {
              debugPrint('Could not apply screen-state transition: $error');
            });
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Screen-state listener failed: $error');
      },
    );
    _alertsMuted = await _alertMuteController.isMuted;
    if (_screenInteractive) {
      await _startSensorTracking();
    } else {
      await _updateForegroundNotification();
    }

    _lastTick = timestamp;
    _sendState();
  }

  Future<void> _startSensorTracking() async {
    if (_accelerometerSubscription != null ||
        !_settings.monitoringEnabled ||
        !_screenInteractive) {
      return;
    }
    _hasSensorReading = false;
    try {
      _accelerometerSubscription = accelerometerEventStream().listen(
        _onAccelerometerEvent,
        onError: (Object error, StackTrace stackTrace) {
          _sendError(
            'The phone orientation sensor is unavailable. Stop monitoring and try again.',
          );
          debugPrint('Accelerometer service error: $error');
        },
        cancelOnError: false,
      );
    } catch (error) {
      _sendError(
        'The phone orientation sensor is unavailable. Stop monitoring and try again.',
      );
      debugPrint('Could not start accelerometer service: $error');
    }
  }

  Future<void> _stopSensorTracking() async {
    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _hasSensorReading = false;
  }

  Future<void> _setScreenInteractive(bool interactive) async {
    if (_screenInteractive == interactive) return;
    _screenInteractive = interactive;
    _lastTick = DateTime.now();
    await _resetPostureEpisode();
    if (interactive && _settings.monitoringEnabled) {
      await _startSensorTracking();
    } else {
      await _stopSensorTracking();
      _cameraAvailable = false;
      _cameraSuggestsGoodPosture = false;
    }
    await _updateForegroundNotification();
    _sendState();
  }

  Future<void> _resetPostureEpisode() async {
    _badPostureStart = null;
    _alertScheduler.reset();
    _postureStatus = 'GOOD';
    _previousCountedStatus = null;
    _isMoving = false;
    _phoneAngleFilter.reset();
    _hasSensorReading = false;
    _hysteresis.reset();
    _movementDetector.reset();
    await PostureNotificationService.cancelPostureAlert();
  }

  Future<void> _updateForegroundNotification() async {
    final notificationText = await PostureNotificationService.foregroundText(
      screenInteractive: _screenInteractive,
    );
    await FlutterForegroundTask.updateService(
      notificationTitle: notificationText.title,
      notificationText: notificationText.body,
    );
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    final rawAngle = phoneAngleFromAccelerometer(
      x: event.x,
      y: event.y,
      z: event.z,
    );
    if (rawAngle == null) return;
    final smoothedAngle = _phoneAngleFilter.add(rawAngle);
    if (smoothedAngle == null) return;
    _smoothedPhoneAngle = smoothedAngle;
    _hasSensorReading = true;

    final wasMoving = _isMoving;
    _isMoving = _movementDetector.add(rawAngle);
    if (_isMoving && !wasMoving) {
      _pendingForToday().movementPaused++;
    }

    _evaluatePosture();
  }

  void _evaluatePosture() {
    if (!_screenInteractive || !_hasSensorReading) return;
    final calibration = _calibration;
    if (calibration == null) return;

    String nextStatus;
    if (_isMoving) {
      _badPostureStart = null;
      nextStatus = 'WARNING';
    } else {
      final thresholds = calculatePostureThresholds(
        calibration.neutralPhoneAngle,
      );
      final phoneAngleIsBad = _hysteresis.update(
        _smoothedPhoneAngle,
        thresholds,
      );
      final cameraSignalIsFresh =
          _cameraAvailable &&
          _cameraSignalAt != null &&
          DateTime.now().difference(_cameraSignalAt!).inSeconds <= 3;

      if (!phoneAngleIsBad ||
          (cameraSignalIsFresh && _cameraSuggestsGoodPosture)) {
        _badPostureStart = null;
        nextStatus = 'GOOD';
      } else {
        _badPostureStart ??= DateTime.now();
        final badSeconds = DateTime.now()
            .difference(_badPostureStart!)
            .inSeconds;
        nextStatus = badSeconds >= _settings.alertDelaySeconds
            ? 'BAD'
            : 'WARNING';
      }
    }

    _setPostureStatus(nextStatus);
  }

  void _setPostureStatus(String status) {
    if (_postureStatus == status) {
      if (status == 'BAD') unawaited(_maybeAlert());
      return;
    }

    _postureStatus = status;
    if (_previousCountedStatus != status) {
      if (status == 'BAD') _pendingForToday().badDetections++;
      if (status == 'GOOD') _pendingForToday().goodDetections++;
      _previousCountedStatus = status;
    }

    if (status == 'GOOD') {
      _alertScheduler.reset();
      unawaited(PostureNotificationService.cancelPostureAlert());
    } else if (status == 'BAD') {
      unawaited(_maybeAlert());
    }
    _sendState();
  }

  Future<void> _maybeAlert() async {
    if (!_settings.alertsEnabled ||
        !_screenInteractive ||
        _alertsMuted ||
        _postureStatus != 'BAD') {
      return;
    }

    final now = DateTime.now();
    if (!_alertScheduler.isDue(
      now: now,
      postureIsBad: _postureStatus == 'BAD',
      alertsEnabled: _settings.alertsEnabled,
      frequencySeconds: _settings.alertFrequencySeconds,
      screenInteractive: _screenInteractive,
      temporarilyMuted: _alertsMuted,
    )) {
      return;
    }

    try {
      await PostureNotificationService.showPostureAlert();
      _alertScheduler.markAlertSent(now);
      _pendingForToday().alertsSent++;
      _alertEventSequence++;
      _sendState();
    } catch (error) {
      _sendError(
        'Posture was detected, but the alert notification could not be shown.',
      );
      debugPrint('Could not show posture alert: $error');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_tickInProgress) return;
    _tickInProgress = true;
    unawaited(
      _tick(timestamp).whenComplete(() {
        _tickInProgress = false;
      }),
    );
  }

  Future<void> _tick(DateTime timestamp) async {
    await _refreshMuteState();
    if (!_screenInteractive) {
      _lastTick = timestamp;
      _sendState();
      return;
    }
    _evaluatePosture();
    if (!_hasSensorReading) {
      _lastTick = timestamp;
      _sendState();
      return;
    }

    final previousTick = _lastTick;
    _lastTick = timestamp;
    final elapsed = previousTick == null
        ? 1
        : timestamp.difference(previousTick).inSeconds.clamp(1, 5);
    final delta = _pendingForToday();
    delta.screenSeconds += elapsed;
    if (_postureStatus == 'BAD') delta.badSeconds += elapsed;

    final shouldFlush =
        _lastStatsFlush == null ||
        timestamp.difference(_lastStatsFlush!).inSeconds >= 5;
    if (shouldFlush) {
      _lastStatsFlush = timestamp;
      await _savePendingStats();
      await _flushPendingStats();
    }
    _sendState();
  }

  Future<void> _refreshMuteState() async {
    final muted = await _alertMuteController.isMuted;
    if (muted == _alertsMuted) return;
    _alertsMuted = muted;
    await _resetPostureEpisode();
    _sendState();
  }

  _MutableStatsDelta _pendingForToday() {
    return _pendingStats.putIfAbsent(
      postureDateKey(),
      () => _MutableStatsDelta(),
    );
  }

  Future<void> _flushPendingStats() async {
    var repository = _statisticsRepository;
    if (repository == null) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
        repository = StatisticsRepository();
        _statisticsRepository = repository;
      } catch (_) {
        return;
      }
    }

    for (final entry in _pendingStats.entries.toList()) {
      if (entry.value.isEmpty) {
        _pendingStats.remove(entry.key);
        continue;
      }

      try {
        await repository.addDelta(entry.key, entry.value.toDelta());
        _pendingStats.remove(entry.key);
        await _savePendingStats();
      } catch (error) {
        debugPrint('Background statistics sync failed: $error');
        break;
      }
    }
  }

  Future<void> _loadPendingStats() async {
    final encoded = await _preferences.getString(_pendingStatsKey);
    if (encoded == null || encoded.isEmpty) return;

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        if (entry.value is Map) {
          _pendingStats[entry.key.toString()] = _MutableStatsDelta.fromMap(
            entry.value as Map,
          );
        }
      }
    } catch (error) {
      debugPrint('Could not restore pending monitoring statistics: $error');
    }
  }

  Future<void> _savePendingStats() async {
    final data = <String, Object>{};
    for (final entry in _pendingStats.entries) {
      if (!entry.value.isEmpty) data[entry.key] = entry.value.toMap();
    }
    await _preferences.setString(_pendingStatsKey, jsonEncode(data));
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;
    final command = data['command'];

    if (command == 'settings') {
      _settings = AppSettings.fromMap(data, fallback: _settings);
      if (!_settings.alertsEnabled) {
        _alertScheduler.reset();
        unawaited(PostureNotificationService.cancelPostureAlert());
      }
      _evaluatePosture();
      return;
    }

    if (command == 'calibration') {
      final angle = (data['neutralPhoneAngle'] as num?)?.toDouble();
      if (angle != null && Calibration.isValidPhoneAngle(angle)) {
        unawaited(_applyCalibration(Calibration(neutralPhoneAngle: angle)));
      }
      return;
    }

    if (command == 'camera') {
      if (!_screenInteractive) return;
      _cameraAvailable = data['available'] == true;
      _cameraSuggestsGoodPosture = data['suggestsGoodPosture'] == true;
      final milliseconds = (data['timestamp'] as num?)?.toInt();
      _cameraSignalAt = milliseconds == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(milliseconds);
      _evaluatePosture();
      return;
    }

    if (command == 'cameraUnavailable') {
      _pendingForToday().cameraUnavailable++;
      _cameraAvailable = false;
      return;
    }

    if (command == 'prepareStop') {
      unawaited(_prepareToStop());
      return;
    }

    if (command == 'alertMuteChanged') {
      unawaited(_reloadMuteAndResetEpisode());
      return;
    }

    if (command == 'language') {
      unawaited(_updateForegroundNotification());
      return;
    }

    if (command == 'state') _sendState();
  }

  Future<void> _prepareToStop() async {
    await PostureNotificationService.cancelPostureAlert();
    await _savePendingStats();
    await _flushPendingStats();
  }

  Future<void> _applyCalibration(Calibration calibration) async {
    _calibration = calibration;
    await _resetPostureEpisode();
    _sendState();
  }

  Future<void> _reloadMuteAndResetEpisode() async {
    _alertsMuted = await _alertMuteController.isMuted;
    await _resetPostureEpisode();
    _sendState();
  }

  void _sendState() {
    FlutterForegroundTask.sendDataToMain({
      'type': 'monitoringState',
      'active': true,
      'screenInteractive': _screenInteractive,
      'alertsMuted': _alertsMuted,
      'alertEventSequence': _alertEventSequence,
      'hasSensorReading': _hasSensorReading,
      'postureStatus': _postureStatus,
      'phoneAngle': _smoothedPhoneAngle,
      'badPostureSeconds': _badPostureStart == null
          ? 0
          : DateTime.now().difference(_badPostureStart!).inSeconds,
    });
  }

  void _sendError(String message) {
    FlutterForegroundTask.sendDataToMain({
      'type': 'monitoringError',
      'message': message,
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _screenStateSubscription?.cancel();
    _screenStateSubscription = null;
    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    await PostureNotificationService.cancelPostureAlert();
    await _savePendingStats();
    await _flushPendingStats();
    FlutterForegroundTask.sendDataToMain({
      'type': 'monitoringState',
      'active': false,
      'postureStatus': 'GOOD',
    });
  }
}
