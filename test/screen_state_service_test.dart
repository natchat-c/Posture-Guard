import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/platform/platform_capabilities.dart';
import 'package:postureguard/services/screen_state_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('postureguard/screen_state');
  const capabilityResolver = PlatformCapabilityResolver();

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

  test('platform factory preserves Android screen-state implementation', () {
    final provider = createScreenStateProvider(
      capabilities: capabilityResolver.resolve(
        platform: TargetPlatform.android,
        isWeb: false,
      ),
    );

    expect(provider, isA<AndroidScreenStateProvider>());
  });

  test('non-Android screen-state fallback safely stays interactive', () async {
    final provider = createScreenStateProvider(
      capabilities: capabilityResolver.resolve(
        platform: TargetPlatform.iOS,
        isWeb: false,
      ),
    );

    expect(provider, isA<AlwaysInteractiveScreenStateProvider>());
    expect(await provider.isInteractive(), isTrue);
    expect(await provider.changes.toList(), isEmpty);
  });
}
