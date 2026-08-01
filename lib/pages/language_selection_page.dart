import 'package:flutter/material.dart';

import '../l10n/locale_controller.dart';
import '../widgets/responsive_layout.dart';

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
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = constraints.responsiveHorizontalPadding;
            final isShort = constraints.isShortPhone;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  key: const Key('languageSelectionScrollView'),
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(padding, 16, padding, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.language,
                        size: isShort ? 56 : 72,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(height: isShort ? 12 : 24),
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
                      SizedBox(height: isShort ? 12 : 24),
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
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              key: const Key('languageBottomAction'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  key: const Key('languageContinueButton'),
                  onPressed: _saving ? null : _continue,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          localizationsForLanguage(
                            _selectedCode,
                          ).continueButton,
                          textAlign: TextAlign.center,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
