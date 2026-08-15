import '../models/app_settings.dart';
import 'monitoring_service.dart';
import 'preferences_service.dart';

class AppStartupResult {
  const AppStartupResult({
    required this.monitoringEnabled,
    required this.isRunning,
    this.warning,
  });

  final bool monitoringEnabled;
  final bool isRunning;
  final String? warning;
}

class AppStartupCoordinator {
  AppStartupCoordinator({
    TutorialPreferences? tutorialPreferences,
    SettingsStore? settingsStore,
    Future<bool> Function()? isMonitoringRunning,
    Future<MonitoringActionResult> Function()? startMonitoring,
    Future<MonitoringActionResult> Function()? stopMonitoring,
    Future<NotificationPermission> Function()? requestNotificationPermission,
  }) : _tutorialPreferences = tutorialPreferences ?? TutorialPreferences(),
       _settingsStore = settingsStore ?? SettingsRepository(),
       _isMonitoringRunning =
           isMonitoringRunning ?? MonitoringService.isRunning,
       _startMonitoring = startMonitoring ?? MonitoringService.start,
       _stopMonitoring = stopMonitoring ?? MonitoringService.stop;

  final TutorialPreferences _tutorialPreferences;
  final SettingsStore _settingsStore;
  final Future<bool> Function() _isMonitoringRunning;
  final Future<MonitoringActionResult> Function() _startMonitoring;
  final Future<MonitoringActionResult> Function() _stopMonitoring;

  Future<bool> hasCompletedTutorial() {
    return _tutorialPreferences.hasCompletedTutorial();
  }

  Future<AppStartupResult> completeFirstLaunch() async {
    await _tutorialPreferences.markCompleted();
    final loadResult = await _settingsStore.load();
    final settings = loadResult.settings;
    final saveResult = await _settingsStore.save(settings);

    return _applyStartupState(
      settings,
      initialWarning: _combineWarnings(
        loadResult.warning,
        saveResult.savedToFirebase
            ? null
            : 'Your enabled settings were saved on this device, but cloud synchronization failed.',
      ),
    );
  }

  Future<AppStartupResult> restoreAfterCompletedTutorial() async {
    final loadResult = await _settingsStore.load();
    return _applyStartupState(
      loadResult.settings,
      initialWarning: loadResult.warning,
    );
  }

  Future<AppStartupResult> _applyStartupState(
    AppSettings settings, {
    String? initialWarning,
    NotificationPermission? notificationPermission,
  }) async {
    final alreadyRunning = await _isMonitoringRunning();
    if (!settings.monitoringEnabled) {
      if (!alreadyRunning) {
        return AppStartupResult(
          monitoringEnabled: false,
          isRunning: false,
          warning: initialWarning,
        );
      }

      final stopResult = await _stopMonitoring();
      if (!stopResult.success && stopResult.isRunning) {
        final correctedSettings = settings.copyWith(monitoringEnabled: true);
        final saveResult = await _settingsStore.save(correctedSettings);
        return AppStartupResult(
          monitoringEnabled: true,
          isRunning: true,
          warning: _combineWarnings(
            initialWarning,
            'Android could not stop the monitoring service. '
            'Posture Guard remains enabled; try the switch again in Settings.',
            saveResult.savedToFirebase
                ? null
                : 'The accurate service state was saved locally, but cloud synchronization failed.',
          ),
        );
      }
      return AppStartupResult(
        monitoringEnabled: false,
        isRunning: stopResult.isRunning,
        warning: _combineWarnings(
          initialWarning,
          stopResult.success
              ? null
              : 'Posture Guard is disabled, but Android could not stop the monitoring service.',
        ),
      );
    }

    if (alreadyRunning) {
      MonitoringService.requestState();
      return AppStartupResult(
        monitoringEnabled: true,
        isRunning: true,
        warning: _combineWarnings(
          initialWarning,
          _notificationWarning(notificationPermission),
        ),
      );
    }

    final startResult = await _startMonitoring();
    if (startResult.success && startResult.isRunning) {
      return AppStartupResult(
        monitoringEnabled: true,
        isRunning: true,
        warning: _combineWarnings(
          initialWarning,
          _notificationWarning(
            notificationPermission ?? startResult.notificationPermission,
          ),
        ),
      );
    }

    final disabledSettings = settings.copyWith(monitoringEnabled: false);
    final rollbackResult = await _settingsStore.save(disabledSettings);
    return AppStartupResult(
      monitoringEnabled: false,
      isRunning: startResult.isRunning,
      warning: _combineWarnings(
        initialWarning,
        'Posture Guard could not start monitoring. Open Settings to try again. '
                '${startResult.error ?? ''}'
            .trim(),
        rollbackResult.savedToFirebase
            ? null
            : 'The disabled state was saved locally, but cloud synchronization failed.',
      ),
    );
  }

  String? _notificationWarning(NotificationPermission? permission) {
    if (permission == null || permission == NotificationPermission.granted) {
      return null;
    }
    return 'Monitoring is active, but Android notification permission is disabled. '
        'Enable notifications in system settings to receive posture alerts.';
  }

  String? _combineWarnings(String? first, String? second, [String? third]) {
    final warnings = [first, second, third]
        .whereType<String>()
        .where((warning) => warning.trim().isNotEmpty)
        .toList();
    return warnings.isEmpty ? null : warnings.join(' ');
  }
}
