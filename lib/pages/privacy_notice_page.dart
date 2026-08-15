import 'package:flutter/material.dart';

import '../l10n/locale_controller.dart';

enum PrivacyNoticeChoice { continueToApp, sensorsOnly }

class PrivacyNoticePage extends StatelessWidget {
  const PrivacyNoticePage({super.key, required this.onChoice});

  final Future<void> Function(PrivacyNoticeChoice choice) onChoice;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyNoticeTitle)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.camera_front_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          l10n.privacyNoticeBody,
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.privacyNoticeDetail,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        FilledButton(
                          key: const Key('privacyNoticeContinueButton'),
                          onPressed: () =>
                              onChoice(PrivacyNoticeChoice.continueToApp),
                          child: Text(l10n.continueLabel),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          key: const Key('privacyNoticeSensorsOnlyButton'),
                          onPressed: () =>
                              onChoice(PrivacyNoticeChoice.sensorsOnly),
                          child: Text(l10n.useSensorsOnly),
                        ),
                      ],
                    ),
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

Future<bool> showCameraPermissionExplanationDialog(BuildContext context) async {
  final l10n = context.l10n;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.cameraExplanationTitle),
          content: Text(l10n.cameraExplanationBody),
          actions: [
            TextButton(
              key: const Key('cameraExplanationNotNowButton'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.notNow),
            ),
            FilledButton(
              key: const Key('cameraExplanationContinueButton'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.continueLabel),
            ),
          ],
        ),
      ) ??
      false;
}
