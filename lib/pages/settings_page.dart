import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../services/preferences_service.dart';

class Settings extends StatefulWidget {
  const Settings({
    super.key,
    required this.store,
    required this.onCalibrateNeutral,
    this.onSettingsSaved,
    this.loadMonitoringState,
    this.onStartMonitoring,
    this.onStopMonitoring,
    this.initialHasCalibration = false,
  });

  final SettingsStore store;
  final Future<bool> Function() onCalibrateNeutral;
  final Future<void> Function(AppSettings settings)? onSettingsSaved;
  final Future<bool> Function()? loadMonitoringState;
  final Future<MonitoringControlResult> Function()? onStartMonitoring;
  final Future<MonitoringControlResult> Function()? onStopMonitoring;
  final bool initialHasCalibration;

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
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
  bool _monitoringActive = false;
  bool _changingMonitoringState = false;
  bool _calibrating = false;
  late bool _hasCalibration;
  String? _loadWarning;

  @override
  void initState() {
    super.initState();
    _hasCalibration = widget.initialHasCalibration;
    _load();
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
    _customDelayController.dispose();
    _customFrequencyController.dispose();
    super.dispose();
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
    if (!selected || !_settings.alertsEnabled) return null;
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
      if (saved) setState(() => _hasCalibration = true);
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

  Future<void> _changeMonitoringState() async {
    if (_changingMonitoringState) return;
    final callback = _monitoringActive
        ? widget.onStopMonitoring
        : widget.onStartMonitoring;
    if (callback == null) return;

    setState(() => _changingMonitoringState = true);
    try {
      final result = await callback();
      if (!mounted) return;
      setState(() => _monitoringActive = result.isActive);
      if (result.message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message!)));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not change monitoring state: $error')),
      );
    } finally {
      if (mounted) setState(() => _changingMonitoringState = false);
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
                onPressed: _saving ? null : _save,
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _monitoringActive
                                    ? Icons.sensors
                                    : Icons.sensors_off,
                                color: _monitoringActive
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _monitoringActive
                                      ? 'Monitoring active'
                                      : 'Monitoring stopped',
                                  key: const Key('settingsMonitoringState'),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            key: const Key('settingsMonitoringButton'),
                            onPressed:
                                _saving ||
                                    _changingMonitoringState ||
                                    (_monitoringActive
                                        ? widget.onStopMonitoring == null
                                        : widget.onStartMonitoring == null)
                                ? null
                                : _changeMonitoringState,
                            icon: _changingMonitoringState
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _monitoringActive
                                        ? Icons.stop_circle_outlined
                                        : Icons.play_circle_outline,
                                  ),
                            label: Text(
                              _monitoringActive
                                  ? 'Stop Monitoring'
                                  : 'Start Monitoring',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Posture alerts'),
                    subtitle: const Text(
                      'Monitoring continues when alerts are disabled.',
                    ),
                    value: _settings.alertsEnabled,
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              _settings = _settings.copyWith(
                                alertsEnabled: value,
                              );
                            });
                          },
                  ),
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
                    onChanged: !_settings.alertsEnabled || _saving
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
                      enabled: _settings.alertsEnabled && !_saving,
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
                    onChanged: !_settings.alertsEnabled || _saving
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
                      enabled: _settings.alertsEnabled && !_saving,
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
                    subtitle: const Text(
                      'Sit upright and save the current phone angle.',
                    ),
                    trailing: _calibrating
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _saving || _calibrating ? null : _calibrate,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Posture Guard uses your camera only while the app is open '
                    'to improve posture detection. When the app is closed or in '
                    'the background, monitoring continues using your phone angle.',
                  ),
                ],
              ),
            ),
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
