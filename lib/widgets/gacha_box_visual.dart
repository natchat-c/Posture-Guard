import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/locale_controller.dart';
import '../models/cosmetics.dart';
import '../models/gacha_box_visual_config.dart';
import '../services/gacha_service.dart';
import 'cosmetic_widgets.dart';

@immutable
class GachaBoxAssetLayout {
  const GachaBoxAssetLayout({
    required this.baseAsset,
    required this.lidAsset,
    required this.lidPivot,
  });

  static const standard = GachaBoxAssetLayout(
    baseAsset: 'images/boxes/normal_box.png',
    lidAsset: 'images/boxes/normal_lid.png',
    lidPivot: Alignment(0, 0.23),
  );

  static const premium = GachaBoxAssetLayout(
    baseAsset: 'images/boxes/elite_box.png',
    lidAsset: 'images/boxes/elite_lid.png',
    lidPivot: Alignment(0, 0.37),
  );

  final String baseAsset;
  final String lidAsset;
  final Alignment lidPivot;

  static GachaBoxAssetLayout forType(GachaBoxType type) => switch (type) {
    GachaBoxType.standard => standard,
    GachaBoxType.premium => premium,
  };
}

class GachaBoxVisual extends StatelessWidget {
  const GachaBoxVisual({
    super.key,
    required this.type,
    this.progress = 0,
    this.rarity,
    this.reward,
    this.reducedMotion = false,
    this.keyPrefix = 'gachaBox',
    this.config,
  });

