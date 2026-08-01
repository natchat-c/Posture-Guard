import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/services.dart';

import '../l10n/locale_controller.dart';
import '../models/app_settings.dart';
import '../models/calibration.dart';
import '../services/alert_mute_service.dart';
import '../services/device_screen_time_service.dart';
import '../services/monitoring_service.dart';
import '../services/preferences_service.dart';
import '../widgets/coach_mark_overlay.dart';

enum SettingsTourResult { completed, back, skipped }

enum _SettingsTourItem {
  monitoring,
  notifications,
  screenTime,
  delay,
  frequency,
  postureSetup,
  language,
}

class Settings extends StatefulWidget {
  const Settings({
    super.key,
    required this.store,
    required this.onCalibrateNeutral,
    this.onSettingsSaved,
    this.loadMonitoringState,
    this.onMonitoringEnabledChanged,
    this.screenTimeProvider,
    this.alertMuteController,
    this.onAlertMuteChanged,
    this.initialCalibration,
    this.currentCalibration,
    this.initialHasCalibration = false,
    this.showGuidedTour = false,
    this.loadNotificationPermission,
    this.requestNotificationPermission,
  });

  final SettingsStore store;
  final Future<bool> Function() onCalibrateNeutral;
  final Future<void> Function(AppSettings settings)? onSettingsSaved;
  final Future<bool> Function()? loadMonitoringState;
  final Future<MonitoringControlResult> Function(bool enabled)?
  onMonitoringEnabledChanged;
  final DeviceScreenTimeProvider? screenTimeProvider;
  final AlertMuteController? alertMuteController;
  final VoidCallback? onAlertMuteChanged;
  final Calibration? initialCalibration;
  final Calibration? Function()? currentCalibration;
  final bool initialHasCalibration;
  final bool showGuidedTour;
  final Future<NotificationPermission> Function()? loadNotificationPermission;
  final Future<NotificationPermission> Function()?
  requestNotificationPermission;

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> with WidgetsBindingObserver {
  static const int customOption = -1;
  static const List<int> delayOptions = [10, 30, 60];
  static const List<int> frequencyOptions = [15, 30, 60, 300];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _customDelayController = TextEditingController();
  final TextEditingController _customFrequencyController =
      TextEditingController();
  final GlobalKey _monitoringTourKey = GlobalKey();
  final GlobalKey _notificationsTourKey = GlobalKey();
  final GlobalKey _screenTimeTourKey = GlobalKey();
  final GlobalKey _delayTourKey = GlobalKey();
  final GlobalKey _frequencyTourKey = GlobalKey();
  final GlobalKey _postureSetupTourKey = GlobalKey();
  final GlobalKey _languageTourKey = GlobalKey();

  AppSettings _settings = AppSettings.defaults;
  int _selectedDelayOption = AppSettings.defaultAlertDelaySeconds;
  int _selectedFrequencyOption = AppSettings.defaultAlertFrequencySeconds;
  bool _loading = true;
  bool _saving = false;
  bool _applyingImmediateSetting = false;
  bool _monitoringActive = false;
  bool _changingMonitoringState = false;
  bool _calibrating = false;
  late bool _hasCalibration;
  Calibration? _calibration;
  String? _loadWarning;
  late final DeviceScreenTimeProvider _screenTimeProvider;
  bool _screenTimeSupported = false;
  bool _hasUsageAccess = false;
  bool _checkingUsageAccess = false;
  bool _usageAccessResolved = false;
  bool _notificationPermissionResolved = false;
  bool _notificationGranted = false;
  bool _checkingNotificationPermission = false;
  bool _notificationPermissionAttempted = false;
  bool _guidedTourStarted = false;
  bool _usageSettingsOpenedFromTour = false;
  List<_SettingsTourItem> _guidedTourItems = const [];
  int? _guidedTourIndex;
  int? _preparedGuidedTourIndex;
  late final AlertMuteController _alertMuteController;
  DateTime? _alertsMutedUntil;
  Timer? _muteStatusTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screenTimeProvider =
        widget.screenTimeProvider ?? const AndroidDeviceScreenTimeProvider();
    _alertMuteController = widget.alertMuteController ?? AlertMuteController();
    _calibration = widget.initialCalibration;
    _hasCalibration = widget.initialHasCalibration || _calibration != null;
    _load();
    _refreshUsageAccess();
    _refreshNotificationPermission();
    _refreshAlertMute();
    _muteStatusTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshAlertMute(),
    );
  }

  Future<void> _load() async {
    final result = await widget.store.load();
    var monitoringActive = false;
    var monitoringStateFailed = false;
    try {
      monitoringActive = await widget.loadMonitoringState?.call() ?? false;
    } catch (_) {
      monitoringStateFailed = true;
    }
    if (!mounted) return;
    final monitoringWarning = monitoringStateFailed
        ? context.l10n.monitoringStateUnavailable
        : null;

    final settings = result.settings;
    setState(() {
      _settings = settings;
      _selectedDelayOption = delayOptions.contains(settings.alertDelaySeconds)
          ? settings.alertDelaySeconds
          : customOption;
      _selectedFrequencyOption =
          frequencyOptions.contains(settings.alertFrequencySeconds)
          ? settings.alertFrequencySeconds
          : customOption;
      _customDelayController.text = settings.alertDelaySeconds.toString();
      _customFrequencyController.text = settings.alertFrequencySeconds
          .toString();
      _loadWarning = result.warning == null
          ? null
          : context.l10n.dataLoadWarning;
      _monitoringActive = monitoringActive;
      _loading = false;
    });
    _maybeStartGuidedTour();

    final warning = monitoringWarning ?? result.warning;
    if (warning != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(warning)));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _customDelayController.dispose();
    _customFrequencyController.dispose();
    _muteStatusTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshUsageAccess();
      _refreshNotificationPermission();
      _refreshAlertMute();
    }
  }

  Future<void> _refreshAlertMute() async {
    final mutedUntil = await _alertMuteController.activeMutedUntil();
    if (!mounted) return;
    setState(() => _alertsMutedUntil = mutedUntil);
  }

  Future<void> _unmuteAlerts() async {
    await _alertMuteController.unmute();
    (widget.onAlertMuteChanged ?? MonitoringService.alertMuteChanged)();
    if (!mounted) return;
    setState(() => _alertsMutedUntil = null);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.unmutedMessage)));
  }

  Future<void> _refreshUsageAccess() async {
    if (mounted) setState(() => _checkingUsageAccess = true);
    final supported = await _screenTimeProvider.isSupported();
    final hasAccess = supported && await _screenTimeProvider.hasUsageAccess();
    if (!mounted) return;
    final shouldAdvanceTour =
        hasAccess && _currentGuidedTourItem == _SettingsTourItem.screenTime;
    setState(() {
      _screenTimeSupported = supported;
      _hasUsageAccess = hasAccess;
      _checkingUsageAccess = false;
      _usageAccessResolved = true;
    });
    _maybeStartGuidedTour();
    if (shouldAdvanceTour) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _moveGuidedTour(1);
      });
    }
  }

  Future<void> _refreshNotificationPermission() async {
    final permission =
        await (widget.loadNotificationPermission ??
            MonitoringService.notificationPermission)();
    if (!mounted) return;
    setState(() {
      _notificationGranted = permission == NotificationPermission.granted;
      _notificationPermissionResolved = true;
      _checkingNotificationPermission = false;
    });
    _maybeStartGuidedTour();
  }

  Future<void> _requestNotificationAccess() async {
    if (_checkingNotificationPermission || _notificationPermissionAttempted) {
      return;
    }
    setState(() {
      _checkingNotificationPermission = true;
      _notificationPermissionAttempted = true;
    });
    final permission =
        await (widget.requestNotificationPermission ??
            MonitoringService.requestNotificationPermissionIfAppropriate)();
    if (!mounted) return;
    setState(() {
      _notificationGranted = permission == NotificationPermission.granted;
      _checkingNotificationPermission = false;
    });
    if (_currentGuidedTourItem == _SettingsTourItem.notifications) {
      _moveGuidedTour(1);
    }
  }

  Future<void> _openUsageAccessSettings() async {
    if (_checkingUsageAccess) return;
    setState(() => _checkingUsageAccess = true);
    final opened = await _screenTimeProvider.openUsageAccessSettings();
    if (!mounted) return;
    if (!opened) {
      setState(() => _checkingUsageAccess = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.screenTimeSettingsUnavailable)),
      );
    }
  }

  int? _parseCustom(TextEditingController controller, {required bool isDelay}) {
    final value = int.tryParse(controller.text.trim());
    if (value == null) return null;
    final valid = isDelay
        ? AppSettings.isValidAlertDelay(value)
        : AppSettings.isValidAlertFrequency(value);
    return valid ? value : null;
  }

  String? _validateCustom(
    String? raw, {
    required bool selected,
    required bool isDelay,
  }) {
    if (!selected) return null;
    final value = int.tryParse(raw?.trim() ?? '');
    if (value == null) return context.l10n.enterWholeNumber;

    if (isDelay && !AppSettings.isValidAlertDelay(value)) {
      return context.l10n.secondsRange(
        AppSettings.minimumAlertDelaySeconds,
        AppSettings.maximumAlertDelaySeconds,
      );
    }
    if (!isDelay && !AppSettings.isValidAlertFrequency(value)) {
      return context.l10n.secondsRange(
        AppSettings.minimumAlertFrequencySeconds,
        AppSettings.maximumAlertFrequencySeconds,
      );
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final delay = _selectedDelayOption == customOption
        ? _parseCustom(_customDelayController, isDelay: true)
        : _selectedDelayOption;
    final frequency = _selectedFrequencyOption == customOption
        ? _parseCustom(_customFrequencyController, isDelay: false)
        : _selectedFrequencyOption;
    if (delay == null || frequency == null) return;

    final settings = AppSettings(
      monitoringEnabled: _settings.monitoringEnabled,
      alertDelaySeconds: delay,
      alertFrequencySeconds: frequency,
      alertsEnabled: _settings.alertsEnabled,
    );

    setState(() => _saving = true);
    try {
      final result = await widget.store.save(settings);
      await widget.onSettingsSaved?.call(settings);
      if (!mounted) return;

      setState(() => _settings = settings);
      if (result.succeeded) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.settingsSaved)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.settingsSavedLocally)),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.settingsSaveFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _calibrate() async {
    if (_calibrating) return;
    setState(() => _calibrating = true);
    try {
      final saved = await widget.onCalibrateNeutral();
      if (!mounted) return;
      if (saved) {
        setState(() {
          _hasCalibration = true;
          _calibration = widget.currentCalibration?.call() ?? _calibration;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved ? context.l10n.positionSet : context.l10n.calibrationError,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _calibrating = false);
    }
  }

  Future<void> _setMonitoringEnabled(bool enabled) async {
    if (_changingMonitoringState) return;
    final callback = widget.onMonitoringEnabledChanged;
    if (callback == null) return;

    final previousSettings = _settings;
    final selectedSettings = _settings.copyWith(monitoringEnabled: enabled);
    setState(() {
      _settings = selectedSettings;
      _changingMonitoringState = true;
    });
    try {
      final saveResult = await widget.store.save(selectedSettings);
      await widget.onSettingsSaved?.call(selectedSettings);
      final result = await callback(enabled);
      if (!mounted) return;

      final correctedSettings = selectedSettings.copyWith(
        monitoringEnabled: result.isActive,
      );
      SettingsSaveResult? correctionSaveResult;
      if (correctedSettings != selectedSettings) {
        correctionSaveResult = await widget.store.save(correctedSettings);
        await widget.onSettingsSaved?.call(correctedSettings);
      }
      if (!mounted) return;
      setState(() {
        _settings = correctedSettings;
        _monitoringActive = result.isActive;
      });

      final messages = <String>[
        ?result.message,
        if (!saveResult.savedToFirebase ||
            correctionSaveResult?.savedToFirebase == false)
          context.l10n.cloudBackupWarning,
      ];
      if (messages.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messages.join(' '))));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _settings = previousSettings);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.settingUpdateFailed)));
    } finally {
      if (mounted) setState(() => _changingMonitoringState = false);
    }
  }

  Future<void> _setAlertsEnabled(bool enabled) async {
    if (_applyingImmediateSetting) return;
    final previousSettings = _settings;
    final selectedSettings = _settings.copyWith(alertsEnabled: enabled);
    setState(() {
      _settings = selectedSettings;
      _applyingImmediateSetting = true;
    });

    try {
      final result = await widget.store.save(selectedSettings);
      await widget.onSettingsSaved?.call(selectedSettings);
      if (!mounted) return;
      if (!result.savedToFirebase) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.cloudBackupWarning)),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _settings = previousSettings);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.settingUpdateFailed)));
    } finally {
      if (mounted) setState(() => _applyingImmediateSetting = false);
    }
  }

  DropdownMenuItem<int> _menuItem(int value, String label) {
    return DropdownMenuItem<int>(value: value, child: Text(label));
  }

  _SettingsTourItem? get _currentGuidedTourItem {
    final index = _guidedTourIndex;
    if (index == null || index < 0 || index >= _guidedTourItems.length) {
      return null;
    }
    return _guidedTourItems[index];
  }

  void _maybeStartGuidedTour() {
    if (!widget.showGuidedTour ||
        _guidedTourStarted ||
        _loading ||
        !_usageAccessResolved ||
        !_notificationPermissionResolved) {
      return;
    }
    _guidedTourStarted = true;
    _guidedTourItems = [
      _SettingsTourItem.monitoring,
      _SettingsTourItem.notifications,
      if (_screenTimeSupported && !_hasUsageAccess)
        _SettingsTourItem.screenTime,
      _SettingsTourItem.delay,
      _SettingsTourItem.frequency,
      _SettingsTourItem.postureSetup,
      _SettingsTourItem.language,
    ];
    setState(() {
      _guidedTourIndex = 0;
      _preparedGuidedTourIndex = null;
    });
  }

  GlobalKey? _guidedTourKey(_SettingsTourItem? item) {
    return switch (item) {
      _SettingsTourItem.monitoring => _monitoringTourKey,
      _SettingsTourItem.notifications => _notificationsTourKey,
      _SettingsTourItem.screenTime => _screenTimeTourKey,
      _SettingsTourItem.delay => _delayTourKey,
      _SettingsTourItem.frequency => _frequencyTourKey,
      _SettingsTourItem.postureSetup => _postureSetupTourKey,
      _SettingsTourItem.language => _languageTourKey,
      null => null,
    };
  }

  Future<void> _prepareGuidedTourTarget() async {
    final index = _guidedTourIndex;
    if (index == null || _preparedGuidedTourIndex == index) return;
    _preparedGuidedTourIndex = index;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final targetContext = _guidedTourKey(
      _currentGuidedTourItem,
    )?.currentContext;
    if (targetContext != null && targetContext.mounted) {
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.35,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    if (mounted) setState(() {});
  }

  Rect? _guidedTourTargetRect() {
    final renderObject = _guidedTourKey(
      _currentGuidedTourItem,
    )?.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  void _finishGuidedTour(SettingsTourResult result) {
    setState(() => _guidedTourIndex = null);
    if (Navigator.canPop(context)) Navigator.pop(context, result);
  }

  void _moveGuidedTour(int delta) {
    final index = _guidedTourIndex;
    if (index == null) return;
    final next = index + delta;
    if (next < 0) {
      _finishGuidedTour(SettingsTourResult.back);
      return;
    }
    if (next >= _guidedTourItems.length) {
      _finishGuidedTour(SettingsTourResult.completed);
      return;
    }
    setState(() {
      _guidedTourIndex = next;
      _preparedGuidedTourIndex = null;
    });
  }

  void _skipGuidedTourItem() {
    if (_currentGuidedTourItem == _SettingsTourItem.screenTime) {
      _moveGuidedTour(1);
    } else {
      _finishGuidedTour(SettingsTourResult.skipped);
    }
  }

  Future<void> _allowUsageAccessFromTour() async {
    if (_usageSettingsOpenedFromTour || _checkingUsageAccess) return;
    setState(() => _usageSettingsOpenedFromTour = true);
    await _openUsageAccessSettings();
  }

  (String, String) _guidedTourCopy(_SettingsTourItem item) {
    final l10n = context.l10n;
    return switch (item) {
      _SettingsTourItem.monitoring => (
        l10n.monitoringEnabledSetting,
        l10n.settingsTourEnabledBody,
      ),
      _SettingsTourItem.notifications => (
        l10n.sendNotifications,
        l10n.settingsTourNotificationsBody,
      ),
      _SettingsTourItem.screenTime => (
        l10n.screenTimeTourTitle,
        l10n.screenTimeTourBody,
      ),
      _SettingsTourItem.delay => (l10n.alertDelay, l10n.settingsTourDelayBody),
      _SettingsTourItem.frequency => (
        l10n.alertRepeatFrequency,
        l10n.settingsTourFrequencyBody,
      ),
      _SettingsTourItem.postureSetup => (
        l10n.postureSetup,
        l10n.settingsTourPostureSetupBody,
      ),
      _SettingsTourItem.language => (
        l10n.language,
        l10n.settingsTourLanguageBody,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedLanguage =
        context.localeController?.selectedLanguageCode ??
        Localizations.localeOf(context).languageCode;
    final settingsPage = Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: FilledButton.icon(
                key: const Key('saveSettingsButton'),
                onPressed:
                    _saving ||
                        _applyingImmediateSetting ||
                        _changingMonitoringState
                    ? null
                    : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? l10n.saving : l10n.saveSettings),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                key: const Key('settingsScrollView'),
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loadWarning != null)
                      Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(_loadWarning!),
                        ),
                      ),
                    Text(
                      l10n.language,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    KeyedSubtree(
                      key: _languageTourKey,
                      child: DropdownButtonFormField<String>(
                        key: const Key('languageSelector'),
                        initialValue: selectedLanguage,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'en',
                            child: Text(l10n.english),
                          ),
                          DropdownMenuItem(value: 'th', child: Text(l10n.thai)),
                        ],
                        onChanged: (code) async {
                          if (code == null || code == selectedLanguage) return;
                          await context.localeController?.selectLanguage(code);
                        },
                      ),
                    ),
                    const Divider(height: 32),
                    KeyedSubtree(
                      key: _monitoringTourKey,
                      child: SwitchListTile(
                        key: const Key('monitoringEnabledSwitch'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.monitoringEnabledSetting),
                        subtitle: Text(
                          !_settings.monitoringEnabled
                              ? l10n.monitoringDisabledDescription
                              : _monitoringActive
                              ? l10n.monitoringActiveDescription
                              : l10n.monitoringWaitingDescription,
                        ),
                        value: _settings.monitoringEnabled,
                        onChanged:
                            _saving ||
                                _applyingImmediateSetting ||
                                _changingMonitoringState ||
                                widget.onMonitoringEnabledChanged == null
                            ? null
                            : _setMonitoringEnabled,
                      ),
                    ),
                    const Divider(height: 32),
                    KeyedSubtree(
                      key: _notificationsTourKey,
                      child: SwitchListTile(
                        key: const Key('alertsEnabledSwitch'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.sendNotifications),
                        subtitle: Text(l10n.notificationsDisabledDescription),
                        value: _settings.alertsEnabled,
                        onChanged:
                            _saving ||
                                _applyingImmediateSetting ||
                                _changingMonitoringState
                            ? null
                            : _setAlertsEnabled,
                      ),
                    ),
                    if (_settings.alertsEnabled &&
                        _notificationPermissionResolved &&
                        !_notificationGranted)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          key: const Key('allowNotificationAccessButton'),
                          onPressed:
                              _checkingNotificationPermission ||
                                  _notificationPermissionAttempted
                              ? null
                              : _requestNotificationAccess,
                          icon: _checkingNotificationPermission
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.notifications_outlined),
                          label: Text(l10n.allowNotifications),
                        ),
                      ),
                    if (_alertsMutedUntil case final mutedUntil?) ...[
                      Padding(
                        key: const Key('temporaryAlertMuteStatus'),
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.alertsMutedUntil(
                                  TimeOfDay.fromDateTime(
                                    mutedUntil,
                                  ).format(context),
                                ),
                              ),
                            ),
                            TextButton(
                              key: const Key('unmuteAlertsButton'),
                              onPressed: _unmuteAlerts,
                              child: Text(l10n.unmuteNow),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_screenTimeSupported)
                      KeyedSubtree(
                        key: _screenTimeTourKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Divider(height: 32),
                            Padding(
                              key: const Key('deviceScreenTimeSetting'),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.screen_lock_portrait_outlined,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.useDeviceScreenTime,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(l10n.deviceScreenTimePrivacy),
                                        const SizedBox(height: 6),
                                        Text(
                                          _hasUsageAccess
                                              ? l10n.accessGranted
                                              : l10n.accessNotGranted,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!_hasUsageAccess)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  key: const Key('allowScreenTimeAccessButton'),
                                  onPressed: _checkingUsageAccess
                                      ? null
                                      : () => _openUsageAccessSettings(),
                                  icon: _checkingUsageAccess
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.settings_outlined),
                                  label: Text(l10n.allowScreenTimeAccess),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const Divider(height: 32),
                    Text(
                      l10n.alertDelay,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    KeyedSubtree(
                      key: _delayTourKey,
                      child: DropdownButtonFormField<int>(
                        key: const Key('alertDelayDropdown'),
                        initialValue: _selectedDelayOption,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          helperText: l10n.alertDelayHelp,
                        ),
                        items: [
                          _menuItem(10, l10n.secondsCount(10)),
                          _menuItem(30, l10n.secondsCount(30)),
                          _menuItem(60, l10n.minuteCount(1)),
                          _menuItem(customOption, l10n.custom),
                        ],
                        onChanged:
                            _saving ||
                                _applyingImmediateSetting ||
                                _changingMonitoringState
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedDelayOption = value;
                                  if (value != customOption) {
                                    _customDelayController.text = value
                                        .toString();
                                  }
                                });
                              },
                      ),
                    ),
                    if (_selectedDelayOption == customOption) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('customDelayField'),
                        controller: _customDelayController,
                        enabled:
                            !_saving &&
                            !_applyingImmediateSetting &&
                            !_changingMonitoringState,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: l10n.customDelaySeconds,
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => _validateCustom(
                          value,
                          selected: _selectedDelayOption == customOption,
                          isDelay: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Text(
                      l10n.alertRepeatFrequency,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    KeyedSubtree(
                      key: _frequencyTourKey,
                      child: DropdownButtonFormField<int>(
                        key: const Key('alertFrequencyDropdown'),
                        initialValue: _selectedFrequencyOption,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          helperText: l10n.alertFrequencyHelp,
                        ),
                        items: [
                          _menuItem(15, l10n.secondsCount(15)),
                          _menuItem(30, l10n.secondsCount(30)),
                          _menuItem(60, l10n.minuteCount(1)),
                          _menuItem(300, l10n.minuteCount(5)),
                          _menuItem(customOption, l10n.custom),
                        ],
                        onChanged:
                            _saving ||
                                _applyingImmediateSetting ||
                                _changingMonitoringState
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedFrequencyOption = value;
                                  if (value != customOption) {
                                    _customFrequencyController.text = value
                                        .toString();
                                  }
                                });
                              },
                      ),
                    ),
                    if (_selectedFrequencyOption == customOption) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('customFrequencyField'),
                        controller: _customFrequencyController,
                        enabled:
                            !_saving &&
                            !_applyingImmediateSetting &&
                            !_changingMonitoringState,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: l10n.customFrequencySeconds,
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => _validateCustom(
                          value,
                          selected: _selectedFrequencyOption == customOption,
                          isDelay: false,
                        ),
                      ),
                    ],
                    const Divider(height: 36),
                    Text(
                      l10n.postureSetup,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.postureSetupDescription),
                    const SizedBox(height: 8),
                    _calibrationDetails(),
                    const SizedBox(height: 12),
                    KeyedSubtree(
                      key: _postureSetupTourKey,
                      child: FilledButton.icon(
                        key: const Key('calibrateButton'),
                        onPressed:
                            _saving ||
                                _calibrating ||
                                _applyingImmediateSetting ||
                                _changingMonitoringState
                            ? null
                            : _calibrate,
                        icon: _calibrating
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.center_focus_strong),
                        label: Text(
                          _hasCalibration
                              ? l10n.setPositionAgain
                              : l10n.setPosition,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );

    final guidedTourIndex = _guidedTourIndex;
    final guidedTourItem = _currentGuidedTourItem;
    if (guidedTourIndex == null || guidedTourItem == null) {
      return settingsPage;
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _prepareGuidedTourTarget(),
    );
    final copy = _guidedTourCopy(guidedTourItem);
    final isScreenTime = guidedTourItem == _SettingsTourItem.screenTime;
    final needsNotificationPermission =
        guidedTourItem == _SettingsTourItem.notifications &&
        !_notificationGranted;
    final isLast = guidedTourIndex == _guidedTourItems.length - 1;

    return Stack(
      children: [
        settingsPage,
        Positioned.fill(
          child: CoachMarkOverlay(
            target: _guidedTourTargetRect(),
            title: copy.$1,
            body: copy.$2,
            currentStep: guidedTourIndex,
            totalSteps: _guidedTourItems.length,
            backLabel: l10n.back,
            nextLabel: needsNotificationPermission
                ? l10n.allowNotifications
                : isScreenTime
                ? l10n.allow
                : isLast
                ? l10n.done
                : l10n.next,
            skipLabel: l10n.skip,
            onBack: () => _moveGuidedTour(-1),
            onNext: needsNotificationPermission
                ? (_checkingNotificationPermission ||
                          _notificationPermissionAttempted
                      ? null
                      : _requestNotificationAccess)
                : isScreenTime
                ? (_usageSettingsOpenedFromTour || _checkingUsageAccess
                      ? null
                      : _allowUsageAccessFromTour)
                : () => _moveGuidedTour(1),
            onSkip: _skipGuidedTourItem,
            nextButtonKey: const Key('settingsTourNextButton'),
            backButtonKey: const Key('settingsTourBackButton'),
            skipButtonKey: const Key('settingsTourSkipButton'),
          ),
        ),
      ],
    );
  }

  Widget _calibrationDetails() {
    final calibration = _calibration;
    if (calibration == null || !calibration.isValid) {
      return Text(
        context.l10n.positionNotSet,
        key: const Key('calibrationDiagnostics'),
      );
    }
    return Text(
      context.l10n.positionSet,
      key: const Key('calibrationDiagnostics'),
    );
  }
}

class MonitoringControlResult {
  const MonitoringControlResult({
    required this.success,
    required this.isActive,
    this.message,
  });

  final bool success;
  final bool isActive;
  final String? message;
}
