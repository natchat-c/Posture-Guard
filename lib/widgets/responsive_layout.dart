import 'package:flutter/widgets.dart';

abstract final class ResponsiveBreakpoints {
  static const double verySmallWidth = 340;
  static const double smallWidth = 380;
  static const double largeWidth = 430;
  static const double shortHeight = 650;
  static const double maxContentWidth = 720;
}

extension ResponsiveConstraints on BoxConstraints {
  bool get isVerySmallPhone => maxWidth < ResponsiveBreakpoints.verySmallWidth;
  bool get isSmallPhone => maxWidth < ResponsiveBreakpoints.smallWidth;
  bool get isLargePhone => maxWidth >= ResponsiveBreakpoints.largeWidth;
  bool get isShortPhone => maxHeight < ResponsiveBreakpoints.shortHeight;

  double get responsiveHorizontalPadding {
    if (isVerySmallPhone) return 12;
    if (isSmallPhone) return 16;
    return 20;
  }
}
