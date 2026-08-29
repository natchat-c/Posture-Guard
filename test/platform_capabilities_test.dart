import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/platform/platform_capabilities.dart';

void main() {
  const resolver = PlatformCapabilityResolver();

  test('Android exposes the current native capabilities', () {
    final capabilities = resolver.resolve(
      platform: TargetPlatform.android,
      isWeb: false,
    );

    expect(capabilities.isAndroid, isTrue);
    expect(capabilities.isIOS, isFalse);
    expect(capabilities.supportsForegroundPostureMonitoring, isTrue);
    expect(capabilities.supportsDeviceScreenTime, isTrue);
    expect(capabilities.supportsBackgroundMonitoring, isTrue);
    expect(capabilities.supportsPersistentForegroundNotification, isTrue);
    expect(capabilities.supportsScreenStateEvents, isTrue);
    expect(capabilities.supportsCameraAssistance, isTrue);
  });

  test('iOS supports foreground posture monitoring but not Android parity', () {
    final capabilities = resolver.resolve(
      platform: TargetPlatform.iOS,
      isWeb: false,
    );

    expect(capabilities.isAndroid, isFalse);
    expect(capabilities.isIOS, isTrue);
    expect(capabilities.supportsForegroundPostureMonitoring, isTrue);
    expect(capabilities.supportsDeviceScreenTime, isFalse);
    expect(capabilities.supportsBackgroundMonitoring, isFalse);
    expect(capabilities.supportsPersistentForegroundNotification, isFalse);
    expect(capabilities.supportsScreenStateEvents, isFalse);
    expect(capabilities.supportsCameraAssistance, isTrue);
  });

  test('web does not inherit Android capabilities from a target override', () {
    final capabilities = resolver.resolve(
      platform: TargetPlatform.android,
      isWeb: true,
    );

    expect(capabilities.isAndroid, isFalse);
    expect(capabilities.isIOS, isFalse);
    expect(capabilities.supportsForegroundPostureMonitoring, isFalse);
    expect(capabilities.supportsDeviceScreenTime, isFalse);
    expect(capabilities.supportsBackgroundMonitoring, isFalse);
    expect(capabilities.supportsCameraAssistance, isFalse);
  });
}
