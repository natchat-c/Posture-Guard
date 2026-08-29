import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../functions/posture_check.dart';
import '../models/app_settings.dart';
import '../models/calibration.dart';
import '../models/posture_thresholds.dart';
import 'alert_mute_service.dart';
import 'notification_service.dart';
import 'preferences_service.dart';
import 'statistics_repository.dart';

class MotionSensorSample {
  const MotionSensorSample({required this.x, required this.y, required this.z});

  final double x;
  final double y;
  final double z;
}

abstract interface class MotionSensorSource {
  Stream<MotionSensorSample> samples();
}

class SensorsPlusMotionSensorSource implements MotionSensorSource {
  const SensorsPlusMotionSensorSource();

  @override
  Stream<MotionSensorSample> samples() {
    return accelerometerEventStream().map(
      (event) => MotionSensorSample(x: event.x, y: event.y, z: event.z),
    );
  }
}

typedef ForegroundMonitoringDataCallback = void Function(Object data);
typedef ForegroundSettingsLoader = Future<AppSettings> Function();
typedef ForegroundCalibrationLoader = Future<Calibration?> Function();
typedef ForegroundStatsWriter =
    Future<void> Function(String dateKey, StatsDelta delta);

class _ForegroundStatsDelta {
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
}

/// Runs the shared posture model in the Flutter process while iOS is visible.
///
/// This deliberately does not register a background task. Losing foreground
/// lifecycle state cancels the sensor subscription, resets the active posture
/// episode, and flushes the locally accumulated statistics.
class IosForegroundMonitoringController {
  IosForegroundMonitoringController({
    MotionSensorSource? sensorSource,
    ForegroundSettingsLoader? loadSettings,
    ForegroundCalibrationLoader? loadCalibration,
    Future<bool> Function()? loadAlertsMuted,
    Future<void> Function()? initializeNotifications,
    Future<void> Function()? showPostureAlert,
    Future<void> Function()? cancelPostureAlert,
    ForegroundStatsWriter? writeStats,
    Future<void> Function()? synchronizeStats,
    DateTime Function()? now,
    bool Function()? isAppForeground,
    this.sensorAvailabilityTimeout = const Duration(seconds: 3),
    this.monitoringTickInterval = const Duration(seconds: 1),
    this.statisticsFlushInterval = const Duration(seconds: 5),
  }) : _sensorSource = sensorSource ?? const SensorsPlusMotionSensorSource(),
       _loadSettings = loadSettings ?? _loadCachedSettings,
       _loadCalibration = loadCalibration ?? _loadCachedCalibration,
       _loadAlertsMuted =
           loadAlertsMuted ?? (() => AlertMuteController().isMuted),
       _initializeNotifications =
           initializeNotifications ?? PostureNotificationService.initialize,
       _showPostureAlert =
           showPostureAlert ?? PostureNotificationService.showPostureAlert,
       _cancelPostureAlert =
           cancelPostureAlert ?? PostureNotificationService.cancelPostureAlert,
       _writeStatsOverride = writeStats,
       _synchronizeStatsOverride = synchronizeStats,
       _now = now ?? DateTime.now,
       _isAppForeground = isAppForeground ?? _defaultIsAppForeground;

  final MotionSensorSource _sensorSource;
  final ForegroundSettingsLoader _loadSettings;
  final ForegroundCalibrationLoader _loadCalibration;
  final Future<bool> Function() _loadAlertsMuted;
  final Future<void> Function() _initializeNotifications;
  final Future<void> Function() _showPostureAlert;
  final Future<void> Function() _cancelPostureAlert;
  final ForegroundStatsWriter? _writeStatsOverride;
  final Future<void> Function()? _synchronizeStatsOverride;
  final DateTime Function() _now;
  final bool Function() _isAppForeground;

  final Duration sensorAvailabilityTimeout;
  final Duration monitoringTickInterval;
  final Duration statisticsFlushInterval;

