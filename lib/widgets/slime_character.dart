import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/cosmetics.dart';

class SlimeCharacter extends StatelessWidget {
  const SlimeCharacter({
    super.key,
    this.expression = SlimeExpression.happy,
    this.selection = CosmeticSelection.none,
    this.fit = BoxFit.contain,
    @visibleForTesting this.baseAssetOverride,
  });

  final SlimeExpression expression;
  final CosmeticSelection selection;
  final BoxFit fit;
  final String? baseAssetOverride;

  static const double canvasScale = 1.18;

  static String assetFor(SlimeExpression expression) {
    return switch (expression) {
      SlimeExpression.happy => 'images/slimes/happy_slime.png',
      SlimeExpression.neutral => 'images/slimes/neutral_slime.png',
      SlimeExpression.sad => 'images/slimes/sad_slime.png',
      SlimeExpression.verySad => 'images/slimes/very_sad_slime.png',
    };
  }

  @override
  Widget build(BuildContext context) {
    final back = CosmeticCatalog.find(selection.backId, CosmeticCategory.back);
    final hat = CosmeticCatalog.find(selection.hatId, CosmeticCategory.hat);
    final eyewear = CosmeticCatalog.find(
      selection.eyewearId,
      CosmeticCategory.eyewear,
    );
    final holding = CosmeticCatalog.find(
      selection.holdingId,
      CosmeticCategory.holding,
    );
    return Semantics(
      image: true,
      child: ClipRect(
        child: Transform.scale(
          scale: canvasScale,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (back != null)
                _TransformedAssetLayer(
                  key: Key('equipped-back-${back.id}'),
                  item: back,
                  expression: expression,
                  fit: fit,
                ),
              _AssetLayer(
                key: Key('slime-${expression.name}'),
                assetPath: baseAssetOverride ?? assetFor(expression),
                fit: fit,
              ),
              if (hat != null)
                _TransformedAssetLayer(
                  key: Key('equipped-hat-${hat.id}'),
                  item: hat,
                  expression: expression,
                  fit: fit,
                ),
              if (eyewear != null)
                _TransformedAssetLayer(
                  key: Key('equipped-eyewear-${eyewear.id}'),
                  item: eyewear,
                  expression: expression,
                  fit: fit,
                ),
              if (holding != null)
                _TransformedAssetLayer(
                  key: Key('equipped-holding-${holding.id}'),
                  item: holding,
                  expression: expression,
                  fit: fit,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransformedAssetLayer extends StatelessWidget {
  const _TransformedAssetLayer({
    super.key,
    required this.item,
    required this.expression,
    required this.fit,
  });

  final CosmeticItem item;
  final SlimeExpression expression;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final transform = resolveCosmeticTransform(item, expression);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Transform.translate(
          offset: Offset(
            constraints.maxWidth * transform.offsetX,
            constraints.maxHeight * transform.offsetY,
          ),
          child: Transform.rotate(
            angle: transform.rotationDegrees * math.pi / 180,
            child: Transform.scale(
              scale: transform.scale,
              child: _AssetLayer(assetPath: item.assetPath, fit: fit),
            ),
          ),
        );
      },
    );
  }
}

class _AssetLayer extends StatelessWidget {
  const _AssetLayer({super.key, required this.assetPath, required this.fit});

  final String assetPath;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Image.asset(
        assetPath,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.image_not_supported_outlined, size: 32),
        ),
      ),
    );
  }
}
