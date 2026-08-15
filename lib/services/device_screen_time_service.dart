import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../platform/platform_capabilities.dart';

abstract class DeviceScreenTimeProvider {
  const DeviceScreenTimeProvider();

  Future<bool> isSupported();

  Future<bool> hasUsageAccess();

  Future<bool> openUsageAccessSettings();

  Future<int?> getScreenTimeSeconds({
    required DateTime start,
    required DateTime end,
  });

  Future<int?> getTodayScreenTimeSeconds({DateTime? now}) {
    final current = now ?? DateTime.now();
    final start = DateTime(current.year, current.month, current.day);
    return getScreenTimeSeconds(start: start, end: current);
  }
}

DeviceScreenTimeProvider createDeviceScreenTimeProvider({
  PlatformCapabilities? capabilities,
}) {
  final resolvedCapabilities = capabilities ?? PlatformCapabilities.current;
  if (resolvedCapabilities.supportsDeviceScreenTime) {
    return const AndroidDeviceScreenTimeProvider();
  }
  return const UnavailableDeviceScreenTimeProvider();
}

class UnavailableDeviceScreenTimeProvider extends DeviceScreenTimeProvider {
  const UnavailableDeviceScreenTimeProvider();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<bool> hasUsageAccess() async => false;

  @override
  Future<bool> openUsageAccessSettings() async => false;

  @override
  Future<int?> getScreenTimeSeconds({
    required DateTime start,
    required DateTime end,
  }) async => null;
}

class AndroidDeviceScreenTimeProvider extends DeviceScreenTimeProvider {
  const AndroidDeviceScreenTimeProvider();

  static const MethodChannel _channel = MethodChannel(
    'postureguard/device_screen_time',
  );

  bool get _isAndroid {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  Future<bool> isSupported() async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isUsageAccessSupported') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> hasUsageAccess() async {
    if (!await isSupported()) return false;
    try {
      return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> openUsageAccessSettings() async {
    if (!await isSupported()) return false;
    try {
      return await _channel.invokeMethod<bool>('openUsageAccessSettings') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<int?> getScreenTimeSeconds({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!await isSupported() || end.isBefore(start)) return null;
    try {
      return await _channel.invokeMethod<int>('getDeviceScreenTimeSeconds', {
        'startMillis': start.millisecondsSinceEpoch,
        'endMillis': end.millisecondsSinceEpoch,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
