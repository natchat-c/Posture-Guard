import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preferences_service.dart';

enum CameraPermissionState {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unavailable,
}

abstract interface class CameraPermissionGateway {
  Future<CameraPermissionState> status();

  Future<CameraPermissionState> request();

  Future<bool> openSettings();
}

class PermissionHandlerCameraPermissionGateway
    implements CameraPermissionGateway {
  const PermissionHandlerCameraPermissionGateway();

  @override
  Future<CameraPermissionState> status() async {
    try {
      return _map(await Permission.camera.status);
    } catch (_) {
      return CameraPermissionState.unavailable;
    }
  }

  @override
  Future<CameraPermissionState> request() async {
    try {
      return _map(await Permission.camera.request());
    } catch (_) {
      return CameraPermissionState.unavailable;
    }
  }

  @override
  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }

  CameraPermissionState _map(PermissionStatus status) {
    if (status.isGranted) return CameraPermissionState.granted;
    if (status.isPermanentlyDenied) {
      return CameraPermissionState.permanentlyDenied;
    }
    if (status.isRestricted) return CameraPermissionState.restricted;
    return CameraPermissionState.denied;
  }
}

class CameraPrivacyPreferences {
  CameraPrivacyPreferences({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  Future<bool> isNoticeAcknowledged() async {
    return await _preferences.getBool(
          PreferenceKeys.cameraPrivacyNoticeAcknowledged,
        ) ??
        false;
  }

  Future<void> acknowledgeNotice({required bool useSensorsOnly}) async {
    await _preferences.setBool(
      PreferenceKeys.cameraPrivacyNoticeAcknowledged,
      true,
    );
    if (useSensorsOnly) await setCameraAssistEnabled(false);
  }

  Future<bool> isCameraAssistEnabled() async {
    return await _preferences.getBool(PreferenceKeys.cameraAssistEnabled) ??
        false;
  }

  Future<void> setCameraAssistEnabled(bool enabled) {
    return _preferences.setBool(PreferenceKeys.cameraAssistEnabled, enabled);
  }
}

class CameraAssistEnableResult {
  const CameraAssistEnableResult({
    required this.enabled,
    required this.permissionState,
    this.permissionWasPreviouslyRequested = false,
  });

  final bool enabled;
  final CameraPermissionState permissionState;
  final bool permissionWasPreviouslyRequested;

  bool get shouldOfferSettings {
    return permissionState == CameraPermissionState.permanentlyDenied ||
        permissionState == CameraPermissionState.restricted ||
        (permissionState == CameraPermissionState.denied &&
            permissionWasPreviouslyRequested);
  }
}

class CameraAssistPermissionCoordinator {
  CameraAssistPermissionCoordinator({
    CameraPrivacyPreferences? preferences,
    CameraPermissionGateway? permissionGateway,
    SharedPreferencesAsync? sharedPreferences,
  }) : _preferences = preferences ?? CameraPrivacyPreferences(),
       _permissionGateway =
           permissionGateway ??
           const PermissionHandlerCameraPermissionGateway(),
       _sharedPreferences = sharedPreferences ?? SharedPreferencesAsync();

  final CameraPrivacyPreferences _preferences;
  final CameraPermissionGateway _permissionGateway;
  final SharedPreferencesAsync _sharedPreferences;

  Future<bool> isEnabled() => _preferences.isCameraAssistEnabled();

  Future<CameraPermissionState> permissionStatus() {
    return _permissionGateway.status();
  }

  Future<bool> needsExplanation() async {
    final acknowledged = await _preferences.isNoticeAcknowledged();
    final permission = await _permissionGateway.status();
    return !acknowledged || permission != CameraPermissionState.granted;
  }

  Future<CameraAssistEnableResult> enableAfterExplanation() async {
    await _preferences.acknowledgeNotice(useSensorsOnly: false);
    var permission = await _permissionGateway.status();
    final previouslyRequested =
        await _sharedPreferences.getBool(
          PreferenceKeys.cameraPermissionRequested,
        ) ??
        false;
    if (permission != CameraPermissionState.granted &&
        permission != CameraPermissionState.permanentlyDenied &&
        permission != CameraPermissionState.restricted &&
        !previouslyRequested) {
      await _sharedPreferences.setBool(
        PreferenceKeys.cameraPermissionRequested,
        true,
      );
      permission = await _permissionGateway.request();
    }
    final enabled = permission == CameraPermissionState.granted;
    await _preferences.setCameraAssistEnabled(enabled);
    return CameraAssistEnableResult(
      enabled: enabled,
      permissionState: permission,
      permissionWasPreviouslyRequested: previouslyRequested,
    );
  }

  Future<void> disable() => _preferences.setCameraAssistEnabled(false);

  Future<CameraAssistEnableResult> reconcilePermission() async {
    final selected = await _preferences.isCameraAssistEnabled();
    if (!selected) {
      return const CameraAssistEnableResult(
        enabled: false,
        permissionState: CameraPermissionState.denied,
      );
    }
    final permission = await _permissionGateway.status();
    final enabled = permission == CameraPermissionState.granted;
    if (!enabled) await _preferences.setCameraAssistEnabled(false);
    return CameraAssistEnableResult(
      enabled: enabled,
      permissionState: permission,
    );
  }

  Future<bool> openSettings() => _permissionGateway.openSettings();
}
