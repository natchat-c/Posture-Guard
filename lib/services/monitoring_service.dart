import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
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
import 'notification_service.dart';
import 'preferences_service.dart';
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

  static bool get isSupported => Platform.isAndroid;

  static void initialize() {
    if (_initialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'posture_guard_monitoring',
        channelName: 'Posture Guard monitoring',
        channelDescription:
            'Permanent notification shown while phone-angle monitoring is active.',
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

  static Future<MonitoringActionResult> start() async {
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

    NotificationPermission permission;
    try {
      permission = await requestNotificationPermissionIfAppropriate();
    } catch (_) {
      permission = NotificationPermission.denied;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: PostureNotificationService.foregroundServiceNotificationId,
      serviceTypes: const [ForegroundServiceTypes.specialUse],
      notificationTitle: 'Posture Guard is active',
      notificationText: 'Monitoring your phone angle',
      notificationButtons: const [
        NotificationButton(id: 'stop_monitoring', text: 'Stop'),
      ],
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

  static Future<MonitoringActionResult> stop() async {
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
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final PhoneAngleFilter _phoneAngleFilter = PhoneAngleFilter();
  final PostureHysteresis _hysteresis = PostureHysteresis();
  final PhoneMovementDetector _movementDetector = PhoneMovementDetector();
  final PostureAlertScheduler _alertScheduler = PostureAlertScheduler();
  final Map<String, _MutableStatsDelta> _pendingStats = {};

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
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
  double _smoothedPhoneAngle = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    DartPluginRegistrant.ensureInitialized();

    _settings =
        await SettingsRepository.loadCachedSettings(_preferences) ??
        AppSettings.defaults;
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
      _sendError('Calibration is missing. Open Posture Guard and calibrate.');
      unawaited(FlutterForegroundTask.stopService());
      return;
    }

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

    _lastTick = timestamp;
    _sendState();
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    final gravity = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    if (gravity == 0) return;

    final ratio = (event.z.abs() / gravity).clamp(0.0, 1.0);
    final rawAngle = asin(ratio) * 180 / pi;
    _smoothedPhoneAngle = _phoneAngleFilter.add(rawAngle);

    final wasMoving = _isMoving;
    _isMoving = _movementDetector.add(rawAngle);
    if (_isMoving && !wasMoving) {
      _pendingForToday().movementPaused++;
    }

    _evaluatePosture();
  }

  void _evaluatePosture() {
    final calibration = _calibration;
    if (calibration == null) return;

    String nextStatus;
    if (_isMoving) {
      _badPostureStart = null;
      nextStatus = 'WARNING';
    } else {
      final effectiveAngle = calibratedPhoneAngle(
        _smoothedPhoneAngle,
        calibration.neutralPhoneAngle,
      );
      final phoneAngleIsBad = _hysteresis.update(effectiveAngle);
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
    if (!_settings.alertsEnabled || _postureStatus != 'BAD') return;

    final now = DateTime.now();
    if (!_alertScheduler.isDue(
      now: now,
      postureIsBad: _postureStatus == 'BAD',
      alertsEnabled: _settings.alertsEnabled,
      frequencySeconds: _settings.alertFrequencySeconds,
    )) {
      return;
    }

    try {
      await PostureNotificationService.showPostureAlert();
      _alertScheduler.markAlertSent(now);
      _pendingForToday().alertsSent++;
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
    _evaluatePosture();

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
        _calibration = Calibration(neutralPhoneAngle: angle);
        _badPostureStart = null;
        _setPostureStatus('GOOD');
      }
      return;
    }

    if (command == 'camera') {
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

    if (command == 'state') _sendState();
  }

  Future<void> _prepareToStop() async {
    await PostureNotificationService.cancelPostureAlert();
    await _savePendingStats();
    await _flushPendingStats();
  }

  void _sendState() {
    FlutterForegroundTask.sendDataToMain({
      'type': 'monitoringState',
      'active': true,
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
  void onNotificationButtonPressed(String id) {
    if (id == 'stop_monitoring') {
      unawaited(FlutterForegroundTask.stopService());
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
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
