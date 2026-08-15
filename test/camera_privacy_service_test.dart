import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/services/camera_privacy_service.dart';
import 'package:postureguard/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _PermissionGateway implements CameraPermissionGateway {
  CameraPermissionState current = CameraPermissionState.denied;
  CameraPermissionState requestResult = CameraPermissionState.denied;
  int requestCalls = 0;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<CameraPermissionState> request() async {
    requestCalls++;
    current = requestResult;
    return current;
  }

  @override
  Future<CameraPermissionState> status() async => current;
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'a denial is not followed by repeated Android permission prompts',
    () async {
      final gateway = _PermissionGateway();
      final preferences = SharedPreferencesAsync();
      final coordinator = CameraAssistPermissionCoordinator(
        preferences: CameraPrivacyPreferences(preferences: preferences),
        permissionGateway: gateway,
        sharedPreferences: preferences,
      );

      final first = await coordinator.enableAfterExplanation();
      final retry = await coordinator.enableAfterExplanation();

      expect(first.enabled, isFalse);
      expect(first.shouldOfferSettings, isFalse);
      expect(retry.enabled, isFalse);
      expect(retry.shouldOfferSettings, isTrue);
      expect(gateway.requestCalls, 1);
      expect(
        await preferences.getBool(PreferenceKeys.cameraAssistEnabled),
        isFalse,
      );
    },
  );

  test(
    'permission revocation disables camera assistance without prompting',
    () async {
      final preferences = SharedPreferencesAsync();
      await preferences.setBool(PreferenceKeys.cameraAssistEnabled, true);
      final gateway = _PermissionGateway();
      final coordinator = CameraAssistPermissionCoordinator(
        preferences: CameraPrivacyPreferences(preferences: preferences),
        permissionGateway: gateway,
        sharedPreferences: preferences,
      );

      final result = await coordinator.reconcilePermission();

      expect(result.enabled, isFalse);
      expect(gateway.requestCalls, 0);
      expect(
        await preferences.getBool(PreferenceKeys.cameraAssistEnabled),
        isFalse,
      );
    },
  );
}
