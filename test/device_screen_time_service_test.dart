import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/services/device_screen_time_service.dart';

class _FakeScreenTimeProvider extends DeviceScreenTimeProvider {
  _FakeScreenTimeProvider({
    required this.supported,
    required this.access,
    this.seconds,
  });

  bool supported;
  bool access;
  int? seconds;
  DateTime? requestedStart;
  DateTime? requestedEnd;
  int settingsOpens = 0;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> hasUsageAccess() async => access;

  @override
  Future<bool> openUsageAccessSettings() async {
    settingsOpens++;
    return supported;
  }

  @override
  Future<int?> getScreenTimeSeconds({
    required DateTime start,
    required DateTime end,
  }) async {
    requestedStart = start;
    requestedEnd = end;
    return supported && access ? seconds : null;
  }
}

void main() {
  test(
    'today query uses local midnight through the supplied current time',
    () async {
      final provider = _FakeScreenTimeProvider(
        supported: true,
        access: true,
        seconds: 3723,
      );
      final now = DateTime(2026, 3, 1, 14, 22, 9);

      final seconds = await provider.getTodayScreenTimeSeconds(now: now);

      expect(seconds, 3723);
      expect(provider.requestedStart, DateTime(2026, 3, 1));
      expect(provider.requestedEnd, now);
    },
  );

  test('denied and revoked access return no aggregate', () async {
    final provider = _FakeScreenTimeProvider(
      supported: true,
      access: false,
      seconds: 99,
    );

    expect(
      await provider.getTodayScreenTimeSeconds(now: DateTime(2026, 7, 26)),
      isNull,
    );
    provider.access = true;
    expect(
      await provider.getTodayScreenTimeSeconds(now: DateTime(2026, 7, 26)),
      99,
    );
    provider.access = false;
    expect(
      await provider.getTodayScreenTimeSeconds(now: DateTime(2026, 7, 26)),
      isNull,
    );
  });

  test(
    'unsupported and non-Android providers fall back without throwing',
    () async {
      final fake = _FakeScreenTimeProvider(supported: false, access: false);
      expect(await fake.isSupported(), isFalse);
      expect(
        await fake.getTodayScreenTimeSeconds(now: DateTime(2026, 7, 26)),
        isNull,
      );

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const platformProvider = AndroidDeviceScreenTimeProvider();
      expect(await platformProvider.isSupported(), isFalse);
      expect(await platformProvider.getTodayScreenTimeSeconds(), isNull);
    },
  );

  test('provider API exposes only an aggregate integer duration', () async {
    final provider = _FakeScreenTimeProvider(
      supported: true,
      access: true,
      seconds: 65,
    );

    final result = await provider.getScreenTimeSeconds(
      start: DateTime(2026, 7, 26),
      end: DateTime(2026, 7, 26, 0, 1, 5),
    );

    expect(result, isA<int>());
    expect(result, 65);
  });
}
