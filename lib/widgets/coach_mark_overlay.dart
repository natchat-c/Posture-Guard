import 'dart:math' as math;

import 'package:flutter/material.dart';

enum CoachMarkSpotlightShape { roundedRectangle, circle }

class CoachMarkOverlay extends StatefulWidget {
  const CoachMarkOverlay({
    super.key,
    required this.targetKey,
    required this.targetIdentity,
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
    this.spotlightShape = CoachMarkSpotlightShape.roundedRectangle,
    this.scrollAlignment = 0.3,
    this.nextButtonKey,
    this.backButtonKey,
    this.skipButtonKey,
  }) : assert(body != null || content != null);

  static const spotlightKey = Key('coachMarkSpotlight');

  final GlobalKey? targetKey;
  final Object targetIdentity;
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
  final CoachMarkSpotlightShape spotlightShape;
  final double scrollAlignment;
  final Key? nextButtonKey;
  final Key? backButtonKey;
  final Key? skipButtonKey;

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay> {
  static const _spotlightPadding = 8.0;
  static const _layoutRetryCount = 12;

  Rect? _targetRect;
  bool _measurementScheduled = false;
  int _measurementGeneration = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant CoachMarkOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetKey != widget.targetKey ||
        oldWidget.targetIdentity != widget.targetIdentity ||
        oldWidget.scrollAlignment != widget.scrollAlignment) {
      _measurementGeneration++;
      _targetRect = null;
    }
    _scheduleMeasurement();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _measurementGeneration++;
    _targetRect = null;
    _scheduleMeasurement();
  }

  void _scheduleMeasurement() {
    if (_measurementScheduled || widget.targetKey == null) return;
    _measurementScheduled = true;
    final generation = _measurementGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _measurementScheduled = false;
      await _measureTarget(generation);
      if (mounted && generation != _measurementGeneration) {
        _scheduleMeasurement();
      }
    });
  }

  Future<void> _measureTarget(int generation) async {
    for (var attempt = 0; attempt < _layoutRetryCount; attempt++) {
      if (!mounted || generation != _measurementGeneration) return;
      final targetContext = widget.targetKey?.currentContext;
      final targetObject = targetContext?.findRenderObject();
      final overlayObject = context.findRenderObject();
      if (targetContext == null ||
          !targetContext.mounted ||
          targetObject is! RenderBox ||
          overlayObject is! RenderBox ||
          !targetObject.attached ||
          !targetObject.hasSize ||
          targetObject.size.isEmpty ||
          !overlayObject.attached ||
          !overlayObject.hasSize) {
        await WidgetsBinding.instance.endOfFrame;
        continue;
      }

      if (attempt == 0) {
        await Scrollable.ensureVisible(
          targetContext,
          alignment: widget.scrollAlignment.clamp(0.0, 1.0),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
        if (!mounted || generation != _measurementGeneration) return;
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || generation != _measurementGeneration) return;
      }

      final settledTargetObject = widget.targetKey?.currentContext
          ?.findRenderObject();
      final settledOverlayObject = context.findRenderObject();
      if (settledTargetObject is! RenderBox ||
          settledOverlayObject is! RenderBox ||
          !settledTargetObject.attached ||
          !settledTargetObject.hasSize ||
          settledTargetObject.size.isEmpty ||
          !settledOverlayObject.attached ||
          !settledOverlayObject.hasSize) {
        await WidgetsBinding.instance.endOfFrame;
        continue;
      }

      final targetOrigin = settledTargetObject.localToGlobal(Offset.zero);
      final overlayOrigin = settledOverlayObject.localToGlobal(Offset.zero);
      final rect = (targetOrigin - overlayOrigin) & settledTargetObject.size;
      if (!rect.isFinite || rect.isEmpty) {
        await WidgetsBinding.instance.endOfFrame;
        continue;
      }

      if (!mounted || generation != _measurementGeneration) return;
      if (_targetRect != rect) setState(() => _targetRect = rect);
      return;
    }

    if (mounted &&
        generation == _measurementGeneration &&
        _targetRect != null) {
      setState(() => _targetRect = null);
    }
  }

  Rect? _spotlightRect(Size size) {
    final target = _targetRect;
    if (target == null) return null;
    const edgeGap = 4.0;
    final inflated = target.inflate(_spotlightPadding);
    final left = inflated.left.clamp(edgeGap, size.width - edgeGap);
    final top = inflated.top.clamp(edgeGap, size.height - edgeGap);
    final right = inflated.right.clamp(edgeGap, size.width - edgeGap);
    final bottom = inflated.bottom.clamp(edgeGap, size.height - edgeGap);
    if (right <= left || bottom <= top) return null;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasurement();
    return LayoutBuilder(
      builder: (context, constraints) {
        const outerGap = 12.0;
        const targetGap = 12.0;
        final size = constraints.biggest;
        final spotlightRect = _spotlightRect(size);
        final targetIsPending = widget.targetKey != null && _targetRect == null;
        final safePadding = MediaQuery.paddingOf(context);
        final safeTop = safePadding.top + outerGap;
        final safeBottom = size.height - safePadding.bottom - outerGap;
        final safeLeft = safePadding.left + outerGap;
        final safeRight = size.width - safePadding.right - outerGap;
        final safeHeight = math.max(1.0, safeBottom - safeTop);
        final maxPreferredHeight = safeHeight * 0.68;

        late final double cardTop;
        late final double maxCardHeight;
        if (spotlightRect == null) {
          maxCardHeight = maxPreferredHeight;
          cardTop = safeBottom - maxCardHeight;
        } else {
          final availableAbove = math.max(
            0.0,
            spotlightRect.top - targetGap - safeTop,
          );
          final availableBelow = math.max(
            0.0,
            safeBottom - spotlightRect.bottom - targetGap,
          );
          final putBelow = availableBelow >= availableAbove;
          final selectedSpace = putBelow ? availableBelow : availableAbove;
          if (selectedSpace >= 160) {
            maxCardHeight = math.min(maxPreferredHeight, selectedSpace);
            cardTop = putBelow
                ? spotlightRect.bottom + targetGap
                : spotlightRect.top - targetGap - maxCardHeight;
          } else {
            maxCardHeight = maxPreferredHeight;
            cardTop = safeTop + (safeHeight - maxCardHeight) / 2;
          }
        }

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CoachMarkPainter(
                    spotlightRect,
                    widget.spotlightShape,
                  ),
                ),
              ),
            ),
            ..._outsideTargetBarriers(size, _targetRect),
            if (spotlightRect != null)
              Positioned.fromRect(
                rect: spotlightRect,
                child: const IgnorePointer(
                  child: SizedBox.expand(key: CoachMarkOverlay.spotlightKey),
                ),
              ),
            if (!targetIsPending)
              Positioned(
                left: safeLeft,
                right: size.width - safeRight,
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
                                    widget.title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  widget.content ?? Text(widget.body!),
                                  const SizedBox(height: 12),
                                  Text(
                                    '${widget.currentStep + 1} / '
                                    '${widget.totalSteps}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            key: const Key('coachMarkActions'),
                            children: [
                              Expanded(
                                child: TextButton(
                                  key: widget.skipButtonKey,
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                  ),
                                  onPressed: widget.onSkip,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(widget.skipLabel),
                                  ),
                                ),
                              ),
                              if (widget.onBack != null) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    key: widget.backButtonKey,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(48, 48),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                    ),
                                    onPressed: widget.onBack,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(widget.backLabel),
                                    ),
                                  ),
                                ),
                              ],
                              if (widget.onNext != null) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    key: widget.nextButtonKey,
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(48, 48),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                    ),
                                    onPressed: widget.onNext,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(widget.nextLabel),
                                    ),
                                  ),
                                ),
                              ],
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

  List<Widget> _outsideTargetBarriers(Size size, Rect? target) {
    if (target == null) {
      return const [Positioned.fill(child: _CoachMarkPointerBarrier())];
    }
    final visible = target.intersect(Offset.zero & size);
    if (visible.isEmpty) {
      return const [Positioned.fill(child: _CoachMarkPointerBarrier())];
    }
    return [
      if (visible.top > 0)
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: visible.top,
          child: const _CoachMarkPointerBarrier(),
        ),
      if (visible.bottom < size.height)
        Positioned(
          left: 0,
          right: 0,
          top: visible.bottom,
          bottom: 0,
          child: const _CoachMarkPointerBarrier(),
        ),
      if (visible.left > 0)
        Positioned(
          left: 0,
          top: visible.top,
          width: visible.left,
          height: visible.height,
          child: const _CoachMarkPointerBarrier(),
        ),
      if (visible.right < size.width)
        Positioned(
          left: visible.right,
          right: 0,
          top: visible.top,
          height: visible.height,
          child: const _CoachMarkPointerBarrier(),
        ),
    ];
  }
}

class _CoachMarkPointerBarrier extends StatelessWidget {
  const _CoachMarkPointerBarrier();

  @override
  Widget build(BuildContext context) {
    return const AbsorbPointer(child: ColoredBox(color: Colors.transparent));
  }
}

class _CoachMarkPainter extends CustomPainter {
  const _CoachMarkPainter(this.spotlight, this.shape);

  final Rect? spotlight;
  final CoachMarkSpotlightShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (spotlight case final rect?) {
      switch (shape) {
        case CoachMarkSpotlightShape.roundedRectangle:
          overlay.addRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(16)),
          );
        case CoachMarkSpotlightShape.circle:
          overlay.addOval(rect);
      }
    }
    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withValues(alpha: 0.72),
    );
  }

  @override
  bool shouldRepaint(covariant _CoachMarkPainter oldDelegate) {
    return oldDelegate.spotlight != spotlight || oldDelegate.shape != shape;
  }
}
