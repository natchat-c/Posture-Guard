import 'package:flutter/material.dart';

import '../l10n/locale_controller.dart';
import '../services/camera_privacy_service.dart';
import '../services/user_data_deletion_service.dart';

enum PrivacySettingsResult { dataDeleted }

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({
    super.key,
    required this.cameraCoordinator,
    required this.deletionService,
    required this.onCameraAssistChanged,
    required this.onPrepareForDataDeletion,
    required this.onDataDeletionFailed,
    required this.onDataDeleted,
  });

  final CameraAssistPermissionCoordinator cameraCoordinator;
  final UserDataDeletionService deletionService;
  final Future<void> Function(bool enabled) onCameraAssistChanged;
  final Future<void> Function() onPrepareForDataDeletion;
  final Future<void> Function() onDataDeletionFailed;
  final Future<void> Function() onDataDeleted;

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _cameraEnabled = false;
  bool _loading = true;
  bool _deleting = false;
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await widget.cameraCoordinator.isEnabled();
    if (!mounted) return;
    setState(() {
      _cameraEnabled = enabled;
      _loading = false;
    });
  }

  Future<void> _turnOffCamera() async {
    await widget.cameraCoordinator.disable();
    await widget.onCameraAssistChanged(false);
    if (!mounted) return;
    setState(() => _cameraEnabled = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.cameraAssistanceTurnedOff)),
    );
  }

  Future<void> _confirmDeletion() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteDataConfirmTitle),
        content: Text(l10n.deleteDataConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirmDeleteDataButton'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.deleteDataAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _deleteData();
  }

  Future<void> _deleteData() async {
    setState(() => _deleting = true);
    await widget.onPrepareForDataDeletion();
    final result = await widget.deletionService.deleteCurrentUserData();
    if (!result.succeeded) await widget.onDataDeletionFailed();
    if (!mounted) return;
    if (result.succeeded) {
      await widget.onDataDeleted();
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _deleted = true;
        _cameraEnabled = false;
      });
      return;
    }
    setState(() => _deleting = false);
    final message = switch (result.status) {
      UserDataDeletionStatus.noAuthenticatedUser =>
        context.l10n.deleteDataNoUser,
      UserDataDeletionStatus.cloudDeleteFailed =>
        context.l10n.deleteDataCloudFailed,
      UserDataDeletionStatus.authDeleteFailed =>
        context.l10n.deleteDataAuthFailed,
      UserDataDeletionStatus.localDeleteFailed =>
        context.l10n.deleteDataLocalFailed,
      UserDataDeletionStatus.success => context.l10n.deleteDataSuccess,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_deleted) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.cameraAndPrivacy)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.deleteDataSuccess,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, PrivacySettingsResult.dataDeleted),
                  child: Text(l10n.done),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cameraAndPrivacy)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.privacyPageIntroduction,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const Divider(height: 40),
                          _PrivacySection(
                            title: l10n.privacyPageCameraUseTitle,
                            children: [
                              _PrivacyParagraphs(
                                l10n.privacyPageCameraUseIntroduction,
                              ),
                              _PrivacyBulletList(
                                l10n.privacyPageCameraUseItems,
                              ),
                              const SizedBox(height: 12),
                              _PrivacyParagraphs(
                                l10n.privacyPageCameraUseClosing,
                              ),
                              const SizedBox(height: 4),
                              OutlinedButton.icon(
                                key: const Key('turnOffCameraAssistanceButton'),
                                onPressed: _cameraEnabled || _deleting
                                    ? (_deleting ? null : _turnOffCamera)
                                    : null,
                                icon: const Icon(Icons.videocam_off_outlined),
                                label: Text(l10n.turnOffCameraAssistance),
                              ),
                            ],
                          ),
                          _PrivacySection(
                            title: l10n.privacyPageCameraPermissionTitle,
                            children: [
                              _PrivacyParagraphs(
                                l10n.privacyPageCameraPermissionBody,
                              ),
                            ],
                          ),
                          _PrivacySection(
                            title: l10n.privacyPageDataStoredTitle,
                            children: [
                              _PrivacyParagraphs(
                                l10n.privacyPageDataStoredIntroduction,
                              ),
                              _PrivacyBulletList(
                                l10n.privacyPageDataStoredItems,
                              ),
                              const SizedBox(height: 12),
                              _PrivacyParagraphs(
                                l10n.privacyPageDataStoredClosing,
                              ),
                            ],
                          ),
                          _PrivacySection(
                            title: l10n.privacyPageFirebaseTitle,
                            children: [
                              _PrivacyParagraphs(l10n.privacyPageFirebaseBody),
                            ],
                          ),
                          _PrivacySection(
                            title: l10n.privacyPageChoicesTitle,
                            children: [
                              _PrivacyBulletList(l10n.privacyPageChoicesItems),
                            ],
                          ),
                          _PrivacySection(
                            title: l10n.privacyPageDeleteTitle,
                            children: [
                              _PrivacyParagraphs(l10n.privacyPageDeleteBody),
                              const SizedBox(height: 4),
                              FilledButton.icon(
                                key: const Key('deleteMyDataButton'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                ),
                                onPressed: _deleting ? null : _confirmDeletion,
                                icon: _deleting
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.delete_forever_outlined),
                                label: Text(
                                  _deleting
                                      ? l10n.deletingData
                                      : l10n.deleteMyData,
                                ),
                              ),
                            ],
                          ),
                          _PrivacySection(
                            title: l10n.privacyPageCameraIndicatorTitle,
                            children: [
                              _PrivacyParagraphs(
                                l10n.privacyPageCameraIndicatorBody,
                              ),
                            ],
                          ),
                          _PrivacySection(
                            title: l10n.privacyPageConsentTitle,
                            children: [
                              _PrivacyParagraphs(l10n.privacyPageConsentBody),
                            ],
                          ),
                          _PrivacySection(
                            title: l10n.privacyPagePolicyTitle,
                            showDivider: false,
                            children: [
                              _PrivacyParagraphs(l10n.privacyPagePolicyBody),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({
    required this.title,
    required this.children,
    this.showDivider = true,
  });

  final String title;
  final List<Widget> children;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ...children,
        if (showDivider) const Divider(height: 40),
      ],
    );
  }
}

class _PrivacyParagraphs extends StatelessWidget {
  const _PrivacyParagraphs(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final paragraphs = text.split('\n\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < paragraphs.length; index++) ...[
          Text(paragraphs[index]),
          if (index != paragraphs.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _PrivacyBulletList extends StatelessWidget {
  const _PrivacyBulletList(this.items);

  final String items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items.split('\n'))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•'),
                const SizedBox(width: 10),
                Expanded(child: Text(item)),
              ],
            ),
          ),
      ],
    );
  }
}