  final GachaBoxType type;
  final double progress;
  final CosmeticRarity? rarity;
  final Widget? reward;
  final bool reducedMotion;
  final String keyPrefix;
  final GachaBoxVisualConfig? config;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    final layout = GachaBoxAssetLayout.forType(type);
    final visualConfig =
        config ?? GachaBoxVisualConfigs.finalized.forType(type);
    final colors = Theme.of(context).colorScheme;
    final rarityLevel = (rarity?.starCount ?? 1).toDouble();
    final glowColor = rarityLevel >= 3 ? colors.tertiary : colors.primary;
    final premiumBoost = type == GachaBoxType.premium ? 0.06 : 0.0;
    final frame = GachaVisualFrame.forProgress(
      value,
      reducedMotion: reducedMotion,
    );
    final shake = reducedMotion ? 0.0 : _shakeAmount(value);
    final glowOpacity =
        ((0.16 * frame.leakProgress) + (0.52 * frame.burstProgress)) *
        (0.78 + rarityLevel * 0.07 + premiumBoost) *
        frame.glowFade;
    final particleCount = switch (rarity) {
      CosmeticRarity.oneStar => 3,
      CosmeticRarity.twoStar => 5,
      CosmeticRarity.threeStar => 7,
      CosmeticRarity.fourStar => 10,
      CosmeticRarity.fiveStar => 14,
      null => 0,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final shortest = constraints.biggest.shortestSide;
        final side = shortest.isFinite ? shortest : 320.0;
        final lidOffset = Offset.lerp(
          Offset(visualConfig.lidX, visualConfig.lidY),
          Offset(visualConfig.lidOpenX, visualConfig.lidOpenY),
          frame.lidProgress,
        )!;
        final lidScale = _lerp(
          visualConfig.lidScale,
          visualConfig.lidOpenScale,
          frame.lidProgress,
        );
        final rewardOffset = Offset.lerp(
          Offset(visualConfig.glowX, visualConfig.glowY),
          Offset(visualConfig.rewardX, visualConfig.rewardY),
          frame.rewardProgress,
        )!;
        return RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              if (glowOpacity > 0)
                Center(
                  child: Transform.translate(
                    offset: Offset(
                      visualConfig.glowX * side,
                      visualConfig.glowY * side,
                    ),
                    child: Transform.scale(
                      scale:
                          visualConfig.glowScale *
                          (0.42 + 0.82 * frame.burstProgress),
                      child: Opacity(
                        key: Key('$keyPrefix-glowOpacity-${type.name}'),
                        opacity: glowOpacity.clamp(0.0, 0.92),
                        child: DecoratedBox(
                          key: Key('$keyPrefix-glow-${type.name}'),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white,
                                glowColor.withValues(alpha: 0.78),
                                glowColor.withValues(alpha: 0),
                              ],
                              stops: const [0, 0.38, 1],
                            ),
                          ),
                          child: SizedBox.square(
                            dimension: math.min(190, side * 0.62),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (particleCount > 0 && !reducedMotion)
                CustomPaint(
                  key: Key('$keyPrefix-particles-${type.name}'),
                  painter: _SparklePainter(
                    progress: value,
                    count: particleCount,
                    color: glowColor,
                  ),
                ),
              _shakeLayer(
                shake,
                child: Opacity(
                  key: Key('$keyPrefix-baseOpacity-${type.name}'),
                  opacity: frame.boxOpacity,
                  child: _assetLayer(
                    asset: layout.baseAsset,
                    assetKey: Key('$keyPrefix-base-${type.name}'),
                    scale: visualConfig.baseScale,
                    offset: Offset(
                      visualConfig.baseX * side,
                      visualConfig.baseY * side,
                    ),
                  ),
                ),
              ),
              _shakeLayer(
                shake,
                child: Opacity(
                  key: Key('$keyPrefix-lidOpacity-${type.name}'),
                  opacity: frame.boxOpacity,
                  child: Transform.translate(
                    key: Key('$keyPrefix-lidPosition-${type.name}'),
                    offset: lidOffset * side,
                    child: Transform.rotate(
                      alignment: layout.lidPivot,
                      angle:
                          visualConfig.lidOpenRotationDegrees *
                          math.pi /
                          180 *
                          frame.lidProgress,
                      child: Transform.scale(
                        alignment: layout.lidPivot,
                        scale: lidScale,
                        child: Image.asset(
                          layout.lidAsset,
                          key: Key('$keyPrefix-lid-${type.name}'),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (reward != null && frame.rewardProgress > 0)
                Align(
                  alignment: Alignment.center,
                  child: FractionallySizedBox(
                    widthFactor: 0.60,
                    heightFactor: 0.60,
                    child: Transform.translate(
                      key: Key('$keyPrefix-rewardPosition-${type.name}'),
                      offset: rewardOffset * side,
                      child: Transform.scale(
                        scale:
                            visualConfig.rewardScale *
                            _rewardScale(frame.rewardProgress),
                        child: Opacity(
                          key: Key('$keyPrefix-rewardOpacity-${type.name}'),
                          opacity: frame.rewardOpacity,
                          child: reward,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _shakeLayer(double shake, {required Widget child}) {
    return Transform.translate(
      offset: Offset(shake * 5, 0),
      child: Transform.rotate(angle: shake * math.pi / 90, child: child),
    );
  }

  Widget _assetLayer({
    required String asset,
    required Key assetKey,
    required double scale,
    required Offset offset,
  }) {
    return Transform.translate(
      offset: offset,
      child: Transform.scale(
        scale: scale,
        child: Image.asset(
          asset,
          key: assetKey,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        ),
      ),
    );
  }

  double _shakeAmount(double value) {
    if (value < 0.14 || value > 0.31) return 0;
    final local = (value - 0.14) / 0.17;
    return math.sin(local * math.pi * 6) * (1 - local * 0.35);
  }

  double _rewardScale(double value) {
    if (value <= 0.72) {
      return 0.60 + 0.48 * Curves.easeOutCubic.transform(value / 0.72);
    }
    return 1.08 - 0.08 * Curves.easeInOut.transform((value - 0.72) / 0.28);
  }
}

@immutable
class GachaVisualFrame {
  const GachaVisualFrame({
    required this.lidProgress,
    required this.leakProgress,
    required this.burstProgress,
    required this.rewardProgress,
    required this.rewardOpacity,
    required this.boxOpacity,
    required this.glowFade,
  });

  final double lidProgress;
  final double leakProgress;
  final double burstProgress;
  final double rewardProgress;
  final double rewardOpacity;
  final double boxOpacity;
  final double glowFade;

  factory GachaVisualFrame.forProgress(
    double progress, {
    bool reducedMotion = false,
  }) {
    final value = progress.clamp(0.0, 1.0);
    final rewardProgress = _curvedInterval(
      value,
      reducedMotion ? 0.36 : 0.54,
      reducedMotion ? 0.68 : 0.80,
      Curves.easeOutCubic,
    );
    return GachaVisualFrame(
      lidProgress: reducedMotion
          ? _curvedInterval(value, 0.16, 0.44, Curves.easeOut)
          : _curvedInterval(value, 0.36, 0.57, Curves.easeInOutCubic),
      leakProgress: _curvedInterval(
        value,
        reducedMotion ? 0.10 : 0.24,
        reducedMotion ? 0.38 : 0.50,
        Curves.easeOut,
      ),
      burstProgress: _curvedInterval(
        value,
        reducedMotion ? 0.28 : 0.48,
        reducedMotion ? 0.52 : 0.65,
        Curves.easeOutCubic,
      ),
      rewardProgress: rewardProgress,
      rewardOpacity: _curvedInterval(rewardProgress, 0, 0.28, Curves.easeOut),
      boxOpacity:
          1 -
          _curvedInterval(
            value,
            reducedMotion ? 0.48 : 0.64,
            reducedMotion ? 0.66 : 0.80,
            Curves.easeInOut,
          ),
      glowFade:
          1 -
          _curvedInterval(
            value,
            reducedMotion ? 0.66 : 0.78,
            reducedMotion ? 0.88 : 0.94,
            Curves.easeInOut,
          ),
    );
  }
}

class GachaOpeningOverlay extends StatefulWidget {
  const GachaOpeningOverlay({
    super.key,
    required this.result,
    required this.onContinue,
    this.visualConfig,
  });

  static const animationDuration = Duration(milliseconds: 2200);
  static const reducedMotionDuration = Duration(milliseconds: 280);
  static const skipAvailableAfter = Duration(milliseconds: 800);

  final GachaPurchaseResult result;
  final VoidCallback onContinue;
  final GachaBoxVisualConfig? visualConfig;

  @override
  State<GachaOpeningOverlay> createState() => _GachaOpeningOverlayState();
}

class _GachaOpeningOverlayState extends State<GachaOpeningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: GachaOpeningOverlay.animationDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _controller.duration = _reducedMotion
        ? GachaOpeningOverlay.reducedMotionDuration
        : GachaOpeningOverlay.animationDuration;
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skip() {
    if (_controller.isCompleted || _reducedMotion) return;
    final skipPoint =
        GachaOpeningOverlay.skipAvailableAfter.inMilliseconds /
        GachaOpeningOverlay.animationDuration.inMilliseconds;
    if (_controller.value < skipPoint) return;
    _controller.value = 1;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.result.item!;
    final locale = Localizations.localeOf(context);
    final visualConfig =
        widget.visualConfig ??
        GachaBoxVisualConfigs.finalized.forType(widget.result.boxType);
    final selection = CosmeticSelection.none.withCategory(
      item.category,
      item.id,
    );
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        final statusProgress = _curvedInterval(
          progress,
          _reducedMotion ? 0.64 : 0.76,
          _reducedMotion ? 0.84 : 0.88,
          Curves.easeOut,
        );
        final textProgress = _curvedInterval(
          progress,
          _reducedMotion ? 0.72 : 0.82,
          _reducedMotion ? 0.92 : 0.96,
          Curves.easeOut,
        );
        final complete = progress >= 0.999;
        return PopScope(
          canPop: complete,
          child: Material(
            key: const Key('gachaResultDialog'),
            type: MaterialType.transparency,
            child: SafeArea(
              child: GestureDetector(
                key: const Key('gachaAnimationTapTarget'),
                behavior: HitTestBehavior.opaque,
                onTap: _skip,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final horizontalPadding = constraints.maxWidth < 360
                        ? 12.0
                        : 20.0;
                    final availableWidth =
                        constraints.maxWidth - horizontalPadding * 2;
                    final availableHeight = constraints.maxHeight - 24;
                    final stageDimension = math.min(
                      math.min(availableWidth, 350.0),
                      availableHeight * 0.54,
                    );
                    final stageTop = (availableHeight - stageDimension) * 0.46;
                    final detailTop = math.min(
                      stageTop + stageDimension - 4,
                      availableHeight - 166,
                    );
                    final colors = Theme.of(context).colorScheme;
                    final textShadows = <Shadow>[
                      Shadow(
                        color: colors.surface.withValues(alpha: 0.96),
                        blurRadius: 5,
                      ),
                      Shadow(
                        color: colors.surface.withValues(alpha: 0.90),
                        blurRadius: 2,
                      ),
                    ];
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 12,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Align(
                            alignment: const Alignment(0, -0.08),
                            child: SizedBox.square(
                              dimension: stageDimension,
                              child: GachaBoxVisual(
                                key: const Key('gachaOpeningVisual'),
                                type: widget.result.boxType,
                                config: visualConfig,
                                progress: progress,
                                rarity: item.rarity,
                                reducedMotion: _reducedMotion,
                                keyPrefix: 'openingGachaBox',
                                reward: CharacterPreview(
                                  key: Key('gachaResultPreview-${item.id}'),
                                  selection: selection,
                                  expression: SlimeExpression.happy,
                                ),
                              ),
                            ),
                          ),
                          if (statusProgress > 0)
                            Positioned(
                              top: math.max(4, stageTop - 42),
                              left: 0,
                              right: 0,
                              child: Opacity(
                                opacity: statusProgress,
                                child: Transform.translate(
                                  offset: Offset(0, 8 * (1 - statusProgress)),
                                  child: Text(
                                    widget.result.isNewUnlock
                                        ? context.l10n.gachaRewardNew
                                        : context.l10n.duplicate,
                                    key: const Key('gachaResultStatus'),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: colors.onSurface,
                                          fontWeight: FontWeight.w900,
                                          shadows: textShadows,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          if (textProgress > 0)
                            Positioned(
                              top: detailTop,
                              left: 8,
                              right: 8,
                              child: Opacity(
                                opacity: textProgress,
                                child: Transform.translate(
                                  offset: Offset(0, 8 * (1 - textProgress)),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.localizedName(locale),
                                        key: const Key('gachaResultItemName'),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              color: colors.onSurface,
                                              fontWeight: FontWeight.w800,
                                              shadows: textShadows,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.rarity.stars,
                                        key: const Key('gachaResultRarity'),
                                        style: TextStyle(
                                          color: colors.onSurface,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          shadows: textShadows,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.result.isNewUnlock
                                            ? context.l10n.unlocked
                                            : context.l10n.convertedToCoins(
                                                widget.result.duplicateRefund,
                                              ),
                                        key: const Key('gachaResultOutcome'),
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: colors.onSurface,
                                              fontWeight: FontWeight.w800,
                                              shadows: textShadows,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (complete)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: 160,
                                  ),
                                  child: FilledButton(
                                    key: const Key('gachaResultOkButton'),
                                    onPressed: widget.onContinue,
                                    style: FilledButton.styleFrom(
                                      foregroundColor: colors.onPrimary,
                                    ),
                                    child: Text(
                                      context.l10n.continueLabel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter({
    required this.progress,
    required this.count,
    required this.color,
  });

  final double progress;
  final int count;
  final Color color;

  static const _destinations = <Offset>[
    Offset(-0.42, -0.42),
    Offset(-0.26, -0.62),
    Offset(-0.08, -0.48),
    Offset(0.12, -0.68),
    Offset(0.30, -0.50),
    Offset(0.44, -0.32),
    Offset(-0.48, -0.18),
    Offset(-0.20, -0.28),
    Offset(0.22, -0.24),
    Offset(0.49, -0.10),
    Offset(-0.36, 0.02),
    Offset(-0.04, -0.74),
    Offset(0.37, -0.66),
    Offset(0.08, -0.36),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final burst = _linearInterval(progress, 0.47, 0.80);
    if (burst <= 0) return;
    final origin = Offset(size.width * 0.5, size.height * 0.57);
    for (var index = 0; index < count; index++) {
      final delay = index * 0.018;
      final local = ((burst - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;
      final eased = Curves.easeOutCubic.transform(local);
      final target =
          origin +
          Offset(
            _destinations[index].dx * size.width,
            _destinations[index].dy * size.height,
          );
      final position = Offset.lerp(origin, target, eased)!;
      final opacity = math.sin(local * math.pi).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = (index.isEven ? color : Colors.white).withValues(
          alpha: opacity,
        );
      final radius = 2.2 + (index % 3) * 0.8;
      if (index % 4 == 0) {
        _paintStar(canvas, position, radius * 1.8, paint);
      } else {
        canvas.drawCircle(position, radius, paint);
      }
    }
  }

  void _paintStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * 0.28, center.dy - radius * 0.28)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx + radius * 0.28, center.dy + radius * 0.28)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius * 0.28, center.dy + radius * 0.28)
      ..lineTo(center.dx - radius, center.dy)
      ..lineTo(center.dx - radius * 0.28, center.dy - radius * 0.28)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) {
    return progress != oldDelegate.progress ||
        count != oldDelegate.count ||
        color != oldDelegate.color;
  }
}

double _curvedInterval(double value, double begin, double end, Curve curve) {
  return curve.transform(_linearInterval(value, begin, end));
}

double _linearInterval(double value, double begin, double end) {
  return ((value - begin) / (end - begin)).clamp(0.0, 1.0);
}

double _lerp(double begin, double end, double progress) {
  return begin + (end - begin) * progress;
}