  final Set<ForegroundMonitoringDataCallback> _callbacks = {};
  final PhoneAngleFilter _phoneAngleFilter = PhoneAngleFilter();
  final PostureHysteresis _hysteresis = PostureHysteresis();
  final PhoneMovementDetector _movementDetector = PhoneMovementDetector();
  final PostureAlertScheduler _alertScheduler = PostureAlertScheduler();
  final Map<String, _ForegroundStatsDelta> _pendingStats = {};

  StreamSubscription<MotionSensorSample>? _sensorSubscription;
  Timer? _sensorAvailabilityTimer;
  Timer? _tickTimer;
  StatisticsRepository? _statisticsRepository;
  Future<bool>? _startInFlight;
  Future<void>? _stopInFlight;

  AppSettings _settings = AppSettings.defaults;
  Calibration? _calibration;
  String _postureStatus = 'GOOD';
  String? _previousCountedStatus;
  DateTime? _badPostureStart;
  DateTime? _lastTick;
  DateTime? _lastStatsFlush;
  DateTime? _cameraSignalAt;
  bool _enabled = false;
  bool _foregroundActive = false;
  bool _hasSensorReading = false;
  bool _sensorAvailable = false;
  bool _sensorUnavailableReported = false;
  bool _cameraAvailable = false;
  bool _cameraSuggestsGoodPosture = false;
  bool _isMoving = false;
  bool _alertsMuted = false;
  bool _tickInProgress = false;
  int _alertEventSequence = 0;
  double _smoothedPhoneAngle = 0;

  bool get isEnabled => _enabled;
  bool get isForegroundActive => _foregroundActive;
  bool get isSensorTracking => _sensorSubscription != null;
  bool get hasSensorReading => _hasSensorReading;

  void addDataCallback(ForegroundMonitoringDataCallback callback) {
    _callbacks.add(callback);
    if (_enabled) {
      scheduleMicrotask(() {
        if (!_callbacks.contains(callback)) return;
        _sendTo(callback, _stateData());
        if (_sensorUnavailableReported) {
          _sendTo(callback, _errorData('motionSensorsUnavailable'));
        }
      });
    }
  }

  void removeDataCallback(ForegroundMonitoringDataCallback callback) {
    _callbacks.remove(callback);
  }

  Future<bool> start() {
    final existing = _startInFlight;
    if (existing != null) return existing;

    late final Future<bool> operation;
    operation = _start().whenComplete(() {
      if (identical(_startInFlight, operation)) _startInFlight = null;
    });
    _startInFlight = operation;
    return operation;
  }

  Future<bool> _start() async {
    final stopping = _stopInFlight;
    if (stopping != null) await stopping;
    if (_enabled) {
      if (_isAppForeground()) await _resumeForeground();
      _sendState();
      return true;
    }

    try {
      _settings = await _loadSettings();
    } catch (error) {
      debugPrint('Could not load iOS foreground monitoring settings: $error');
      _settings = AppSettings.defaults;
    }
    if (!_settings.monitoringEnabled) return false;

    try {
      _calibration = await _loadCalibration();
    } catch (error) {
      debugPrint('Could not load iOS foreground calibration: $error');
    }
    _calibration ??= const Calibration(
      neutralPhoneAngle: maximumSensorAngleDegrees,
    );

    try {
      _alertsMuted = await _loadAlertsMuted();
    } catch (error) {
      debugPrint('Could not load iOS alert mute state: $error');
      _alertsMuted = false;
    }
    // Notification setup must never block foreground sensor monitoring.
    unawaited(_initializeNotificationsSafely());

    _enabled = true;
    _sensorUnavailableReported = false;
    if (_isAppForeground()) {
      await _resumeForeground();
    } else {
      _foregroundActive = false;
      _sendState();
    }
    return true;
  }

  Future<void> _initializeNotificationsSafely() async {
    try {
      await _initializeNotifications();
    } catch (error) {
      debugPrint('iOS notification initialization is unavailable: $error');
    }
  }

