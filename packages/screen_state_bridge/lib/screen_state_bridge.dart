import 'dart:async';

import 'package:flutter/services.dart';

class ScreenStateBridge {
  const ScreenStateBridge();

  static const MethodChannel _methodChannel = MethodChannel(
    'postureguard/screen_state',
  );
  static const EventChannel _eventChannel = EventChannel(
    'postureguard/screen_state_events',
  );

  Future<bool> isInteractive() async {
    return await _methodChannel.invokeMethod<bool>('isInteractive') ?? true;
  }

  Stream<bool> get changes => _eventChannel
      .receiveBroadcastStream()
      .where((value) => value is bool)
      .cast<bool>()
      .distinct();
}
