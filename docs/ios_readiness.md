# Posture Guard iOS readiness

This is a Windows implementation audit, not proof of an iOS device build.
Estimated iOS code/configuration readiness is **70%**. Flutter UI, data, and the
foreground sensor-monitoring path are functional in structure and test-driven;
camera, ML Kit, notifications, and sensor axes still need Apple hardware
verification. Android-style background monitoring, whole-device screen time,
and lock-state signals do not yet have iOS parity.

## A. Prepared on Windows

- Kept the existing `PlatformCapabilities`, screen-time, screen-state, and
  background-monitoring service boundaries. No duplicate abstractions were
  introduced.
- Added `IosForegroundMonitoringController` behind the monitoring facade. It
  subscribes through `sensors_plus` only while the app is resumed, reuses the
  existing posture math/calibration/alert-delay/statistics code, and pauses and
  resets the active episode for every non-resumed lifecycle state.
- Added a three-second first-sample timeout and safe stream-error handling. An
  iOS Simulator with no motion samples remains responsive and receives a
  localized sensor-unavailable message; no production readings are fabricated.
- Confirmed the Android-only manual ML Kit MethodChannel is skipped on iOS and
  added tests for both the iOS skip and unchanged Android path.
- Set the iOS project and CocoaPods deployment target to 15.5. This is required
  by the installed `google_mlkit_face_detection` and
  `google_mlkit_commons` podspecs; their documentation also requires Xcode
  15.3 or newer and exclusion of armv7.
- Added the standard Flutter CocoaPods integration, the ML Kit armv7 exclusion,
  and only the `PERMISSION_CAMERA=1` permission-handler macro.
- Clarified `NSCameraUsageDescription`: front camera, while the app is open,
  on-device processing, and no saving or uploading.
- Added no entitlements, background modes, notification plist keys, Apple
  Screen Time APIs, or untestable native implementations.

## B-E. Feature readiness matrix

“Conceptual compile” means the Dart/plugin API has an iOS implementation or a
guarded fallback; it still requires an actual Mac build.

| Feature | Current implementation | Android dependency | Conceptual iOS compile? | iOS equivalent/current fallback | Safe Windows preparation | Mac/Xcode or device verification |
| --- | --- | --- | --- | --- | --- | --- |
| Accelerometer/orientation | `sensors_plus` feeds platform-neutral angle normalization | Android sensor plugin implementation | Yes | Foreground iOS controller uses `sensors_plus`; first-sample timeout handles Simulator absence | Controller and failure tests added | Verify axes, rotations, sampling, portrait lock |
| Posture classification | Pure Dart thresholds/filter/hysteresis/delay | None | Yes | iOS controller calls the same classes with sensor samples | Synthetic GOOD/WARNING/BAD test added | Compare real-device classifications |
| Calibration | Flutter UI plus platform-neutral calibration model | None | Yes | Same logic | No change needed | Verify sensor values and persistence |
| Background monitoring | `MonitoringService` selects Android background or iOS foreground implementation | `flutter_foreground_task`, foreground service, wake lock, persistent notification | Yes, with reduced behavior | iOS monitors only while resumed; it does not call `flutter_foreground_task` or claim background protection | Foreground controller and resolver tests added | Design an Apple-permitted background model separately |
| Screen interactive/lock | `ScreenStateProvider` | Internal Android MethodChannel/EventChannel bridge, `PowerManager`, `KeyguardManager`, broadcasts | Yes, with fallback | Always-interactive/no-events fallback | Existing boundary retained | Decide behavior with the future monitoring design |
| Whole-device screen time | `DeviceScreenTimeProvider` | `UsageStatsManager`, `UsageEvents`, AppOps, usage-access Settings intent | Yes, with fallback | Unavailable/null; Statistics uses Monitored Time | Existing boundary retained | Apple Screen Time entitlement/product decision |
| Usage Access UI/tutorial | Capability-gated Settings section and guided-tour step | Android usage-access permission/settings | Yes | Hidden/skipped when unsupported | Existing tests cover the fallback | Confirm complete flow on iPhone |
| Notifications | `flutter_local_notifications`; foreground controller treats initialization/delivery as non-fatal | Android channels, category, vibration, action receiver | Plugin: yes; product flow: incomplete | Generic Darwin foreground alert can be attempted; authorization and Darwin categories/actions still need work | Sensor monitoring is tested independent of notification success | Prompt, foreground delivery, action design |
| Camera | `camera`, generic permission service, front-camera stream | Android camera plugin implementation; Android frames use NV21 | Yes | `camera_avfoundation`; non-Android frames use BGRA8888 | Camera plist text and macro prepared | Permission states, front-camera selection, frames, indicator |
| ML Kit face detection | Lazy `FaceDetectorLifecycle`; manual initializer only when Android capability is true | `postureguard/ml_kit` MethodChannel and Android `MlKit.initialize` | Yes in structure | Native iOS ML Kit plugin creates detector; Android bridge is skipped | iOS/Android path tests added; iOS 15.5 prepared | CocoaPods resolution and physical-device detection |
| Firebase Core | Explicit `DefaultFirebaseOptions.currentPlatform` | `google-services.json` only for Android native setup | Yes | FlutterFire iOS SDK and explicit Dart options | Configuration audited only | Bundle registration/config consistency |
| Firebase anonymous Auth | FlutterFire repository/service | None in app code | Yes | Firebase Auth iOS SDK | No behavior change | Anonymous sign-in, restart identity, deletion |
| Firebase Realtime Database | FlutterFire repositories under existing `users/{uid}` paths | None in app code | Yes | Firebase Database iOS SDK | Schema/paths untouched | Online/offline/read/write behavior |
| SharedPreferences | `SharedPreferencesAsync` repositories | None in app code | Yes | `shared_preferences_foundation` | Keys/semantics untouched | Persistence across restart/reinstall expectations |
| App lifecycle | `MyApp` forwards lifecycle to the monitoring facade | Android service receives a no-op; its native service is unchanged | Yes | iOS cancels sensors/ticks, flushes stats, and resets posture when not resumed; resumes if still enabled | Pause/resume tests added | Confirm transitions and interruptions on device |
| Permissions | Camera through `permission_handler`; notification permission through monitoring facade | Android permission model and Usage Access | Partially | Camera can use `permission_handler_apple`; notification runtime flow is pending | Camera macro/plist only | Denied/restricted/permanently denied/settings flows |
| Privacy/PDPA | Flutter pages and persisted acknowledgements | Some existing English/Thai copy names Android | Yes | Same disclosure semantics; platform-specific copy needs a later localized pass | Semantics untouched | Review wording and UI on iOS |
| Tutorial | Flutter tutorial; Usage Access step is capability-gated | Android Usage Access step | Yes | Android-only step is skipped | Existing behavior retained | End-to-end first-run test; review platform wording |
| Delete My Data | Firebase user-tree removal, anonymous-user deletion, and local reset | No direct Android API; policy preserves some Android permission choices | Yes | Same logical deletion path | Semantics untouched | Verify remote deletion, local reset, and re-authentication |
| Cosmetic cloud sync | FlutterFire plus local-first repositories | None in app code | Yes | Same repositories | Paths/ownership logic untouched | Offline edits, reconnect, ownership/equip sync |
| UI/layout/localization | Material Flutter UI, English and Thai localizations | No compile-time Android widget dependency | Yes | Keep current visual identity | No redesign | Portrait sizes, safe areas, text scale, EN/TH overflow |

