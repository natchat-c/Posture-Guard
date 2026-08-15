import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/services/auth_service.dart';
import 'package:postureguard/services/preferences_service.dart';
import 'package:postureguard/services/user_data_deletion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _DeletionAuthClient implements AuthClient {
  _DeletionAuthClient(this.user);

  AuthIdentity? user;
  int deleteCalls = 0;

  @override
  AuthIdentity? get currentUser => user;

  @override
  Future<void> deleteCurrentUser() async {
    deleteCalls++;
    if (user == null) throw StateError('No current user.');
    user = null;
  }

  @override
  Future<AuthIdentity> signInAnonymously() async {
    throw StateError('Deletion must not create a replacement identity.');
  }
}

class _RecordingRemoteStore implements UserDataRemoteStore {
  final List<String> deletedUids = [];
  Object? error;

  @override
  Future<void> deleteUserNode(String uid) async {
    if (error case final value?) throw value;
    deletedUids.add(uid);
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'deletes only the current UID and selectively clears local user data',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            PreferenceKeys.selectedLanguageCode: 'th',
            PreferenceKeys.notificationPermissionRequested: true,
            PreferenceKeys.cameraPermissionRequested: true,
            PreferenceKeys.hasCompletedTutorial: true,
            PreferenceKeys.monitoringEnabled: true,
            PreferenceKeys.neutralPhoneAngle: 61.0,
            PreferenceKeys.localCoinState: '{"totalCoins":120}',
            PreferenceKeys.localStatisticsState: '{"records":{}}',
            PreferenceKeys.cameraAssistEnabled: true,
            PreferenceKeys.ownedCosmeticIds: <String>['hat-1'],
          });
      final authClient = _DeletionAuthClient(
        const AuthIdentity('current-user-uid'),
      );
      final remote = _RecordingRemoteStore();
      final service = UserDataDeletionService(
        authService: AuthService(client: authClient),
        remoteStore: remote,
        preferences: SharedPreferencesAsync(),
      );

      final result = await service.deleteCurrentUserData();

      expect(result.status, UserDataDeletionStatus.success);
      expect(remote.deletedUids, ['current-user-uid']);
      expect(authClient.deleteCalls, 1);
      expect(authClient.user, isNull);
      final preferences = SharedPreferencesAsync();
      expect(
        await preferences.getString(PreferenceKeys.selectedLanguageCode),
        'th',
      );
      expect(
        await preferences.getBool(
          PreferenceKeys.notificationPermissionRequested,
        ),
        isTrue,
      );
      expect(
        await preferences.getBool(PreferenceKeys.cameraPermissionRequested),
        isTrue,
      );
      for (final key in PreferenceKeys.userDataKeys) {
        expect(await preferences.containsKey(key), isFalse, reason: key);
      }
      expect(
        await preferences.containsKey(
          PreferenceKeys.cloudAccessSuspendedForDeletion,
        ),
        isFalse,
      );
    },
  );

  test(
    'cloud failure keeps identity and local data and reports failure',
    () async {
      final preferences = SharedPreferencesAsync();
      await preferences.setString(PreferenceKeys.localCoinState, 'coins');
      final authClient = _DeletionAuthClient(const AuthIdentity('uid-to-keep'));
      final remote = _RecordingRemoteStore()..error = StateError('offline');
      final service = UserDataDeletionService(
        authService: AuthService(client: authClient),
        remoteStore: remote,
        preferences: preferences,
      );

      final result = await service.deleteCurrentUserData();

      expect(result.status, UserDataDeletionStatus.cloudDeleteFailed);
      expect(authClient.deleteCalls, 0);
      expect(authClient.user?.uid, 'uid-to-keep');
      expect(
        await preferences.getString(PreferenceKeys.localCoinState),
        'coins',
      );
      expect(
        await preferences.containsKey(
          PreferenceKeys.cloudAccessSuspendedForDeletion,
        ),
        isFalse,
      );
    },
  );

  test(
    'resumes local cleanup after a crash following identity deletion',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            PreferenceKeys.pendingAccountDeletionUid: 'deleted-uid',
            PreferenceKeys.cloudAccessSuspendedForDeletion: true,
            PreferenceKeys.localStatisticsState: 'history',
          });
      final authClient = _DeletionAuthClient(null);
      final remote = _RecordingRemoteStore();
      final service = UserDataDeletionService(
        authService: AuthService(client: authClient),
        remoteStore: remote,
        preferences: SharedPreferencesAsync(),
      );

      final result = await service.deleteCurrentUserData();

      expect(result.succeeded, isTrue);
      expect(remote.deletedUids, isEmpty);
      expect(authClient.deleteCalls, 0);
      final preferences = SharedPreferencesAsync();
      expect(
        await preferences.containsKey(PreferenceKeys.localStatisticsState),
        isFalse,
      );
      expect(
        await preferences.containsKey(
          PreferenceKeys.cloudAccessSuspendedForDeletion,
        ),
        isFalse,
      );
    },
  );
}
