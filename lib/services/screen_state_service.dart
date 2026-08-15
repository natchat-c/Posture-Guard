import 'dart:async';

import 'package:flutter/services.dart';
import 'package:screen_state_bridge/screen_state_bridge.dart';

import '../platform/platform_capabilities.dart';

abstract class ScreenStateProvider {
  Future<bool> isInteractive();

  Stream<bool> get changes;
}

ScreenStateProvider createScreenStateProvider({
  PlatformCapabilities? capabilities,
}) {
  final resolvedCapabilities = capabilities ?? PlatformCapabilities.current;
  if (resolvedCapabilities.supportsScreenStateEvents) {
    return const AndroidScreenStateProvider();
  }
  return const AlwaysInteractiveScreenStateProvider();
}

class AlwaysInteractiveScreenStateProvider implements ScreenStateProvider {
  const AlwaysInteractiveScreenStateProvider();

  @override
  Future<bool> isInteractive() async => true;

  @override
  Stream<bool> get changes => const Stream<bool>.empty();
}

class AndroidScreenStateProvider implements ScreenStateProvider {
  const AndroidScreenStateProvider({
    ScreenStateBridge bridge = const ScreenStateBridge(),
  }) : _bridge = bridge;

  final ScreenStateBridge _bridge;

  @override
  Future<bool> isInteractive() async {
    try {
      return await _bridge.isInteractive();
    } on PlatformException {
      return true;
    } on MissingPluginException {
      return true;
    }
  }

  @override
  Stream<bool> get changes => _bridge.changes.handleError((Object _) {});
}
