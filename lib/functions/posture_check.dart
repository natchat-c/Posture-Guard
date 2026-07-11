import 'dart:math' as math;

const double defaultPhoneAngleEmaAlpha = 0.2;
const double enterBadPhoneAngle = 30;
const double returnGoodPhoneAngle = 25;

class PhoneAngleFilter {
  PhoneAngleFilter({this.alpha = defaultPhoneAngleEmaAlpha});

  final double alpha;
  double? _ema;

  double add(double angle) {
    _ema = _ema == null ? angle : alpha * angle + (1 - alpha) * _ema!;
    return _ema!;
  }
}

class PostureHysteresis {
  bool _breached = false;

  bool update(double calibratedAngle) {
    if (_breached) {
      if (calibratedAngle < returnGoodPhoneAngle) _breached = false;
    } else if (calibratedAngle > enterBadPhoneAngle) {
      _breached = true;
    }
    return _breached;
  }
}

class CameraFrameStability {
  CameraFrameStability({this.requiredValidFrames = 3, this.bufferSize = 5});

  final int requiredValidFrames;
  final int bufferSize;
  final List<double> _headXValues = [];
  final List<double> _headYValues = [];
  final List<double> _headZValues = [];
  double? _previousHeadX;

  double? get averageHeadX => _average(_headXValues);
  double? get averageHeadY => _average(_headYValues);
  double? get averageHeadZ => _average(_headZValues);

  bool addFrame({
    required double faceWidth,
    required double faceHeight,
    required double imageWidth,
    required double imageHeight,
    required double? headX,
    required double? headY,
    required double? headZ,
  }) {
    final faceArea = faceWidth * faceHeight;
    final imageArea = imageWidth * imageHeight;
    final largeEnough = imageArea > 0 && faceArea / imageArea >= 0.04;
    final anglesValid =
        headX != null &&
        headY != null &&
        headZ != null &&
        headX.abs() <= 60 &&
        headY.abs() <= 45 &&
        headZ.abs() <= 45;
    final stable =
        _previousHeadX == null ||
        (headX != null && (headX - _previousHeadX!).abs() <= 15);

    if (largeEnough && anglesValid && stable) {
      _add(_headXValues, headX);
      _add(_headYValues, headY);
      _add(_headZValues, headZ);
    }
    _previousHeadX = headX;
    return _headXValues.length >= requiredValidFrames;
  }

  // Recent valid detections are averaged so one noisy frame cannot decide posture.
  void _add(List<double> values, double value) {
    values.add(value);
    if (values.length > bufferSize) values.removeAt(0);
  }

  double? _average(List<double> values) {
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  void reset() {
    _headXValues.clear();
    _headYValues.clear();
    _headZValues.clear();
    _previousHeadX = null;
  }
}

class PhoneMovementDetector {
  PhoneMovementDetector({this.sampleCount = 6, this.movementThreshold = 7});

  final int sampleCount;
  final double movementThreshold;
  final List<double> _changes = [];
  double? _previousAngle;

  bool add(double rawAngle) {
    if (_previousAngle != null) {
      _changes.add((rawAngle - _previousAngle!).abs());
      if (_changes.length > sampleCount) _changes.removeAt(0);
    }
    _previousAngle = rawAngle;
    if (_changes.length < sampleCount) return false;
    return _changes.reduce((a, b) => a + b) / _changes.length >
        movementThreshold;
  }
}

double calibratedPhoneAngle(double smoothedAngle, double neutralAngle) {
  return math.max(0, smoothedAngle - neutralAngle);
}

// TODO: A future pass could add pose detection here to estimate neck and
// shoulder alignment when face angles alone are insufficient.
