import 'package:flutter/foundation.dart';

/// Features whose availability is determined by the host platform.
///
/// This is intentionally small: it describes only capabilities that currently
/// have Android-specific implementations in Posture Guard.
class PlatformCapabilities {
  const PlatformCapabilities({
    required this.isAndroid,
    required this.supportsDeviceScreenTime,
    required this.supportsBackgroundMonitoring,
    required this.supportsPersistentForegroundNotification,
    required this.supportsScreenStateEvents,
  });

  final bool isAndroid;
  final bool supportsDeviceScreenTime;
  final bool supportsBackgroundMonitoring;
  final bool supportsPersistentForegroundNotification;
  final bool supportsScreenStateEvents;

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

    return PlatformCapabilities(
      isAndroid: isAndroid,
      supportsDeviceScreenTime: isAndroid,
      supportsBackgroundMonitoring: isAndroid,
      supportsPersistentForegroundNotification: isAndroid,
      supportsScreenStateEvents: isAndroid,
    );
  }
}
