import 'dart:math' as math;

import 'package:flutter/material.dart';

class CoachMarkOverlay extends StatelessWidget {
  const CoachMarkOverlay({
    super.key,
    required this.target,
    required this.title,
    required this.currentStep,
    required this.totalSteps,
    required this.backLabel,
    required this.nextLabel,
    required this.skipLabel,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
    this.body,
    this.content,
    this.nextButtonKey,
    this.backButtonKey,
    this.skipButtonKey,
  }) : assert(body != null || content != null);

  final Rect? target;
  final String title;
  final String? body;
  final Widget? content;
  final int currentStep;
  final int totalSteps;
  final String backLabel;
  final String nextLabel;
  final String skipLabel;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final VoidCallback onSkip;
  final Key? nextButtonKey;
  final Key? backButtonKey;
  final Key? skipButtonKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const outerGap = 12.0;
        const targetGap = 12.0;
        final safePadding = MediaQuery.paddingOf(context);
        final safeTop = safePadding.top + outerGap;
        final safeBottom =
            constraints.maxHeight - safePadding.bottom - outerGap;
        final safeLeft = safePadding.left + outerGap;
        final safeRight = safePadding.right + outerGap;
        final safeHeight = math.max(1.0, safeBottom - safeTop);
        final targetRect = target;
        final maxPreferredHeight = safeHeight * 0.68;

        late final double cardTop;
        late final double maxCardHeight;
        if (targetRect == null) {
          maxCardHeight = maxPreferredHeight;
          cardTop = safeBottom - maxCardHeight;
        } else {
          final availableAbove = math.max(
            0.0,
            targetRect.top - targetGap - safeTop,
          );
          final availableBelow = math.max(
            0.0,
            safeBottom - targetRect.bottom - targetGap,
          );
          final putBelow = availableBelow >= availableAbove;
          final selectedSpace = putBelow ? availableBelow : availableAbove;
          if (selectedSpace >= 132) {
            maxCardHeight = math.min(maxPreferredHeight, selectedSpace);
            cardTop = putBelow
                ? targetRect.bottom + targetGap
                : targetRect.top - targetGap - maxCardHeight;
          } else {
            maxCardHeight = maxPreferredHeight;
            cardTop = safeTop + (safeHeight - maxCardHeight) / 2;
          }
        }

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _CoachMarkPainter(target)),
              ),
            ),
            Positioned(
              left: safeLeft,
              right: safeRight,
              top: cardTop,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxCardHeight),
                child: Card(
                  key: const Key('coachMarkCard'),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Flexible(
                          child: SingleChildScrollView(
                            key: const Key('coachMarkScrollView'),
                            physics: const ClampingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                content ?? Text(body!),
                                const SizedBox(height: 12),
                                Text('${currentStep + 1} / $totalSteps'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          key: const Key('coachMarkActions'),
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              key: skipButtonKey,
                              onPressed: onSkip,
                              child: Text(skipLabel),
                            ),
                            if (onBack != null)
                              OutlinedButton(
                                key: backButtonKey,
                                onPressed: onBack,
                                child: Text(backLabel),
                              ),
                            if (onNext != null)
                              FilledButton(
                                key: nextButtonKey,
                                onPressed: onNext,
                                child: Text(nextLabel),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CoachMarkPainter extends CustomPainter {
  const _CoachMarkPainter(this.target);

  final Rect? target;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (target case final rect?) {
      overlay.addRRect(
        RRect.fromRectAndRadius(rect.inflate(8), const Radius.circular(16)),
      );
    }
    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withValues(alpha: 0.72),
    );
  }

  @override
  bool shouldRepaint(covariant _CoachMarkPainter oldDelegate) {
    return oldDelegate.target != target;
  }
}
