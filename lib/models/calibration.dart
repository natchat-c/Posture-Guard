class Calibration {
  const Calibration({required this.neutralPhoneAngle, this.neutralHeadX});

  final double neutralPhoneAngle;
  final double? neutralHeadX;

  static bool isValidPhoneAngle(double value) {
    return value.isFinite && value >= 0 && value <= 90;
  }

  static bool isValidHeadAngle(double value) {
    return value.isFinite && value >= -90 && value <= 90;
  }

  bool get isValid {
    return isValidPhoneAngle(neutralPhoneAngle) &&
        (neutralHeadX == null || isValidHeadAngle(neutralHeadX!));
  }
}
