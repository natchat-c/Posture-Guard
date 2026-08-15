import 'package:flutter/widgets.dart';

enum SlimeExpression { happy, neutral, sad, verySad }

enum CosmeticCategory { hat, eyewear, holding, back }

enum CosmeticRarity { oneStar, twoStar, threeStar, fourStar, fiveStar }

extension CosmeticRarityDisplay on CosmeticRarity {
  int get starCount => index + 1;

  String get stars => List.filled(starCount, '★').join();
}

@immutable
class CosmeticTransform {
  const CosmeticTransform({
    this.scale = 1,
    this.offsetX = 0,
    this.offsetY = 0,
    this.rotationDegrees = 0,
  });

  final double scale;
  final double offsetX;
  final double offsetY;
  final double rotationDegrees;

  @override
  bool operator ==(Object other) {
    return other is CosmeticTransform &&
        other.scale == scale &&
        other.offsetX == offsetX &&
        other.offsetY == offsetY &&
        other.rotationDegrees == rotationDegrees;
  }

  @override
  int get hashCode => Object.hash(scale, offsetX, offsetY, rotationDegrees);
}

typedef CosmeticExpressionTransforms = Map<SlimeExpression, CosmeticTransform>;

@immutable
class CosmeticItem {
  const CosmeticItem({
    required this.id,
    required this.category,
    required this.assetPath,
    required this.englishName,
    required this.thaiName,
    required this.rarity,
    this.isStarter = false,
    this.isAlignmentLocked = false,
  });

  final String id;
  final CosmeticCategory category;
  final String assetPath;
  final String englishName;
  final String thaiName;
  final CosmeticRarity rarity;
  final bool isStarter;
  final bool isAlignmentLocked;

  String localizedName(Locale locale) {
    return locale.languageCode == 'th' ? thaiName : englishName;
  }

  CosmeticTransform transformFor(SlimeExpression expression) {
    return CosmeticCatalog.finalizedTransforms[id]?[expression] ??
        const CosmeticTransform();
  }
}

CosmeticTransform resolveCosmeticTransform(
  CosmeticItem item,
  SlimeExpression expression,
) => item.transformFor(expression);

@immutable
class CosmeticSelection {
  const CosmeticSelection({
    this.hatId,
    this.eyewearId,
    this.holdingId,
    this.backId,
  });

  static const none = CosmeticSelection();

  final String? hatId;
  final String? eyewearId;
  final String? holdingId;
  final String? backId;

  CosmeticSelection withHat(String? id) {
    return CosmeticSelection(
      hatId: id,
      eyewearId: eyewearId,
      holdingId: holdingId,
      backId: backId,
    );
  }

  CosmeticSelection withEyewear(String? id) {
    return CosmeticSelection(
      hatId: hatId,
      eyewearId: id,
      holdingId: holdingId,
      backId: backId,
    );
  }

  CosmeticSelection withHolding(String? id) {
    return CosmeticSelection(
      hatId: hatId,
      eyewearId: eyewearId,
      holdingId: id,
      backId: backId,
    );
  }

  CosmeticSelection withBack(String? id) {
    return CosmeticSelection(
      hatId: hatId,
      eyewearId: eyewearId,
      holdingId: holdingId,
      backId: id,
    );
  }

  CosmeticSelection withCategory(CosmeticCategory category, String? id) {
    return switch (category) {
      CosmeticCategory.hat => withHat(id),
      CosmeticCategory.eyewear => withEyewear(id),
      CosmeticCategory.holding => withHolding(id),
      CosmeticCategory.back => withBack(id),
    };
  }

  String? idFor(CosmeticCategory category) {
    return switch (category) {
      CosmeticCategory.hat => hatId,
      CosmeticCategory.eyewear => eyewearId,
      CosmeticCategory.holding => holdingId,
      CosmeticCategory.back => backId,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is CosmeticSelection &&
        other.hatId == hatId &&
        other.eyewearId == eyewearId &&
        other.holdingId == holdingId &&
        other.backId == backId;
  }

  @override
  int get hashCode => Object.hash(hatId, eyewearId, holdingId, backId);
}

class CosmeticCatalog {
  const CosmeticCatalog._();

