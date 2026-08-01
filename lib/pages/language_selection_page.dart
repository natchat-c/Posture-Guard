import 'package:flutter/material.dart';

import '../l10n/locale_controller.dart';

class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key, required this.onLanguageSelected});

  final Future<void> Function(String code) onLanguageSelected;

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  String _selectedCode = 'en';
  bool _saving = false;

  Future<void> _continue() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onLanguageSelected(_selectedCode);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.language,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 28),
              Text(
                l10n.chooseLanguage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.chooseLanguageThai,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 28),
              RadioGroup<String>(
                groupValue: _selectedCode,
                onChanged: (value) {
                  if (_saving || value == null) return;
                  setState(() => _selectedCode = value);
                },
                child: Column(
                  children: [
                    RadioListTile<String>(
                      key: const Key('languageEnglishOption'),
                      value: 'en',
                      title: Text(l10n.english),
                    ),
                    RadioListTile<String>(
                      key: const Key('languageThaiOption'),
                      value: 'th',
                      title: Text(l10n.thai),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('languageContinueButton'),
                onPressed: _saving ? null : _continue,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        localizationsForLanguage(_selectedCode).continueButton,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
