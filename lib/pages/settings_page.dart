import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../models/calibration.dart';
import '../models/posture_thresholds.dart';
import '../services/alert_mute_service.dart';
import '../services/device_screen_time_service.dart';
import '../services/monitoring_service.dart';
import '../services/preferences_service.dart';

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
    _refreshAlertMute();
    _muteStatusTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshAlertMute(),
    );
  }

  Future<void> _load() async {
    final result = await widget.store.load();
    var monitoringActive = false;
    String? monitoringWarning;
    try {
      monitoringActive = await widget.loadMonitoringState?.call() ?? false;
    } catch (_) {
      monitoringWarning = 'Could not confirm the monitoring service state.';
    }
    if (!mounted) return;

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
      _loadWarning = result.warning;
      _monitoringActive = monitoringActive;
      _loading = false;
    });

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Temporary mute cleared. A full posture-alert delay is required.',
        ),
      ),
    );
  }

  Future<void> _refreshUsageAccess() async {
    final supported = await _screenTimeProvider.isSupported();
    final hasAccess = supported && await _screenTimeProvider.hasUsageAccess();
    if (!mounted) return;
    setState(() {
      _screenTimeSupported = supported;
      _hasUsageAccess = hasAccess;
      _checkingUsageAccess = false;
    });
  }

  Future<void> _openUsageAccessSettings() async {
    if (_checkingUsageAccess) return;
    setState(() => _checkingUsageAccess = true);
    final opened = await _screenTimeProvider.openUsageAccessSettings();
    if (!mounted) return;
    if (!opened) {
      setState(() => _checkingUsageAccess = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Android Usage Access settings are unavailable.'),
        ),
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
    if (value == null) return 'Enter a whole number.';

    if (isDelay && !AppSettings.isValidAlertDelay(value)) {
      return 'Use ${AppSettings.minimumAlertDelaySeconds}–${AppSettings.maximumAlertDelaySeconds} seconds.';
    }
    if (!isDelay && !AppSettings.isValidAlertFrequency(value)) {
      return 'Use ${AppSettings.minimumAlertFrequencySeconds}–${AppSettings.maximumAlertFrequencySeconds} seconds.';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Settings were saved on this device, but Firebase sync failed.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save settings: $error')),
      );
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
            saved
                ? 'Neutral posture saved.'
                : 'Calibration failed. Hold the phone steady and try again.',
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
          'Your choice was saved on this device, but cloud synchronization failed.',
      ];
      if (messages.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messages.join(' '))));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _settings = previousSettings);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update Posture Guard: $error')),
      );
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
          const SnackBar(
            content: Text(
              'Your alert choice was saved on this device, but cloud synchronization failed.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _settings = previousSettings);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update posture alerts: $error')),
      );
    } finally {
      if (mounted) setState(() => _applyingImmediateSetting = false);
    }
  }

  DropdownMenuItem<int> _menuItem(int value, String label) {
    return DropdownMenuItem<int>(value: value, child: Text(label));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
                label: Text(_saving ? 'Saving…' : 'Save settings'),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                key: const Key('settingsScrollView'),
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  if (_loadWarning != null)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_loadWarning!),
                      ),
                    ),
                  SwitchListTile(
                    key: const Key('monitoringEnabledSwitch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Posture Guard enabled'),
                    subtitle: Text(
                      !_settings.monitoringEnabled
                          ? 'Posture monitoring is disabled.'
                          : _monitoringActive
                          ? 'Posture monitoring is active.'
                          : 'Posture monitoring is waiting to start.',
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
                  const Divider(height: 32),
                  SwitchListTile(
                    key: const Key('alertsEnabledSwitch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Send posture notifications'),
                    subtitle: const Text(
                      'Monitoring continues when alerts are disabled.',
                    ),
                    value: _settings.alertsEnabled,
                    onChanged:
                        _saving ||
                            _applyingImmediateSetting ||
                            _changingMonitoringState
                        ? null
                        : _setAlertsEnabled,
                  ),
                  if (_alertsMutedUntil case final mutedUntil?) ...[
                    Padding(
                      key: const Key('temporaryAlertMuteStatus'),
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Posture alerts muted until '
                              '${TimeOfDay.fromDateTime(mutedUntil).format(context)}',
                            ),
                          ),
                          TextButton(
                            key: const Key('unmuteAlertsButton'),
                            onPressed: _unmuteAlerts,
                            child: const Text('Unmute now'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_screenTimeSupported) ...[
                    const Divider(height: 32),
                    Padding(
                      key: const Key('deviceScreenTimeSetting'),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.screen_lock_portrait_outlined),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Use device screen time',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Posture Guard can use Android Usage Access '
                                  'to read your total daily screen-on time. '
                                  'Only the combined duration is used; Posture '
                                  'Guard does not display or upload which apps '
                                  'you used.',
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _hasUsageAccess
                                      ? 'Usage Access granted.'
                                      : 'Usage Access not granted.',
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
                              : _openUsageAccessSettings,
                          icon: _checkingUsageAccess
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.settings_outlined),
                          label: const Text('Allow screen-time access'),
                        ),
                      ),
                  ],
                  const Divider(height: 32),
                  Text(
                    'Alert delay',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    key: const Key('alertDelayDropdown'),
                    initialValue: _selectedDelayOption,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      helperText:
                          'How long poor posture must continue before the first alert.',
                    ),
                    items: [
                      _menuItem(10, '10 seconds'),
                      _menuItem(30, '30 seconds'),
                      _menuItem(60, '1 minute'),
                      _menuItem(customOption, 'Custom'),
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
                                _customDelayController.text = value.toString();
                              }
                            });
                          },
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Custom delay (seconds)',
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
                    'Alert frequency',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    key: const Key('alertFrequencyDropdown'),
                    initialValue: _selectedFrequencyOption,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      helperText:
                          'How often alerts repeat while posture remains poor.',
                    ),
                    items: [
                      _menuItem(15, '15 seconds'),
                      _menuItem(30, '30 seconds'),
                      _menuItem(60, '1 minute'),
                      _menuItem(300, '5 minutes'),
                      _menuItem(customOption, 'Custom'),
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Custom frequency (seconds)',
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
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.center_focus_strong),
                    title: Text(
                      _hasCalibration
                          ? 'Recalibrate neutral posture'
                          : 'Calibrate neutral posture',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sit upright and save the current phone angle.',
                        ),
                        const SizedBox(height: 6),
                        _calibrationDetails(),
                      ],
                    ),
                    trailing: _calibrating
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap:
                        _saving ||
                            _calibrating ||
                            _applyingImmediateSetting ||
                            _changingMonitoringState
                        ? null
                        : _calibrate,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _calibrationDetails() {
    final calibration = _calibration;
    if (calibration == null || !calibration.isValid) {
      return const Text('Not calibrated', key: Key('calibrationDiagnostics'));
    }
    final thresholds = calculatePostureThresholds(
      calibration.neutralPhoneAngle,
    );
    return Text(
      'Neutral angle: ${calibration.neutralPhoneAngle.round()}\u00b0\n'
      'Bad posture below: ${thresholds.badEnterAngle.round()}\u00b0\n'
      'Return to good above: ${thresholds.goodExitAngle.round()}\u00b0',
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
