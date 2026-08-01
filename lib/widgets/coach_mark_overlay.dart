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
    final targetIsNearTop =
        (target?.center.dy ?? 0) < MediaQuery.sizeOf(context).height / 2;
    final maxCardHeight = MediaQuery.sizeOf(context).height * 0.52;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _CoachMarkPainter(target)),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: targetIsNearTop ? null : 16,
          bottom: targetIsNearTop ? 16 : null,
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxCardHeight),
              child: Card(
                elevation: 8,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(18),
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
                      const SizedBox(height: 8),
                      Wrap(
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
        ),
      ],
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
