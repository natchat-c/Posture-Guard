import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/models/app_settings.dart';
import 'package:postureguard/services/alert_mute_service.dart';
import 'package:postureguard/services/notification_service.dart';

class _MemoryMuteStore implements AlertMuteStore {
  int? value;

  @override
  Future<int?> readMutedUntilEpochMs() async => value;

  @override
  Future<void> writeMutedUntilEpochMs(int? epochMs) async {
    value = epochMs;
  }
}

void main() {
  test(
    '15-minute mute persists the exact expiry without changing settings',
    () async {
      final store = _MemoryMuteStore();
      final now = DateTime(2026, 7, 26, 14, 30);
      final controller = AlertMuteController(store: store, clock: () => now);
      const settings = AppSettings.defaults;

      final until = await controller.muteFor();

      expect(until, DateTime(2026, 7, 26, 14, 45));
      expect(store.value, until.millisecondsSinceEpoch);
      expect(await controller.isMuted, isTrue);
      expect(settings.alertsEnabled, isTrue);
      expect(settings.monitoringEnabled, isTrue);
    },
  );

  test('mute survives reconstruction and expired state is cleared', () async {
    final store = _MemoryMuteStore();
    var now = DateTime(2026, 7, 26, 14, 30);
    await AlertMuteController(store: store, clock: () => now).muteFor();

    final restored = AlertMuteController(store: store, clock: () => now);
    expect(await restored.isMuted, isTrue);

    now = DateTime(2026, 7, 26, 14, 45);
    expect(await restored.isMuted, isFalse);
    expect(store.value, isNull);
  });

  test(
    'manual unmute clears state and does not alter alert preference',
    () async {
      final store = _MemoryMuteStore();
      final controller = AlertMuteController(
        store: store,
        clock: () => DateTime(2026, 7, 26, 14, 30),
      );
      await controller.muteFor();

      await controller.unmute();

      expect(await controller.isMuted, isFalse);
      expect(AppSettings.defaults.alertsEnabled, isTrue);
    },
  );

  test('posture notification exposes exactly two background mute actions', () {
    expect(PostureNotificationService.postureAlertActions, hasLength(2));
    final List<AndroidNotificationAction> actions =
        PostureNotificationService.postureAlertActions;
    expect(actions.map((action) => action.id), [
      PostureNotificationService.mute15MinutesActionId,
      PostureNotificationService.mute1HourActionId,
    ]);
    expect(actions.map((action) => action.title), [
      'Mute 15 min',
      'Mute 1 hour',
    ]);
    for (final action in actions) {
      expect(action.showsUserInterface, isFalse);
      expect(action.cancelNotification, isTrue);
    }
  });

  test(
    'both background actions save exact expiry and dismiss the alert',
    () async {
      final store = _MemoryMuteStore();
      final now = DateTime(2026, 7, 31, 10);
      final controller = AlertMuteController(store: store, clock: () => now);
      var dismissals = 0;

      expect(
        await applyPostureNotificationAction(
          PostureNotificationService.mute15MinutesActionId,
          muteController: controller,
          cancelNotification: () async => dismissals++,
        ),
        isTrue,
      );
      expect(
        store.value,
        now.add(postureAlertMute15MinutesDuration).millisecondsSinceEpoch,
      );

      expect(
        await applyPostureNotificationAction(
          PostureNotificationService.mute1HourActionId,
          muteController: controller,
          cancelNotification: () async => dismissals++,
        ),
        isTrue,
      );
      expect(
        store.value,
        now.add(postureAlertMute1HourDuration).millisecondsSinceEpoch,
      );
      expect(dismissals, 2);
    },
  );

  test(
    'selecting either action replaces mute without changing app state',
    () async {
      final store = _MemoryMuteStore();
      final now = DateTime(2026, 7, 31, 10);
      final controller = AlertMuteController(store: store, clock: () => now);
      const settings = AppSettings.defaults;
      const postureAlertCount = 7;

      await applyPostureNotificationAction(
        PostureNotificationService.mute1HourActionId,
        muteController: controller,
        cancelNotification: () async {},
      );
      await applyPostureNotificationAction(
        PostureNotificationService.mute15MinutesActionId,
        muteController: controller,
        cancelNotification: () async {},
      );

      expect(
        store.value,
        now.add(postureAlertMute15MinutesDuration).millisecondsSinceEpoch,
      );
      expect(settings.alertsEnabled, isTrue);
      expect(settings.monitoringEnabled, isTrue);
      expect(postureAlertCount, 7);
    },
  );

  test('unknown notification actions do not change mute state', () async {
    final store = _MemoryMuteStore();
    final controller = AlertMuteController(
      store: store,
      clock: () => DateTime(2026, 7, 31, 10),
    );

    expect(
      await applyPostureNotificationAction(
        'unknown',
        muteController: controller,
        cancelNotification: () async {},
      ),
      isFalse,
    );
    expect(store.value, isNull);
  });
}
