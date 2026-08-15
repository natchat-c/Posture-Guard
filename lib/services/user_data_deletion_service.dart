import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'preferences_service.dart';
import 'user_database_paths.dart';

abstract interface class UserDataRemoteStore {
  Future<void> deleteUserNode(String uid);
}

class FirebaseUserDataRemoteStore implements UserDataRemoteStore {
  FirebaseUserDataRemoteStore({FirebaseDatabase? database})
    : _database = database;

  final FirebaseDatabase? _database;

  @override
  Future<void> deleteUserNode(String uid) async {
    if (_database == null && Firebase.apps.isEmpty) {
      throw StateError('Firebase is not initialized.');
    }
    final database = _database ?? FirebaseDatabase.instance;
    await database.ref(UserDatabasePaths(uid).root).remove();
  }
}

abstract interface class UserLocalDataStore {
  Future<void> deleteUserData();
}

class SharedPreferencesUserLocalDataStore implements UserLocalDataStore {
  SharedPreferencesUserLocalDataStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<void> deleteUserData() async {
    for (final key in PreferenceKeys.userDataKeys) {
      await _preferences.remove(key);
    }
  }
}

enum UserDataDeletionStatus {
  success,
  noAuthenticatedUser,
  cloudDeleteFailed,
  authDeleteFailed,
  localDeleteFailed,
}

class UserDataDeletionResult {
  const UserDataDeletionResult(this.status);

  final UserDataDeletionStatus status;

  bool get succeeded => status == UserDataDeletionStatus.success;

  bool get cloudDataDeleted {
    return status == UserDataDeletionStatus.success ||
        status == UserDataDeletionStatus.authDeleteFailed ||
        status == UserDataDeletionStatus.localDeleteFailed;
  }
}

class UserDataDeletionService {
  UserDataDeletionService({
    AuthService? authService,
    UserDataRemoteStore? remoteStore,
    UserLocalDataStore? localDataStore,
    SharedPreferencesAsync? preferences,
  }) : _authService = authService ?? AuthService.instance,
       _remoteStore = remoteStore ?? FirebaseUserDataRemoteStore(),
       _localDataStore =
           localDataStore ?? SharedPreferencesUserLocalDataStore(),
       _preferences = preferences ?? SharedPreferencesAsync();

  final AuthService _authService;
  final UserDataRemoteStore _remoteStore;
  final UserLocalDataStore _localDataStore;
  final SharedPreferencesAsync _preferences;

  Future<UserDataDeletionResult> deleteCurrentUserData() async {
    final pendingLocalCleanup =
        await _preferences.getBool(
          PreferenceKeys.pendingLocalCleanupAfterAccountDeletion,
        ) ??
        false;
    if (pendingLocalCleanup) return _finishLocalCleanup();

    final pendingUid = await _preferences.getString(
      PreferenceKeys.pendingAccountDeletionUid,
    );
    if (pendingUid != null && pendingUid.isNotEmpty) {
      return _finishIdentityDeletion(pendingUid);
    }

    final identity =
        _authService.currentUser ??
        await _authService.ensureSignedIn(forceRetry: true);
    if (identity == null) {
      return const UserDataDeletionResult(
        UserDataDeletionStatus.noAuthenticatedUser,
      );
    }

    await _authService.suspendCloudAccessForDeletion();
    try {
      await _remoteStore.deleteUserNode(identity.uid);
    } catch (_) {
      await _authService.resumeCloudAccessAfterDeletion();
      return const UserDataDeletionResult(
        UserDataDeletionStatus.cloudDeleteFailed,
      );
    }

    await _preferences.setString(
      PreferenceKeys.pendingAccountDeletionUid,
      identity.uid,
    );
    return _finishIdentityDeletion(identity.uid);
  }

  Future<UserDataDeletionResult> _finishIdentityDeletion(String uid) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        if (currentUser.uid != uid) {
          return const UserDataDeletionResult(
            UserDataDeletionStatus.authDeleteFailed,
          );
        }
        await _authService.deleteCurrentUser();
      }
    } catch (_) {
      return const UserDataDeletionResult(
        UserDataDeletionStatus.authDeleteFailed,
      );
    }

    await _preferences.setBool(
      PreferenceKeys.pendingLocalCleanupAfterAccountDeletion,
      true,
    );
    return _finishLocalCleanup();
  }

  Future<UserDataDeletionResult> _finishLocalCleanup() async {
    try {
      await _localDataStore.deleteUserData();
      await _preferences.remove(
        PreferenceKeys.pendingLocalCleanupAfterAccountDeletion,
      );
      await _preferences.remove(PreferenceKeys.pendingAccountDeletionUid);
      await _authService.resumeCloudAccessAfterDeletion();
      return const UserDataDeletionResult(UserDataDeletionStatus.success);
    } catch (_) {
      return const UserDataDeletionResult(
        UserDataDeletionStatus.localDeleteFailed,
      );
    }
  }
}
