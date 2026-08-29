import 'package:flutter/foundation.dart';

/// Features whose availability is determined by the host platform.
///
/// Foreground posture monitoring is separate from continuous background
/// monitoring so iOS does not inherit Android service/UsageStats assumptions.
class PlatformCapabilities {
  const PlatformCapabilities({
    required this.isAndroid,
    required this.isIOS,
    required this.supportsForegroundPostureMonitoring,
    required this.supportsDeviceScreenTime,
    required this.supportsBackgroundMonitoring,
    required this.supportsPersistentForegroundNotification,
    required this.supportsScreenStateEvents,
    required this.supportsCameraAssistance,
  });

  final bool isAndroid;
  final bool isIOS;
  final bool supportsForegroundPostureMonitoring;
  final bool supportsDeviceScreenTime;
  final bool supportsBackgroundMonitoring;
  final bool supportsPersistentForegroundNotification;
  final bool supportsScreenStateEvents;
  final bool supportsCameraAssistance;

  static PlatformCapabilities get current {
    return const PlatformCapabilityResolver().resolve();
  }
}

class PlatformCapabilityResolver {
  const PlatformCapabilityResolver();

  PlatformCapabilities resolve({TargetPlatform? platform, bool? isWeb}) {
    final resolvedIsWeb = isWeb ?? kIsWeb;
    final resolvedPlatform = platform ?? defaultTargetPlatform;
    final isAndroid =
        !resolvedIsWeb && resolvedPlatform == TargetPlatform.android;
    final isIOS = !resolvedIsWeb && resolvedPlatform == TargetPlatform.iOS;
    final isMobile = isAndroid || isIOS;

    return PlatformCapabilities(
      isAndroid: isAndroid,
      isIOS: isIOS,
      supportsForegroundPostureMonitoring: isMobile,
      supportsDeviceScreenTime: isAndroid,
      supportsBackgroundMonitoring: isAndroid,
      supportsPersistentForegroundNotification: isAndroid,
      supportsScreenStateEvents: isAndroid,
      supportsCameraAssistance: isMobile,
    );
  }
}
