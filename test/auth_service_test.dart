import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/services/auth_service.dart';
import 'package:postureguard/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FakeAuthClient implements AuthClient {
  _FakeAuthClient({this.user, this.signInResult, this.signInError});

  AuthIdentity? user;
  AuthIdentity? signInResult;
  Object? signInError;
  Completer<AuthIdentity>? signInCompleter;
  int signInCalls = 0;

  @override
  AuthIdentity? get currentUser => user;

  @override
  Future<AuthIdentity> signInAnonymously() async {
    signInCalls++;
    if (signInCompleter case final completer?) {
      user = await completer.future;
      return user!;
    }
    if (signInError case final error?) throw error;
    final result = signInResult;
    if (result == null) throw StateError('No fake sign-in result.');
    user = result;
    return result;
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'an existing anonymous user is reused without another sign-in',
    () async {
      final client = _FakeAuthClient(user: const AuthIdentity('persisted-uid'));
      final service = AuthService(client: client);

      final first = await service.ensureSignedIn();
      final reopened = await service.ensureSignedIn();

      expect(first?.uid, 'persisted-uid');
      expect(reopened?.uid, 'persisted-uid');
      expect(service.currentUid, 'persisted-uid');
      expect(client.signInCalls, 0);
    },
  );

  test(
    'a missing user triggers one anonymous sign-in and returns its UID',
    () async {
      final client = _FakeAuthClient(
        signInResult: const AuthIdentity('first-install-uid'),
      );
      final service = AuthService(client: client);

      expect((await service.ensureSignedIn())?.uid, 'first-install-uid');
      expect((await service.ensureSignedIn())?.uid, 'first-install-uid');
      expect(client.signInCalls, 1);
    },
  );

  test('concurrent cloud requests share one anonymous sign-in', () async {
    final client = _FakeAuthClient()
      ..signInCompleter = Completer<AuthIdentity>();
    final service = AuthService(client: client);

    final first = service.ensureSignedIn();
    final second = service.ensureSignedIn();
    client.signInCompleter!.complete(const AuthIdentity('coalesced-uid'));

    expect((await first)?.uid, 'coalesced-uid');
    expect((await second)?.uid, 'coalesced-uid');
    expect(client.signInCalls, 1);
  });

  test(
    'auth failure stays quiet, exposes no UID, and throttles retries',
    () async {
      final client = _FakeAuthClient(signInError: StateError('offline'));
      final service = AuthService(
        client: client,
        retryDelay: const Duration(minutes: 1),
      );

      expect(await service.ensureSignedIn(), isNull);
      expect(await service.ensureUid(), isNull);
      expect(service.currentUid, isNull);
      expect(client.signInCalls, 1);

      client
        ..signInError = null
        ..signInResult = const AuthIdentity('retry-uid');
      expect(
        (await service.ensureSignedIn(forceRetry: true))?.uid,
        'retry-uid',
      );
      expect(client.signInCalls, 2);
    },
  );

  test('auth initialization does not clear any existing local state', () async {
    final localState = <String, Object>{
      PreferenceKeys.hasCachedSettings: true,
      PreferenceKeys.monitoringEnabled: true,
      PreferenceKeys.hasCalibration: true,
      PreferenceKeys.neutralPhoneAngle: 62.0,
      PreferenceKeys.hasCompletedTutorial: true,
      PreferenceKeys.ownedCosmeticIds: <String>['hat-1', 'back-2'],
      'localCoinStateV2': '{"totalCoins":120}',
      'localStatisticsStateV2': '{"records":{}}',
    };
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData(localState);
    final client = _FakeAuthClient(
      signInResult: const AuthIdentity('new-auth-uid'),
    );

    expect(
      (await AuthService(client: client).ensureSignedIn())?.uid,
      'new-auth-uid',
    );

    final preferences = SharedPreferencesAsync();
    expect(await preferences.getBool(PreferenceKeys.monitoringEnabled), isTrue);
    expect(await preferences.getDouble(PreferenceKeys.neutralPhoneAngle), 62);
    expect(
      await preferences.getBool(PreferenceKeys.hasCompletedTutorial),
      isTrue,
    );
    expect(await preferences.getStringList(PreferenceKeys.ownedCosmeticIds), [
      'hat-1',
      'back-2',
    ]);
    expect(await preferences.getString('localCoinStateV2'), isNotNull);
    expect(await preferences.getString('localStatisticsStateV2'), isNotNull);
  });
}
