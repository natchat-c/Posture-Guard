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

  test('posture notification exposes one background mute action', () {
    expect(PostureNotificationService.postureAlertActions, hasLength(1));
    final AndroidNotificationAction action =
        PostureNotificationService.postureAlertActions.single;
    expect(action.id, PostureNotificationService.mute15MinutesActionId);
    expect(action.title, 'Mute for 15 min');
    expect(action.showsUserInterface, isFalse);
    expect(action.cancelNotification, isTrue);
  });
}