  static const starterIds = <String>{'cowboy_hat', 'glasses3'};

  /// Final production alignment, keyed by cosmetic ID and slime expression.
  static const finalizedTransforms = <String, CosmeticExpressionTransforms>{
    'cat_ears': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 1.02,
        offsetX: 0.00,
        offsetY: -0.05,
        rotationDegrees: 0.0,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 1.05,
        offsetX: 0.00,
        offsetY: -0.07,
        rotationDegrees: -3.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 1.02,
        offsetX: 0.00,
        offsetY: -0.03,
        rotationDegrees: 0.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 1.08,
        offsetX: 0.00,
        offsetY: -0.04,
        rotationDegrees: 0.0,
      ),
    },
    'cowboy_hat': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 0.64,
        offsetX: -0.02,
        offsetY: -0.18,
        rotationDegrees: 3.0,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.64,
        offsetX: -0.04,
        offsetY: -0.20,
        rotationDegrees: -1.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.57,
        offsetX: -0.02,
        offsetY: -0.15,
        rotationDegrees: 3.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.64,
        offsetX: -0.02,
        offsetY: -0.16,
        rotationDegrees: 4.0,
      ),
    },
    'crown': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 0.94,
        offsetX: -0.09,
        offsetY: -0.31,
        rotationDegrees: -14.0,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.95,
        offsetX: -0.09,
        offsetY: -0.33,
        rotationDegrees: -13.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.95,
        offsetX: -0.09,
        offsetY: -0.28,
        rotationDegrees: -13.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.94,
        offsetX: -0.09,
        offsetY: -0.30,
        rotationDegrees: -13.0,
      ),
    },
    'flower_hat': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 0.74,
        offsetX: 0.00,
        offsetY: -0.17,
        rotationDegrees: 0.0,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.83,
        offsetX: -0.02,
        offsetY: -0.18,
        rotationDegrees: -4.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.74,
        offsetX: -0.01,
        offsetY: -0.14,
        rotationDegrees: -1.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.81,
        offsetX: 0.00,
        offsetY: -0.16,
        rotationDegrees: 0.0,
      ),
    },
    'halo': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 0.75,
        offsetX: -0.01,
        offsetY: -0.24,
        rotationDegrees: -3.0,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.75,
        offsetX: -0.03,
        offsetY: -0.25,
        rotationDegrees: -3.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.75,
        offsetX: -0.01,
        offsetY: -0.19,
        rotationDegrees: 0.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.79,
        offsetX: -0.01,
        offsetY: -0.24,
        rotationDegrees: 0.0,
      ),
    },
    'santa_hat': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 0.90,
        offsetX: -0.07,
        offsetY: -0.21,
        rotationDegrees: 1.0,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.94,
        offsetX: -0.07,
        offsetY: -0.23,
        rotationDegrees: -1.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.92,
        offsetX: -0.07,
        offsetY: -0.18,
        rotationDegrees: 1.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 1.02,
        offsetX: -0.06,
        offsetY: -0.19,
        rotationDegrees: 1.0,
      ),
    },
    'scholar_hat': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 0.53,
        offsetX: -0.06,
        offsetY: -0.18,
        rotationDegrees: -13.0,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.55,
        offsetX: -0.06,
        offsetY: -0.20,
        rotationDegrees: -13.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.53,
        offsetX: -0.06,
        offsetY: -0.14,
        rotationDegrees: -8.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.56,
        offsetX: -0.06,
        offsetY: -0.18,
        rotationDegrees: -11.0,
      ),
    },
    'glasses': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 0.67,
        offsetX: 0.02,
        offsetY: -0.01,
        rotationDegrees: 0.0,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.67,
        offsetX: 0.02,
        offsetY: -0.01,
        rotationDegrees: -3.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.58,
        offsetX: 0.03,
        offsetY: 0.04,
        rotationDegrees: -8.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.66,
        offsetX: 0.04,
        offsetY: 0.03,
        rotationDegrees: -3.0,
      ),
    },
    'glasses2': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 0.77,
        offsetX: 0.01,
        offsetY: -0.03,
        rotationDegrees: -7.0,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.72,
        offsetX: 0.01,
        offsetY: -0.02,
        rotationDegrees: -8.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.77,
        offsetX: 0.01,
        offsetY: 0.00,
        rotationDegrees: -4.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.78,
        offsetX: 0.01,
        offsetY: -0.01,
        rotationDegrees: -4.0,
      ),
    },
    'glasses3': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 0.59,
        offsetX: 0.01,
        offsetY: -0.03,
        rotationDegrees: -5.0,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.59,
        offsetX: 0.01,
        offsetY: -0.03,
        rotationDegrees: -6.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.63,
        offsetX: 0.01,
        offsetY: 0.00,
        rotationDegrees: -5.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.62,
        offsetX: 0.01,
        offsetY: -0.01,
        rotationDegrees: -4.0,
      ),
    },
    'glasses4': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 0.60,
        offsetX: 0.00,
        offsetY: -0.03,
        rotationDegrees: -6.0,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.61,
        offsetX: 0.01,
        offsetY: -0.02,
        rotationDegrees: -7.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.61,
        offsetX: 0.00,
        offsetY: 0.01,
        rotationDegrees: -5.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.67,
        offsetX: 0.01,
        offsetY: 0.00,
        rotationDegrees: -5.0,
      ),
    },
    'heart_glasses': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 1.05,
        offsetX: 0.01,
        offsetY: 0.00,
        rotationDegrees: -3.0,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 1.09,
        offsetX: 0.01,
        offsetY: 0.00,
        rotationDegrees: -6.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 1.05,
        offsetX: 0.01,
        offsetY: 0.00,
        rotationDegrees: -3.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 1.09,
        offsetX: 0.01,
        offsetY: 0.00,
        rotationDegrees: -2.0,
      ),
    },
    'star_glasses': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 0.72,
        offsetX: 0.01,
        offsetY: -0.02,
        rotationDegrees: -4.0,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.79,
        offsetX: 0.02,
        offsetY: -0.02,
        rotationDegrees: -8.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.79,
        offsetX: 0.01,
        offsetY: 0.01,
        rotationDegrees: -4.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.82,
        offsetX: 0.01,
        offsetY: 0.00,
        rotationDegrees: -4.0,
      ),
    },
    'sunglasses': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 0.79,
        offsetX: 0.01,
        offsetY: -0.04,
        rotationDegrees: -5.0,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.82,
        offsetX: 0.02,
        offsetY: -0.04,
        rotationDegrees: -7.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.82,
        offsetX: 0.01,
        offsetY: -0.01,
        rotationDegrees: -4.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.84,
        offsetX: 0.01,
        offsetY: -0.02,
        rotationDegrees: -4.0,
      ),
    },
    'brush': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 0.58,
        offsetX: 0.21,
        rotationDegrees: -1.0,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.58,
        offsetX: 0.21,
        rotationDegrees: -1.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.58,
        offsetX: 0.21,
        offsetY: 0.03,
        rotationDegrees: 16.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.58,
        offsetX: 0.21,
        offsetY: 0.01,
        rotationDegrees: 16.0,
      ),
    },
    'candy': {
      SlimeExpression.happy: CosmeticTransform(scale: 0.53, offsetX: 0.22),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.53,
        offsetX: 0.25,
        rotationDegrees: -15.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.53,
        offsetX: 0.22,
        offsetY: 0.06,
        rotationDegrees: 20.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.49,
        offsetX: 0.25,
        offsetY: 0.07,
        rotationDegrees: 20.0,
      ),
    },
    'coffee': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 0.50,
        offsetX: 0.22,
        offsetY: 0.03,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.50,
        offsetX: 0.22,
        offsetY: 0.03,
        rotationDegrees: -12.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.50,
        offsetX: 0.22,
        offsetY: 0.03,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.40,
        offsetX: 0.22,
        offsetY: 0.04,
        rotationDegrees: -11.0,
      ),
    },
    'flowers': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 0.48,
        offsetX: 0.23,
        offsetY: -0.01,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.48,
        offsetX: 0.26,
        offsetY: -0.04,
        rotationDegrees: -12.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.48,
        offsetX: 0.23,
        offsetY: 0.02,
        rotationDegrees: 20.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.49,
        offsetX: 0.27,
        offsetY: 0.03,
        rotationDegrees: 20.0,
      ),
    },
    'gaming_controller': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 0.40,
        offsetX: 0.23,
        rotationDegrees: 20.0,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.40,
        offsetX: 0.23,
        rotationDegrees: 18.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.40,
        offsetX: 0.23,
        offsetY: 0.04,
        rotationDegrees: 8.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.40,
        offsetX: 0.23,
        offsetY: 0.05,
        rotationDegrees: 6.0,
      ),
    },
    'magic_book': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 0.49,
        offsetY: 0.10,
        rotationDegrees: 2.0,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.54,
        offsetX: 0.06,
        offsetY: 0.10,
        rotationDegrees: -2.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.40,
        offsetX: 0.03,
        offsetY: 0.12,
        rotationDegrees: 3.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.44,
        offsetX: 0.04,
        offsetY: 0.14,
        rotationDegrees: 3.0,
      ),
    },
    'magic_wand': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 0.59,
        offsetX: 0.19,
        offsetY: -0.01,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.59,
        offsetX: 0.19,
        offsetY: -0.01,
        rotationDegrees: -13.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.59,
        offsetX: 0.19,
        offsetY: 0.04,
        rotationDegrees: 20.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.59,
        offsetX: 0.19,
        offsetY: 0.05,
        rotationDegrees: 20.0,
      ),
    },
    'microphone': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 0.65,
        offsetX: 0.21,
        offsetY: -0.02,
        rotationDegrees: 1.0,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.65,
        offsetX: 0.25,
        offsetY: -0.08,
        rotationDegrees: -18.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.65,
        offsetX: 0.24,
        offsetY: 0.01,
        rotationDegrees: 20.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.65,
        offsetX: 0.24,
        offsetY: 0.03,
        rotationDegrees: 20.0,
      ),
    },
    'teddy_bear': {
      SlimeExpression.happy: CosmeticTransform(
        scale: 0.49,
        offsetX: -0.23,
        rotationDegrees: 10.0,
      ),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.50,
        offsetX: -0.23,
        offsetY: 0.02,
        rotationDegrees: 2.0,
      ),
      SlimeExpression.sad: CosmeticTransform(
        scale: 0.40,
        offsetX: -0.25,
        offsetY: 0.01,
        rotationDegrees: 9.0,
      ),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.59,
        offsetX: -0.26,
        offsetY: -0.01,
        rotationDegrees: 17.0,
      ),
    },
    'angle_wings': {
      SlimeExpression.happy: CosmeticTransform(),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.96,
        rotationDegrees: -5.0,
      ),
      SlimeExpression.sad: CosmeticTransform(),
      SlimeExpression.verySad: CosmeticTransform(scale: 0.99),
    },
    'backpack': {
      SlimeExpression.happy: CosmeticTransform(scale: 1.11, offsetY: -0.02),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 1.07,
        offsetY: -0.04,
        rotationDegrees: -5.0,
      ),
      SlimeExpression.sad: CosmeticTransform(scale: 1.04, offsetY: 0.01),
      SlimeExpression.verySad: CosmeticTransform(scale: 1.12),
    },
    'bat_wings': {
      SlimeExpression.happy: CosmeticTransform(scale: 0.91, offsetY: -0.11),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.91,
        offsetX: -0.02,
        offsetY: -0.11,
        rotationDegrees: -6.0,
      ),
      SlimeExpression.sad: CosmeticTransform(scale: 0.91, offsetY: -0.11),
      SlimeExpression.verySad: CosmeticTransform(scale: 0.93, offsetY: -0.14),
    },
    'butterfly_wings': {
      SlimeExpression.happy: CosmeticTransform(scale: 0.89, offsetY: -0.11),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.85,
        offsetY: -0.10,
        rotationDegrees: -7.0,
      ),
      SlimeExpression.sad: CosmeticTransform(scale: 0.86, offsetY: -0.10),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.88,
        offsetY: -0.11,
        rotationDegrees: -2.0,
      ),
    },
    'devil_wings': {
      SlimeExpression.happy: CosmeticTransform(scale: 1.06),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 1.06,
        rotationDegrees: -5.0,
      ),
      SlimeExpression.sad: CosmeticTransform(scale: 1.06),
      SlimeExpression.verySad: CosmeticTransform(scale: 1.07),
    },
    'dragon_wings': {
      SlimeExpression.happy: CosmeticTransform(scale: 0.87, offsetY: -0.10),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.87,
        offsetX: -0.01,
        offsetY: -0.10,
        rotationDegrees: -7.0,
      ),
      SlimeExpression.sad: CosmeticTransform(scale: 0.87, offsetY: -0.10),
      SlimeExpression.verySad: CosmeticTransform(scale: 0.87, offsetY: -0.15),
    },
    'fairy_wings': {
      SlimeExpression.happy: CosmeticTransform(scale: 0.95),
      SlimeExpression.neutral: CosmeticTransform(
        scale: 0.92,
        rotationDegrees: -4.0,
      ),
      SlimeExpression.sad: CosmeticTransform(scale: 0.95),
      SlimeExpression.verySad: CosmeticTransform(
        scale: 0.94,
        rotationDegrees: -1.0,
      ),
    },
  };

  static const hats = <CosmeticItem>[
    CosmeticItem(
      id: 'cat_ears',
      category: CosmeticCategory.hat,
      rarity: CosmeticRarity.twoStar,
      assetPath: 'images/accessories/hats/cat_ears.png',
      englishName: 'Cat Ears',
      thaiName: 'หูแมว',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'cowboy_hat',
      category: CosmeticCategory.hat,
      rarity: CosmeticRarity.oneStar,
      assetPath: 'images/accessories/hats/cowboy_hat.png',
      englishName: 'Cowboy Hat',
      thaiName: 'หมวกคาวบอย',
      isStarter: true,
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'crown',
      category: CosmeticCategory.hat,
      rarity: CosmeticRarity.fourStar,
      assetPath: 'images/accessories/hats/crown.png',
      englishName: 'Crown',
      thaiName: 'มงกุฎ',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'flower_hat',
      category: CosmeticCategory.hat,
      rarity: CosmeticRarity.twoStar,
      assetPath: 'images/accessories/hats/flower_hat.png',
      englishName: 'Flower Hat',
      thaiName: 'หมวกดอกไม้',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'halo',
      category: CosmeticCategory.hat,
      rarity: CosmeticRarity.fiveStar,
      assetPath: 'images/accessories/hats/halo.png',
      englishName: 'Halo',
      thaiName: 'วงแหวนเทวดา',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'santa_hat',
      category: CosmeticCategory.hat,
      rarity: CosmeticRarity.threeStar,
      assetPath: 'images/accessories/hats/santa_hat.png',
      englishName: 'Santa Hat',
      thaiName: 'หมวกซานต้า',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'scholar_hat',
      category: CosmeticCategory.hat,
      rarity: CosmeticRarity.twoStar,
      assetPath: 'images/accessories/hats/scholar_hat.png',
      englishName: 'Scholar Hat',
      thaiName: 'หมวกรับปริญญา',
      isAlignmentLocked: true,
    ),
  ];

  static const eyewear = <CosmeticItem>[
    CosmeticItem(
      id: 'glasses',
      category: CosmeticCategory.eyewear,
      rarity: CosmeticRarity.oneStar,
      assetPath: 'images/accessories/eyewear/glasses.png',
      englishName: 'Monocle',
      thaiName: 'แว่นตาข้างเดียว',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'glasses2',
      category: CosmeticCategory.eyewear,
      rarity: CosmeticRarity.twoStar,
      assetPath: 'images/accessories/eyewear/glasses2.png',
      englishName: 'Square Glasses',
      thaiName: 'แว่นตาทรงเหลี่ยม',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'glasses3',
      category: CosmeticCategory.eyewear,
      rarity: CosmeticRarity.oneStar,
      assetPath: 'images/accessories/eyewear/glasses3.png',
      englishName: 'Bold Glasses',
      thaiName: 'แว่นตากรอบหนา',
      isStarter: true,
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'glasses4',
      category: CosmeticCategory.eyewear,
      rarity: CosmeticRarity.twoStar,
      assetPath: 'images/accessories/eyewear/glasses4.png',
      englishName: 'Round Glasses',
      thaiName: 'แว่นตาทรงกลม',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'heart_glasses',
      category: CosmeticCategory.eyewear,
      rarity: CosmeticRarity.fourStar,
      assetPath: 'images/accessories/eyewear/heart_glasses.png',
      englishName: 'Heart Glasses',
      thaiName: 'แว่นรูปหัวใจ',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'star_glasses',
      category: CosmeticCategory.eyewear,
      rarity: CosmeticRarity.fourStar,
      assetPath: 'images/accessories/eyewear/star_glasses.png',
      englishName: 'Star Glasses',
      thaiName: 'แว่นรูปดาว',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'sunglasses',
      category: CosmeticCategory.eyewear,
      rarity: CosmeticRarity.threeStar,
      assetPath: 'images/accessories/eyewear/sunglasses.png',
      englishName: 'Sunglasses',
      thaiName: 'แว่นกันแดด',
      isAlignmentLocked: true,
    ),
  ];

  static const holding = <CosmeticItem>[
    CosmeticItem(
      id: 'brush',
      category: CosmeticCategory.holding,
      rarity: CosmeticRarity.oneStar,
      assetPath: 'images/accessories/holding/brush.png',
      englishName: 'Brush',
      thaiName: 'พู่กัน',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'candy',
      category: CosmeticCategory.holding,
      rarity: CosmeticRarity.oneStar,
      assetPath: 'images/accessories/holding/candy.png',
      englishName: 'Candy',
      thaiName: 'ลูกอม',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'coffee',
      category: CosmeticCategory.holding,
      rarity: CosmeticRarity.oneStar,
      assetPath: 'images/accessories/holding/coffee.png',
      englishName: 'Coffee',
      thaiName: 'กาแฟ',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'flowers',
      category: CosmeticCategory.holding,
      rarity: CosmeticRarity.twoStar,
      assetPath: 'images/accessories/holding/flowers.png',
      englishName: 'Flowers',
      thaiName: 'ช่อดอกไม้',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'gaming_controller',
      category: CosmeticCategory.holding,
      rarity: CosmeticRarity.twoStar,
      assetPath: 'images/accessories/holding/gaming_controller.png',
      englishName: 'Gaming Controller',
      thaiName: 'จอยเกม',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'magic_book',
      category: CosmeticCategory.holding,
      rarity: CosmeticRarity.threeStar,
      assetPath: 'images/accessories/holding/magic_book.png',
      englishName: 'Magic Book',
      thaiName: 'หนังสือเวทมนตร์',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'magic_wand',
      category: CosmeticCategory.holding,
      rarity: CosmeticRarity.fourStar,
      assetPath: 'images/accessories/holding/magic_wand.png',
      englishName: 'Magic Wand',
      thaiName: 'ไม้กายสิทธิ์',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'microphone',
      category: CosmeticCategory.holding,
      rarity: CosmeticRarity.threeStar,
      assetPath: 'images/accessories/holding/microphone.png',
      englishName: 'Microphone',
      thaiName: 'ไมโครโฟน',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'teddy_bear',
      category: CosmeticCategory.holding,
      rarity: CosmeticRarity.threeStar,
      assetPath: 'images/accessories/holding/teddy_bear.png',
      englishName: 'Teddy Bear',
      thaiName: 'ตุ๊กตาหมี',
      isAlignmentLocked: true,
    ),
  ];

  static const back = <CosmeticItem>[
    CosmeticItem(
      id: 'angle_wings',
      category: CosmeticCategory.back,
      rarity: CosmeticRarity.fiveStar,
      assetPath: 'images/accessories/back/angle_wings.png',
      englishName: 'Angle Wings',
      thaiName: 'ปีกนางฟ้า',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'backpack',
      category: CosmeticCategory.back,
      rarity: CosmeticRarity.threeStar,
      assetPath: 'images/accessories/back/backpack.png',
      englishName: 'Backpack',
      thaiName: 'กระเป๋าเป้',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'bat_wings',
      category: CosmeticCategory.back,
      rarity: CosmeticRarity.threeStar,
      assetPath: 'images/accessories/back/bat_wings.png',
      englishName: 'Bat Wings',
      thaiName: 'ปีกค้างคาว',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'butterfly_wings',
      category: CosmeticCategory.back,
      rarity: CosmeticRarity.fourStar,
      assetPath: 'images/accessories/back/butterfly_wings.png',
      englishName: 'Butterfly Wings',
      thaiName: 'ปีกผีเสื้อ',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'devil_wings',
      category: CosmeticCategory.back,
      rarity: CosmeticRarity.fourStar,
      assetPath: 'images/accessories/back/devil_wings.png',
      englishName: 'Devil Wings',
      thaiName: 'ปีกปีศาจ',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'dragon_wings',
      category: CosmeticCategory.back,
      rarity: CosmeticRarity.fiveStar,
      assetPath: 'images/accessories/back/dragon_wings.png',
      englishName: 'Dragon Wings',
      thaiName: 'ปีกมังกร',
      isAlignmentLocked: true,
    ),
    CosmeticItem(
      id: 'fairy_wings',
      category: CosmeticCategory.back,
      rarity: CosmeticRarity.fiveStar,
      assetPath: 'images/accessories/back/fairy_wings.png',
      englishName: 'Fairy Wings',
      thaiName: 'ปีกภูต',
      isAlignmentLocked: true,
    ),
  ];

  static const all = <CosmeticItem>[...hats, ...eyewear, ...holding, ...back];

  static List<CosmeticItem> get gachaPool =>
      all.where((item) => !item.isStarter).toList(growable: false);

  static List<CosmeticItem> gachaPoolForRarity(CosmeticRarity rarity) =>
      gachaPool.where((item) => item.rarity == rarity).toList(growable: false);

  static List<CosmeticItem> forCategory(CosmeticCategory category) {
    return switch (category) {
      CosmeticCategory.hat => hats,
      CosmeticCategory.eyewear => eyewear,
      CosmeticCategory.holding => holding,
      CosmeticCategory.back => back,
    };
  }

  static CosmeticItem? find(String? id, [CosmeticCategory? category]) {
    if (id == null) return null;
    for (final item in all) {
      if (item.id == id && (category == null || item.category == category)) {
        return item;
      }
    }
    return null;
  }
}