## Package audit

| Dependency | Classification | iOS note |
| --- | --- | --- |
| `flutter`, `flutter_localizations` | Android + iOS | Framework/localization code |
| `camera` | Android + iOS | Uses `camera_avfoundation`; device verification required |
| `google_mlkit_face_detection` | Android + iOS | Requires iOS 15.5, Xcode 15.3+, CocoaPods, and physical verification |
| `sensors_plus` | Android + iOS | Verify axes/orientation and sampling on iPhone |
| `cupertino_icons`, `fdottedline_nullsafety`, `fl_chart` | Cross-platform Dart/UI | No native blocker identified |
| `firebase_core`, `firebase_auth`, `firebase_database` | Android + iOS | Native pods and final Firebase app registration require Mac verification |
| `flutter_local_notifications` | Android + iOS | Darwin authorization/categories/actions need product work and device tests |
| `flutter_foreground_task` | Android + iOS plugin, Android-only app behavior | Retained for Android; iOS selects the in-process controller and never invokes it |
| `permission_handler` | Android + iOS | Only camera is enabled in the iOS Podfile; runtime test required |
| `shared_preferences` | Android + iOS | Native persistence requires routine device verification |
| `screen_state_bridge` | Android-only internal plugin | Never selected on iOS; safe always-interactive fallback is used |
| `flutter_test`, `shared_preferences_platform_interface`, `flutter_lints` | Development-only | No release runtime role |

## F-G. Bundle identifier and Firebase status

- Xcode Runner bundle identifier (Debug/Profile/Release):
  `com.example.postureguard`.
- Firebase iOS bundle identifier in `lib/firebase_options.dart`:
  `com.example.postureguard`.
- Firebase iOS app ID:
  `1:616136459870:ios:41b05d69081fa01ae216cf` in project
  `posture-guard-ab657`.
- `firebase_options.dart` does contain explicit iOS options, including the
  Asia-Southeast Realtime Database URL.
- `ios/Runner/GoogleService-Info.plist` is absent.
- The current placeholder Xcode bundle and Dart options are internally
  consistent, so they were not changed on Windows. Android production identity
  remains `com.postureguard.app` and its Firebase configuration was untouched.

