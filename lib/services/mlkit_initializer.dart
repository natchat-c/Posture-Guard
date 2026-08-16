import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../platform/platform_capabilities.dart';

enum MlKitInitializationState {
  notInitialized,
  initializing,
  initialized,
  failedForSession,
}

abstract interface class MlKitInitialization {
  MlKitInitializationState get state;

  Future<bool> initialize();
}

typedef MlKitNativeInitialize = Future<void> Function();

/// Initializes Android ML Kit only when camera-assisted detection is demanded.
///
/// Failure is locked out for this object/process session so posture events do
/// not repeatedly call into an unavailable native ML Kit runtime.
class MlKitInitializer implements MlKitInitialization {
  MlKitInitializer({
    MlKitNativeInitialize? initializeNative,
    bool? requiresNativeInitialization,
  }) : _initializeNative = initializeNative ?? _initializeAndroidMlKit,
       _requiresNativeInitialization =
           requiresNativeInitialization ??
           PlatformCapabilities.current.isAndroid;

  static const MethodChannel _channel = MethodChannel('postureguard/ml_kit');
  static final MlKitInitializer instance = MlKitInitializer();

  final MlKitNativeInitialize _initializeNative;
  final bool _requiresNativeInitialization;

  MlKitInitializationState _state = MlKitInitializationState.notInitialized;
  Future<bool>? _initializationInFlight;

  @override
  MlKitInitializationState get state => _state;

  @override
  Future<bool> initialize() {
    if (!_requiresNativeInitialization) {
      _state = MlKitInitializationState.initialized;
      return Future<bool>.value(true);
    }
    if (_state == MlKitInitializationState.initialized) {
      return Future<bool>.value(true);
    }
    if (_state == MlKitInitializationState.failedForSession) {
      return Future<bool>.value(false);
    }
    final existing = _initializationInFlight;
    if (existing != null) return existing;

    _state = MlKitInitializationState.initializing;
    late final Future<bool> operation;
    operation = _initializeOnce().whenComplete(() {
      if (identical(_initializationInFlight, operation)) {
        _initializationInFlight = null;
      }
    });
    _initializationInFlight = operation;
    return operation;
  }

  Future<bool> _initializeOnce() async {
    try {
      await _initializeNative();
      _state = MlKitInitializationState.initialized;
      return true;
    } catch (error) {
      _state = MlKitInitializationState.failedForSession;
      if (kDebugMode) debugPrint('ML Kit initialization failed: $error');
      return false;
    }
  }

  static Future<void> _initializeAndroidMlKit() {
    return _channel.invokeMethod<void>('initializeMlKit');
  }
}