  Future<void> stop() {
    final existing = _stopInFlight;
    if (existing != null) return existing;

    late final Future<void> operation;
    operation = _stop().whenComplete(() {
      if (identical(_stopInFlight, operation)) _stopInFlight = null;
    });
    _stopInFlight = operation;
    return operation;
  }

  Future<void> _stop() async {
    final starting = _startInFlight;
    if (starting != null) await starting;
    _enabled = false;
    _foregroundActive = false;
    _sensorUnavailableReported = false;
    await _stopSensorTracking();
    _stopTicking();
    await _resetPostureEpisode();
    await _flushPendingStats();
    _sendState();
  }

  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      if (_enabled) await _resumeForeground();
      return;
    }
    await _pauseForeground();
  }

  Future<void> _resumeForeground() async {
    if (!_enabled) return;
    if (_foregroundActive && _sensorSubscription != null) return;
    _foregroundActive = true;
    _lastTick = _now();
    _startTicking();
    await _startSensorTracking();
    _sendState();
  }

  Future<void> _pauseForeground() async {
    if (!_foregroundActive && _sensorSubscription == null) return;
    _foregroundActive = false;
    await _stopSensorTracking();
    _stopTicking();
    _cameraAvailable = false;
    _cameraSuggestsGoodPosture = false;
    await _resetPostureEpisode();
    await _flushPendingStats();
    _sendState();
  }

  Future<void> _startSensorTracking() async {
    if (_sensorSubscription != null || !_enabled || !_foregroundActive) return;
    _hasSensorReading = false;
    _sensorAvailable = false;
    try {
      _sensorSubscription = _sensorSource.samples().listen(
        _onSensorSample,
        onError: (Object error, StackTrace _) {
          unawaited(_markSensorUnavailable(error));
        },
        cancelOnError: false,
      );
      _sensorAvailabilityTimer?.cancel();
      _sensorAvailabilityTimer = Timer(sensorAvailabilityTimeout, () {
        if (!_hasSensorReading) {
          unawaited(
            _markSensorUnavailable(
              StateError('No iOS motion-sensor sample was received.'),
            ),
          );
        }
      });
    } catch (error) {
      await _markSensorUnavailable(error);
    }
  }

  Future<void> _stopSensorTracking() async {
    _sensorAvailabilityTimer?.cancel();
    _sensorAvailabilityTimer = null;
    final subscription = _sensorSubscription;
    _sensorSubscription = null;
    await subscription?.cancel();
    _hasSensorReading = false;
    _sensorAvailable = false;
  }

  Future<void> _markSensorUnavailable(Object error) async {
    if (!_enabled || !_foregroundActive) return;
    await _stopSensorTracking();
    _stopTicking();
    await _resetPostureEpisode();
    _sendState();
    if (!_sensorUnavailableReported) {
      _sensorUnavailableReported = true;
      _sendError('motionSensorsUnavailable');
    }
    debugPrint('iOS foreground motion sensors are unavailable: $error');
  }

  void _onSensorSample(MotionSensorSample sample) {
    if (!_enabled || !_foregroundActive) return;
    final rawAngle = phoneAngleFromAccelerometer(
      x: sample.x,
      y: sample.y,
      z: sample.z,
    );
    if (rawAngle == null) return;
    _sensorAvailabilityTimer?.cancel();
    _sensorAvailabilityTimer = null;
    _sensorAvailable = true;
    _sensorUnavailableReported = false;
    final smoothedAngle = _phoneAngleFilter.add(rawAngle);
    if (smoothedAngle == null) return;
    _smoothedPhoneAngle = smoothedAngle;
    _hasSensorReading = true;

    final wasMoving = _isMoving;
    _isMoving = _movementDetector.add(rawAngle);
    if (_isMoving && !wasMoving) {
      _pendingFor(_now()).movementPaused++;
    }
    _evaluatePosture();
  }

  void _evaluatePosture() {
    if (!_enabled || !_foregroundActive || !_hasSensorReading) return;
    final calibration = _calibration;
    if (calibration == null) return;

    final now = _now();
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
          now.difference(_cameraSignalAt!).inSeconds <= 3;

      if (!phoneAngleIsBad ||
          (cameraSignalIsFresh && _cameraSuggestsGoodPosture)) {
        _badPostureStart = null;
        nextStatus = 'GOOD';
      } else {
        _badPostureStart ??= now;
        final badSeconds = now.difference(_badPostureStart!).inSeconds;
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
      if (status == 'BAD') _pendingFor(_now()).badDetections++;
      if (status == 'GOOD') _pendingFor(_now()).goodDetections++;
      _previousCountedStatus = status;
    }

    if (status == 'GOOD') {
      _alertScheduler.reset();
      unawaited(_cancelAlertSafely());
    } else if (status == 'BAD') {
      unawaited(_maybeAlert());
    }
    _sendState();
  }

  Future<void> _maybeAlert() async {
    if (!_settings.alertsEnabled ||
        !_foregroundActive ||
        _alertsMuted ||
        _postureStatus != 'BAD') {
      return;
    }
    final now = _now();
    if (!_alertScheduler.isDue(
      now: now,
      postureIsBad: true,
      alertsEnabled: _settings.alertsEnabled,
      frequencySeconds: _settings.alertFrequencySeconds,
      screenInteractive: _foregroundActive,
      temporarilyMuted: _alertsMuted,
    )) {
      return;
    }

    try {
      await _showPostureAlert();
      _alertScheduler.markAlertSent(now);
      _pendingFor(now).alertsSent++;
      _alertEventSequence++;
      _sendState();
    } catch (error) {
      // Permission denial or unavailable notification delivery must not stop
      // the sensor path.
      debugPrint('Could not show an iOS foreground posture alert: $error');
    }
  }

  void _startTicking() {
    if (_tickTimer != null) return;
    _tickTimer = Timer.periodic(monitoringTickInterval, (_) {
      if (_tickInProgress) return;
      _tickInProgress = true;
      unawaited(
        _tick().whenComplete(() {
          _tickInProgress = false;
        }),
      );
    });
  }

  void _stopTicking() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _lastTick = null;
  }

  Future<void> _tick() async {
    if (!_enabled || !_foregroundActive) return;
    await _refreshMuteState();
    _evaluatePosture();
    final now = _now();
    if (!_hasSensorReading) {
      _lastTick = now;
      _sendState();
      return;
    }

    final previousTick = _lastTick;
    _lastTick = now;
    final elapsed = previousTick == null
        ? 1
        : now.difference(previousTick).inSeconds.clamp(1, 5);
    final delta = _pendingFor(now);
    delta.screenSeconds += elapsed;
    if (_postureStatus == 'BAD') delta.badSeconds += elapsed;

    final shouldFlush =
        _lastStatsFlush == null ||
        now.difference(_lastStatsFlush!) >= statisticsFlushInterval;
    if (shouldFlush) {
      _lastStatsFlush = now;
      await _flushPendingStats();
    }
    _sendState();
  }

  Future<void> _refreshMuteState() async {
    try {
      final muted = await _loadAlertsMuted();
      if (muted == _alertsMuted) return;
      _alertsMuted = muted;
      await _resetPostureEpisode();
      _sendState();
    } catch (error) {
      debugPrint('Could not refresh iOS alert mute state: $error');
    }
  }

  _ForegroundStatsDelta _pendingFor(DateTime timestamp) {
    return _pendingStats.putIfAbsent(
      postureDateKey(timestamp),
      _ForegroundStatsDelta.new,
    );
  }

  Future<void> _flushPendingStats() async {
    for (final entry in _pendingStats.entries.toList()) {
      if (entry.value.isEmpty) {
        _pendingStats.remove(entry.key);
        continue;
      }
      try {
        await _writeStats(entry.key, entry.value.toDelta());
        _pendingStats.remove(entry.key);
      } catch (error) {
        debugPrint(
          'Could not save iOS foreground monitoring statistics: $error',
        );
        break;
      }
    }
  }

  Future<void> _writeStats(String dateKey, StatsDelta delta) async {
    final writer = _writeStatsOverride;
    if (writer != null) return writer(dateKey, delta);
    final repository = _statisticsRepository ??= StatisticsRepository();
    await repository.addDelta(dateKey, delta);
  }

  Future<void> _synchronizeStats() async {
    try {
      final synchronizer = _synchronizeStatsOverride;
      if (synchronizer != null) {
        await synchronizer();
      } else {
        await (_statisticsRepository ??= StatisticsRepository()).synchronize();
      }
    } catch (error) {
      debugPrint('Could not synchronize iOS foreground statistics: $error');
    }
  }

  void updateSettings(AppSettings settings) {
    _settings = settings;
    if (!settings.alertsEnabled) {
      _alertScheduler.reset();
      unawaited(_cancelAlertSafely());
    }
    _evaluatePosture();
  }

  void updateCalibration(Calibration calibration) {
    if (!calibration.isValid) return;
    _calibration = calibration;
    unawaited(_resetPostureEpisode().then((_) => _sendState()));
  }

  void updateCameraSupplement({
    required bool available,
    bool suggestsGoodPosture = false,
  }) {
    if (!_foregroundActive) return;
    _cameraAvailable = available;
    _cameraSuggestsGoodPosture = suggestsGoodPosture;
    _cameraSignalAt = _now();
    _evaluatePosture();
  }

  void reportCameraUnavailable() {
    _pendingFor(_now()).cameraUnavailable++;
    _cameraAvailable = false;
  }

  void requestState() => _sendState();

  void requestStatisticsSync() {
    unawaited(_synchronizeStats());
  }

  void alertMuteChanged() {
    unawaited(_refreshMuteState());
  }

  @visibleForTesting
  Future<void> tickForTesting() => _tick();

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
    await _cancelAlertSafely();
  }

  Future<void> _cancelAlertSafely() async {
    try {
      await _cancelPostureAlert();
    } catch (error) {
      debugPrint('Could not cancel an iOS posture alert: $error');
    }
  }

  void _sendState() {
    _send(_stateData());
  }

  Map<String, Object> _stateData() {
    final now = _now();
    return {
      'type': 'monitoringState',
      'active': _enabled && _foregroundActive,
      'foregroundOnly': true,
      'screenInteractive': _foregroundActive,
      'alertsMuted': _alertsMuted,
      'alertEventSequence': _alertEventSequence,
      'sensorAvailable': _sensorAvailable,
      'hasSensorReading': _hasSensorReading,
      'postureStatus': _postureStatus,
      'phoneAngle': _smoothedPhoneAngle,
      'badPostureSeconds': _badPostureStart == null
          ? 0
          : now.difference(_badPostureStart!).inSeconds,
    };
  }

  void _sendError(String code) {
    _send(_errorData(code));
  }

  Map<String, Object> _errorData(String code) {
    return {'type': 'monitoringError', 'code': code};
  }

  void _send(Object data) {
    for (final callback in _callbacks.toList(growable: false)) {
      _sendTo(callback, data);
    }
  }

  void _sendTo(ForegroundMonitoringDataCallback callback, Object data) {
    try {
      callback(data);
    } catch (error) {
      debugPrint('iOS monitoring callback failed: $error');
    }
  }

  static bool _defaultIsAppForeground() {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  static Future<AppSettings> _loadCachedSettings() async {
    final preferences = SharedPreferencesAsync();
    return await SettingsRepository.loadCachedSettings(preferences) ??
        AppSettings.defaults;
  }

  static Future<Calibration?> _loadCachedCalibration() {
    return CalibrationRepository.loadCachedCalibration(
      SharedPreferencesAsync(),
    );
  }
}
