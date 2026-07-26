import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/functions/posture_check.dart';

void main() {
  test('posture hysteresis enters at 30 degrees and exits below 25', () {
    final hysteresis = PostureHysteresis();

    expect(hysteresis.update(30), isFalse);
    expect(hysteresis.update(30.1), isTrue);
    expect(hysteresis.update(25), isTrue);
    expect(hysteresis.update(24.9), isFalse);
  });

  test('alert scheduler repeats at frequency and resets on good posture', () {
    final scheduler = PostureAlertScheduler();
    final start = DateTime(2026, 1, 1, 12);

    expect(
      scheduler.isDue(
        now: start,
        postureIsBad: true,
        alertsEnabled: true,
        frequencySeconds: 30,
      ),
      isTrue,
    );
    scheduler.markAlertSent(start);
    expect(
      scheduler.isDue(
        now: start.add(const Duration(seconds: 29)),
        postureIsBad: true,
        alertsEnabled: true,
        frequencySeconds: 30,
      ),
      isFalse,
    );
    expect(
      scheduler.isDue(
        now: start.add(const Duration(seconds: 30)),
        postureIsBad: true,
        alertsEnabled: true,
        frequencySeconds: 30,
      ),
      isTrue,
    );

    scheduler.reset();
    expect(scheduler.lastAlert, isNull);
  });
}