Before release, choose the final iOS identifier (normally
`com.postureguard.app` if Apple availability permits), register it as an iOS app
in the Firebase project, and set the same identifier for all Runner
configurations and signing in Xcode. Generate the iOS configuration into a
temporary Dart file as described below so the existing multi-platform
`firebase_options.dart` is not overwritten. Keep the Android Firebase app,
options, and `google-services.json` unchanged.

## H-J. Mac handoff

Requirements: macOS, Xcode 15.3 or newer, an Apple development team/device,
Flutter matching the project, CocoaPods, and an iPhone running iOS 15.5 or
newer. There are no iOS entitlements or Background Modes yet.

First Simulator commands, before changing the bundle identity:

```sh
git pull
flutter doctor -v
flutter pub get
cd ios
pod install
cd ..
flutter build ios --simulator
open ios/Runner.xcworkspace
```

Use `Runner.xcworkspace`, not `Runner.xcodeproj`, because the native plugins use
CocoaPods. If pod specs are stale, run `pod repo update` and retry `pod install`.
Do not commit `Pods/` or machine-specific Xcode state.

Likely first-session issues:

- Xcode command-line tools, CocoaPods/Ruby setup, signing team, provisioning,
  trust/developer mode, or an unavailable placeholder bundle identifier.
- Pod resolution for Firebase/ML Kit and the enforced iOS 15.5 minimum.
- Firebase release registration: install the Firebase CLI, run `firebase
  login`, and install FlutterFire CLI with `dart pub global activate
  flutterfire_cli`. After registering the exact final bundle ID, run from the
  repository root:

  ```sh
  flutterfire configure --yes --project=posture-guard-ab657 --platforms=ios --ios-bundle-id=com.postureguard.app --out=lib/firebase_options_ios_candidate.dart --ios-out=ios/Runner/GoogleService-Info.plist
  ```

  Merge only the generated iOS `FirebaseOptions` into the existing
  `lib/firebase_options.dart`, delete the candidate file, and confirm the
  Android options are byte-for-byte unchanged. Ensure
  `GoogleService-Info.plist` is a member of the Runner target. The current
  FlutterFire CLI supports the platform, bundle-ID, and output flags, and Apple
  configuration must be run on macOS.
- ML Kit supports only 64-bit iOS architectures; armv7 is excluded in the
  Podfile, but the effective Xcode build settings must still be inspected.
- Camera frame metadata/orientation, sensor axes, permissions, and notification
  delivery cannot be validated on Windows.
- The iOS Simulator commonly supplies no accelerometer samples. Posture Guard
  should show the localized unavailable message without crashing or blocking
  Settings, Statistics, Gacha, Customize, Firebase, or navigation.
- Background monitoring, lock-state awareness, whole-device screen time, and
  persistent foreground status are intentionally reduced/unavailable on iOS.

## K. Real-iPhone checklist

- [ ] App launches without plugin/configuration errors; restart and offline
      launch also work.
- [ ] English and Thai language selection, first-run privacy disclosure, and
      tutorial work; Android Usage Access is not shown.
- [ ] Sensor orientation/axes and posture classification are correct in
      portrait; calibration saves and restores. These require a real iPhone.
- [ ] Camera explanation and permission allow/deny/settings states work.
- [ ] Front camera, visible camera indicator, ML Kit face detection, and
      sensor-only fallback all work; images are neither saved nor uploaded.
- [ ] Notification authorization and visible alerts work. Mute actions do not
      have Android parity until Darwin categories/actions are implemented.
- [ ] Backgrounding pauses sensor monitoring and returning to foreground
      restores it when enabled. Continuous Android-style background monitoring
      and its persistent notification are **not expected to have parity** yet.
- [ ] Screen lock/unlock does not crash. Android lock-state signaling is **not
      expected to have parity** yet.
- [ ] Statistics show the existing Monitored Time fallback. Whole-device Screen
      Time/Usage Access is **not expected to have parity** yet.
- [ ] Gacha, cosmetic local persistence, and equipped/owned cosmetic state work
      across restart.
- [ ] Firebase anonymous Auth persists; ownership sync handles reconnect and
      offline mode.
- [ ] Delete My Data removes `users/{uid}`, the anonymous Firebase user, and the
      local state covered by the existing policy without crashing.

## Intentionally deferred

- No iOS build, `pod install`, or `xcodebuild` was attempted on Windows.
- No final bundle-ID/Firebase registration change was guessed.
- No AppDelegate customization, entitlement, Background Mode, Apple Screen Time
  API, iOS background-monitoring implementation, or Darwin notification-action
  design was added without Xcode/device verification.
- No Android manifest, Gradle, Kotlin, foreground-service, ML Kit bridge,
  notification, UsageStats, screen-state, posture, persistence, UI, tutorial,
  or localization behavior was changed.
