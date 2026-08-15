import 'package:flutter/foundation.dart';

import '../services/gacha_service.dart';

@immutable
class GachaBoxVisualConfig {
  const GachaBoxVisualConfig({
    required this.baseScale,
    required this.baseX,
    required this.baseY,
    required this.lidScale,
    required this.lidX,
    required this.lidY,
    required this.lidOpenX,
    required this.lidOpenY,
    required this.lidOpenRotationDegrees,
    required this.lidOpenScale,
    required this.glowX,
    required this.glowY,
    required this.glowScale,
    required this.rewardX,
    required this.rewardY,
    required this.rewardScale,
  });

  final double baseScale;
  final double baseX;
  final double baseY;
  final double lidScale;
  final double lidX;
  final double lidY;
  final double lidOpenX;
  final double lidOpenY;
  final double lidOpenRotationDegrees;
  final double lidOpenScale;
  final double glowX;
  final double glowY;
  final double glowScale;
  final double rewardX;
  final double rewardY;
  final double rewardScale;

  GachaBoxVisualConfig copyWith({
    double? baseScale,
    double? baseX,
    double? baseY,
    double? lidScale,
    double? lidX,
    double? lidY,
    double? lidOpenX,
    double? lidOpenY,
    double? lidOpenRotationDegrees,
    double? lidOpenScale,
    double? glowX,
    double? glowY,
    double? glowScale,
    double? rewardX,
    double? rewardY,
    double? rewardScale,
  }) {
    return GachaBoxVisualConfig(
      baseScale: baseScale ?? this.baseScale,
      baseX: baseX ?? this.baseX,
      baseY: baseY ?? this.baseY,
      lidScale: lidScale ?? this.lidScale,
      lidX: lidX ?? this.lidX,
      lidY: lidY ?? this.lidY,
      lidOpenX: lidOpenX ?? this.lidOpenX,
      lidOpenY: lidOpenY ?? this.lidOpenY,
      lidOpenRotationDegrees:
          lidOpenRotationDegrees ?? this.lidOpenRotationDegrees,
      lidOpenScale: lidOpenScale ?? this.lidOpenScale,
      glowX: glowX ?? this.glowX,
      glowY: glowY ?? this.glowY,
      glowScale: glowScale ?? this.glowScale,
      rewardX: rewardX ?? this.rewardX,
      rewardY: rewardY ?? this.rewardY,
      rewardScale: rewardScale ?? this.rewardScale,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GachaBoxVisualConfig &&
        other.baseScale == baseScale &&
        other.baseX == baseX &&
        other.baseY == baseY &&
        other.lidScale == lidScale &&
        other.lidX == lidX &&
        other.lidY == lidY &&
        other.lidOpenX == lidOpenX &&
        other.lidOpenY == lidOpenY &&
        other.lidOpenRotationDegrees == lidOpenRotationDegrees &&
        other.lidOpenScale == lidOpenScale &&
        other.glowX == glowX &&
        other.glowY == glowY &&
        other.glowScale == glowScale &&
        other.rewardX == rewardX &&
        other.rewardY == rewardY &&
        other.rewardScale == rewardScale;
  }

  @override
  int get hashCode => Object.hashAll([
    baseScale,
    baseX,
    baseY,
    lidScale,
    lidX,
    lidY,
    lidOpenX,
    lidOpenY,
    lidOpenRotationDegrees,
    lidOpenScale,
    glowX,
    glowY,
    glowScale,
    rewardX,
    rewardY,
    rewardScale,
  ]);
}

@immutable
class GachaBoxVisualConfigs {
  const GachaBoxVisualConfigs({required this.standard, required this.premium});

  static const finalized = GachaBoxVisualConfigs(
    standard: GachaBoxVisualConfig(
      baseScale: 0.94,
      baseX: 0,
      baseY: 0.08,
      lidScale: 0.78,
      lidX: 0,
      lidY: -0.01,
      lidOpenX: 0,
      lidOpenY: -0.20,
      lidOpenRotationDegrees: 0,
      lidOpenScale: 0.80,
      glowX: 0,
      glowY: -0.04,
      glowScale: 1.45,
      rewardX: 0,
      rewardY: 0,
      rewardScale: 1,
    ),
    premium: GachaBoxVisualConfig(
      baseScale: 0.91,
      baseX: 0,
      baseY: 0.09,
      lidScale: 0.82,
      lidX: 0,
      lidY: -0.14,
      lidOpenX: 0,
      lidOpenY: -0.30,
      lidOpenRotationDegrees: 0,
      lidOpenScale: 0.82,
      glowX: 0,
      glowY: -0.03,
      glowScale: 1.08,
      rewardX: 0,
      rewardY: 0.02,
      rewardScale: 1.03,
    ),
  );

  final GachaBoxVisualConfig standard;
  final GachaBoxVisualConfig premium;

  GachaBoxVisualConfig forType(GachaBoxType type) => switch (type) {
    GachaBoxType.standard => standard,
    GachaBoxType.premium => premium,
  };
}
