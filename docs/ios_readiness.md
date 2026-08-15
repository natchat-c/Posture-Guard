# iOS readiness

This document records the platform boundary as of the pre-iOS cleanup. It does
not define or implement an iOS background-monitoring design.

## Already platform-neutral

- Flutter UI, localization, settings, calibration models, posture thresholds,
  posture classification, coins, cosmetics/gacha, and statistics summaries.
- Sensor processing follows `sensor vector -> normalized phone angle -> pure
  posture logic`; no Android type enters the classifier.
- Local state uses `SharedPreferencesAsync`. Existing keys for language,
  tutorial completion, settings, calibration, notification/camera prompts,
  cosmetics/ownership, coin and gacha state, statistics cache, and alert mute
  remain unchanged.
- Firebase repositories use FlutterFire APIs and keep their existing database
  paths. `firebase_options.dart` contains an iOS option, but native Apple
  project registration still has to be completed and verified.
- Camera capture and permission requests use Flutter plugins. Image-format
  selection is now based on centralized platform capabilities.

## Android-only areas

| Feature | Files | Android dependency | Likely iOS path or fallback |
| --- | --- | --- | --- |
| Continuous background monitoring | `lib/services/monitoring_service.dart`, `lib/main.dart`, `android/app/src/main/AndroidManifest.xml` | `flutter_foreground_task`, special-use foreground service, wake lock, persistent low-priority notification | Design around permitted iOS background execution; until then the capability is explicitly unsupported and never reports itself running. |
| Aggregate device screen time | `lib/services/device_screen_time_service.dart`, `android/app/src/main/kotlin/com/example/postureguard/MainActivity.kt` | MethodChannel, `UsageStatsManager`, `UsageEvents`, AppOps usage access, `PACKAGE_USAGE_STATS`, Android usage-access Settings intent | A separately entitled/authorized Apple Screen Time implementation may be possible. Current fallback returns unavailable/null so Home and Statistics retain Monitored Time and never show fabricated device time. |
| Interactive/unlocked screen state | `lib/services/screen_state_service.dart`, `packages/screen_state_bridge/` | Android `PowerManager`, `KeyguardManager`, screen broadcasts, MethodChannel/EventChannel | No direct parity is assumed. Current fallback treats the screen as interactive and emits no transitions. Revisit with the eventual iOS monitoring design. |
| Foreground-service notification | `lib/services/monitoring_service.dart`, `android/app/src/main/AndroidManifest.xml` | Android notification channel and foreground-service notification contract | No iOS equivalent is claimed; it follows the background-execution design. |
| Posture notification channels/actions | `lib/services/notification_service.dart`, `android/app/src/main/AndroidManifest.xml` | Android channel importance, vibration pattern, visibility/category, action objects, and `ActionBroadcastReceiver` | Local alert content is reusable. iOS still needs notification authorization and Darwin categories/actions if mute buttons are required. |
| Camera frame format | `lib/pages/home_page.dart`, `lib/platform/platform_capabilities.dart` | Android camera stream uses NV21; other platforms use BGRA8888 | Existing platform branch is centralized. Validate ML Kit frame metadata and front-camera behavior on physical iOS hardware. |
| Android permissions/configuration | `android/app/src/main/AndroidManifest.xml` | Camera, notifications, foreground service/special use, wake lock, usage stats, optional camera features, portrait activity | Do not copy Android permissions. Configure only the Apple permissions/capabilities required by the chosen iOS feature set. |

## Abstractions and current fallbacks

- `PlatformCapabilities` is the single resolver for device screen time,
  background monitoring, persistent foreground notification, screen-state
  events, and Android camera format selection.
- `DeviceScreenTimeProvider` selects the unchanged Android MethodChannel
  provider on Android and `UnavailableDeviceScreenTimeProvider` elsewhere.
- `ScreenStateProvider` selects the existing bridge on Android and
  `AlwaysInteractiveScreenStateProvider` elsewhere.
- `BackgroundMonitoringPlatformService` selects the existing Android
  foreground-task implementation on Android and an explicit unsupported
  implementation elsewhere. Widgets and app startup communicate only through
  `MonitoringService`.

## Work required on macOS/Xcode

1. Register the final iOS bundle identifier in Firebase, add the genuine
   `GoogleService-Info.plist`, and verify that generated Dart options match the
   registered app. Do not change existing Firebase database paths.
2. Verify the existing camera usage description, camera permission flow, ML Kit
   CocoaPods, deployment target, and physical-device camera frame handling.
3. Request notification authorization and define Darwin notification
   categories/actions if the mute actions are part of the iOS feature set.
4. Choose an allowed iOS background-monitoring model before adding Background
   Modes or entitlements. Android foreground-service behavior cannot simply be
   simulated on iOS.
5. Decide whether Apple Screen Time frameworks and their restricted
   entitlements fit the product. Otherwise keep device screen time unavailable
   and use the existing Monitored Time fallback.
6. Only after those decisions, add AppDelegate, Info.plist, entitlement,
   FamilyControls, or DeviceActivity changes. None were made in this cleanup.

The largest expected reductions on iOS are continuous background posture
monitoring, lock-state awareness, persistent foreground status, and aggregate
whole-device screen time. Their capability flags remain false until real iOS
implementations exist.
