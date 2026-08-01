import 'package:flutter/material.dart';

import '../l10n/locale_controller.dart';
import '../services/calibration_service.dart';
import '../widgets/responsive_layout.dart';

class TutorialPage extends StatefulWidget {
  const TutorialPage({
    super.key,
    this.isReplay = false,
    this.onCompleted,
    this.calibrationService,
  });

  final bool isReplay;
  final Future<void> Function()? onCompleted;
  final PostureCalibrationService? calibrationService;

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage> {
  static const int _pageCount = 3;

  late final PageController _controller;
  PostureCalibrationService? _calibrationService;
  late int _page;
  bool _finishing = false;
  bool _calibrating = false;
  bool? _calibrationSucceeded;

  @override
  void initState() {
    super.initState();
    _page = widget.isReplay ? 2 : 0;
    _controller = PageController(initialPage: _page);
    _calibrationService = widget.calibrationService;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _calibrate() async {
    if (_calibrating) return;
    setState(() {
      _calibrating = true;
      _calibrationSucceeded = null;
    });
    final result = await (_calibrationService ??= PostureCalibrationService())
        .calibrate();
    if (!mounted) return;
    setState(() {
      _calibrating = false;
      _calibrationSucceeded = result.success;
    });
  }

  Future<void> _goTo(int page) async {
    await _controller.animateToPage(
      page.clamp(0, _pageCount - 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _next() async {
    if (_page < _pageCount - 1) {
      await _goTo(_page + 1);
      return;
    }

    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      if (widget.isReplay) {
        if (mounted) Navigator.pop(context);
      } else {
        await widget.onCompleted?.call();
      }
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Widget _pageShell({
    required int pageIndex,
    required IconData icon,
    required String title,
    required String body,
    Widget? action,
    Widget? feedback,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.responsiveHorizontalPadding;
        final isShort = constraints.isShortPhone;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              key: Key('tutorialPageScroll$pageIndex'),
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                padding,
                isShort ? 16 : 36,
                padding,
                24,
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    size: isShort ? 64 : 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(height: isShort ? 16 : 28),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (action != null) ...[const SizedBox(height: 24), action],
                  if (feedback != null) ...[
                    const SizedBox(height: 18),
                    feedback,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _postureStatesPage() {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.responsiveHorizontalPadding;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              key: const Key('tutorialPageScroll2'),
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(padding, 16, padding, 20),
              child: Column(
                children: [
                  Icon(
                    Icons.accessibility_new_rounded,
                    size: constraints.isShortPhone ? 52 : 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.knowPostureTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 14),
                  _PostureStateCard(
                    key: const Key('tutorialGoodState'),
                    color: Colors.green,
                    icon: Icons.sentiment_satisfied_alt_rounded,
                    text: l10n.goodPostureExplanation,
                  ),
                  _PostureStateCard(
                    key: const Key('tutorialWarningState'),
                    color: Colors.orange,
                    icon: Icons.warning_amber_rounded,
                    text: l10n.warningPostureExplanation,
                  ),
                  _PostureStateCard(
                    key: const Key('tutorialBadState'),
                    color: Colors.red,
                    icon: Icons.sentiment_dissatisfied_rounded,
                    text: l10n.badPostureExplanation,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPage(int index) {
    final l10n = context.l10n;
    return switch (index) {
      0 => _pageShell(
        pageIndex: 0,
        icon: Icons.health_and_safety_outlined,
        title: l10n.welcomeTitle,
        body: l10n.welcomeBody,
      ),
      1 => _pageShell(
        pageIndex: 1,
        icon: Icons.center_focus_strong,
        title: l10n.calibrationTitle,
        body: l10n.calibrationBody,
        action: FilledButton.icon(
          key: const Key('tutorialCalibrationButton'),
          onPressed: _calibrating ? null : _calibrate,
          icon: _calibrating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.phone_android),
          label: Text(l10n.calibrationButton),
        ),
        feedback: _calibrationSucceeded == null
            ? null
            : _SetupFeedback(
                success: _calibrationSucceeded!,
                message: _calibrationSucceeded!
                    ? l10n.calibrationSuccess
                    : l10n.calibrationError,
              ),
      ),
      _ => _postureStatesPage(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isLast = _page == _pageCount - 1;

    return Scaffold(
      appBar: widget.isReplay ? AppBar(title: Text(l10n.helpTooltip)) : null,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                key: const Key('tutorialPageView'),
                controller: _controller,
                physics: const ClampingScrollPhysics(),
                itemCount: _pageCount,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) => _buildPage(index),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pageCount,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: index == _page ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: index == _page
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final showBack = _page > 0 && !widget.isReplay;
                final padding = constraints.responsiveHorizontalPadding;
                return Padding(
                  key: const Key('tutorialBottomActions'),
                  padding: EdgeInsets.fromLTRB(padding, 12, padding, 16),
                  child: Row(
                    children: [
                      if (showBack)
                        Expanded(
                          child: TextButton.icon(
                            key: const Key('tutorialBackButton'),
                            onPressed: _finishing
                                ? null
                                : () => _goTo(_page - 1),
                            icon: const Icon(Icons.arrow_back),
                            label: Text(l10n.back, textAlign: TextAlign.center),
                          ),
                        )
                      else
                        const Spacer(),
                      if (showBack) const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const Key('tutorialNextButton'),
                          onPressed: _finishing ? null : _next,
                          child: Text(
                            isLast
                                ? (widget.isReplay
                                      ? l10n.done
                                      : l10n.continueButton)
                                : l10n.next,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PostureStateCard extends StatelessWidget {
  const _PostureStateCard({
    super.key,
    required this.color,
    required this.icon,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _SetupFeedback extends StatelessWidget {
  const _SetupFeedback({required this.success, required this.message});

  final bool success;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = success ? Colors.green : Theme.of(context).colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(success ? Icons.check_circle : Icons.info_outline, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
