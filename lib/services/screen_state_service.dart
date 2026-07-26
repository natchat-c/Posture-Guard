import 'dart:async';

import 'package:flutter/services.dart';
import 'package:screen_state_bridge/screen_state_bridge.dart';

abstract class ScreenStateProvider {
  Future<bool> isInteractive();

  Stream<bool> get changes;
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
