import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/services/screen_state_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('postureguard/screen_state');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('Android screen-state provider reads interactive state', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'isInteractive');
          return false;
        });

    expect(await const AndroidScreenStateProvider().isInteractive(), isFalse);
  });

  test(
    'screen-state provider fails open on an unavailable platform bridge',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'unavailable');
          });

      expect(await const AndroidScreenStateProvider().isInteractive(), isTrue);
    },
  );
}
