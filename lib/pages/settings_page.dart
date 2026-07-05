import 'package:flutter/material.dart';

class Settings extends StatefulWidget {
  const Settings({
    super.key,
    required this.initialAlertDelaySeconds,
    required this.initialAlertFrequencySeconds,
    required this.initialAlertsEnabled,
  });

  final int initialAlertDelaySeconds;
  final int initialAlertFrequencySeconds;
  final bool initialAlertsEnabled;

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  late int alertDelaySeconds;
  late int alertFrequencySeconds;
  late bool alertsEnabled;

  late int selectedDelayOption;
  late int selectedFrequencyOption;

  final TextEditingController customDelayController = TextEditingController();
  final TextEditingController customFrequencyController =
      TextEditingController();

  static const int customOption = -1;

  @override
  void initState() {
    super.initState();

    alertDelaySeconds = widget.initialAlertDelaySeconds;
    alertFrequencySeconds = widget.initialAlertFrequencySeconds;
    alertsEnabled = widget.initialAlertsEnabled;

    selectedDelayOption = [10, 30, 60].contains(alertDelaySeconds)
        ? alertDelaySeconds
        : customOption;

    selectedFrequencyOption = [60, 300, 600].contains(alertFrequencySeconds)
        ? alertFrequencySeconds
        : customOption;

    customDelayController.text = alertDelaySeconds.toString();
    customFrequencyController.text = alertFrequencySeconds.toString();
  }

  @override
  void dispose() {
    customDelayController.dispose();
    customFrequencyController.dispose();
    super.dispose();
  }

  void saveAndGoBack() {
    Navigator.pop(
      context,
      SettingsResult(
        alertDelaySeconds: alertDelaySeconds,
        alertFrequencySeconds: alertFrequencySeconds,
        alertsEnabled: alertsEnabled,
      ),
    );
  }

  void updateCustomDelay(String value) {
    final customValue = int.tryParse(value);

    if (customValue == null || customValue <= 0) return;

    setState(() {
      selectedDelayOption = customOption;
      alertDelaySeconds = customValue;
    });
  }

  void updateCustomFrequency(String value) {
    final customValue = int.tryParse(value);

    if (customValue == null || customValue <= 0) return;

    setState(() {
      selectedFrequencyOption = customOption;
      alertFrequencySeconds = customValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
                child: Column(
                  children: [
                    SizedBox(
                      height: 70,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Center(
                            child: Text(
                              'Settings',
                              style: TextStyle(fontSize: 50),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: FloatingActionButton(
                                onPressed: saveAndGoBack,
                                child: const Icon(Icons.arrow_back),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Alert delay',
                            style: TextStyle(fontSize: 25),
                          ),

                          RadioListTile<int>(
                            title: const Text('10 sec'),
                            value: 10,
                            groupValue: selectedDelayOption,
                            onChanged: alertsEnabled
                                ? (value) {
                                    setState(() {
                                      selectedDelayOption = value!;
                                      alertDelaySeconds = value;
                                      customDelayController.text =
                                          value.toString();
                                    });
                                  }
                                : null,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                          ),

                          RadioListTile<int>(
                            title: const Text('30 sec'),
                            value: 30,
                            groupValue: selectedDelayOption,
                            onChanged: alertsEnabled
                                ? (value) {
                                    setState(() {
                                      selectedDelayOption = value!;
                                      alertDelaySeconds = value;
                                      customDelayController.text =
                                          value.toString();
                                    });
                                  }
                                : null,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                          ),

                          RadioListTile<int>(
                            title: const Text('1 min'),
                            value: 60,
                            groupValue: selectedDelayOption,
                            onChanged: alertsEnabled
                                ? (value) {
                                    setState(() {
                                      selectedDelayOption = value!;
                                      alertDelaySeconds = value;
                                      customDelayController.text =
                                          value.toString();
                                    });
                                  }
                                : null,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                          ),

                          RadioListTile<int>(
                            value: customOption,
                            groupValue: selectedDelayOption,
                            onChanged: alertsEnabled
                                ? (value) {
                                    updateCustomDelay(
                                      customDelayController.text,
                                    );
                                  }
                                : null,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                            title: Row(
                              children: [
                                const Text('Custom: '),
                                SizedBox(
                                  width: 80,
                                  child: TextField(
                                    controller: customDelayController,
                                    enabled: alertsEnabled,
                                    keyboardType: TextInputType.number,
                                    onTap: () {
                                      setState(() {
                                        selectedDelayOption = customOption;
                                      });
                                    },
                                    onChanged: updateCustomDelay,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text('sec'),
                              ],
                            ),
                          ),

                          const SizedBox(height: 25),

                          const Text(
                            'Alert frequency',
                            style: TextStyle(fontSize: 25),
                          ),

                          RadioListTile<int>(
                            title: const Text('1 min'),
                            value: 60,
                            groupValue: selectedFrequencyOption,
                            onChanged: alertsEnabled
                                ? (value) {
                                    setState(() {
                                      selectedFrequencyOption = value!;
                                      alertFrequencySeconds = value;
                                      customFrequencyController.text =
                                          value.toString();
                                    });
                                  }
                                : null,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                          ),

                          RadioListTile<int>(
                            title: const Text('5 min'),
                            value: 300,
                            groupValue: selectedFrequencyOption,
                            onChanged: alertsEnabled
                                ? (value) {
                                    setState(() {
                                      selectedFrequencyOption = value!;
                                      alertFrequencySeconds = value;
                                      customFrequencyController.text =
                                          value.toString();
                                    });
                                  }
                                : null,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                          ),

                          RadioListTile<int>(
                            title: const Text('10 min'),
                            value: 600,
                            groupValue: selectedFrequencyOption,
                            onChanged: alertsEnabled
                                ? (value) {
                                    setState(() {
                                      selectedFrequencyOption = value!;
                                      alertFrequencySeconds = value;
                                      customFrequencyController.text =
                                          value.toString();
                                    });
                                  }
                                : null,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                          ),

                          RadioListTile<int>(
                            value: customOption,
                            groupValue: selectedFrequencyOption,
                            onChanged: alertsEnabled
                                ? (value) {
                                    updateCustomFrequency(
                                      customFrequencyController.text,
                                    );
                                  }
                                : null,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                            title: Row(
                              children: [
                                const Text('Custom: '),
                                SizedBox(
                                  width: 80,
                                  child: TextField(
                                    controller: customFrequencyController,
                                    enabled: alertsEnabled,
                                    keyboardType: TextInputType.number,
                                    onTap: () {
                                      setState(() {
                                        selectedFrequencyOption = customOption;
                                      });
                                    },
                                    onChanged: updateCustomFrequency,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text('sec'),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: FloatingActionButton(
                      heroTag: 'disableButton',
                      onPressed: () {
                        setState(() {
                          alertsEnabled = !alertsEnabled;
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        alertsEnabled ? 'Disable' : 'Enable',
                        style: const TextStyle(fontSize: 25),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: FloatingActionButton(
                      heroTag: 'saveButton',
                      onPressed: saveAndGoBack,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(fontSize: 25),
                      ),
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

class SettingsResult {
  const SettingsResult({
    required this.alertDelaySeconds,
    required this.alertFrequencySeconds,
    required this.alertsEnabled,
  });

  final int alertDelaySeconds;
  final int alertFrequencySeconds;
  final bool alertsEnabled;
}