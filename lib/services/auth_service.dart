import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preferences_service.dart';

class AuthIdentity {
  const AuthIdentity(this.uid);

  final String uid;
}

abstract interface class AuthClient {
  AuthIdentity? get currentUser;

  Future<AuthIdentity> signInAnonymously();

  Future<void> deleteCurrentUser();
}

class FirebaseAuthClient implements AuthClient {
  FirebaseAuthClient({FirebaseAuth? auth}) : _auth = auth;

  final FirebaseAuth? _auth;

  FirebaseAuth get _resolvedAuth => _auth ?? FirebaseAuth.instance;

  @override
  AuthIdentity? get currentUser {
    final user = _resolvedAuth.currentUser;
    return user == null ? null : AuthIdentity(user.uid);
  }

  @override
  Future<AuthIdentity> signInAnonymously() async {
    final credential = await _resolvedAuth.signInAnonymously();
    final user = credential.user;
    if (user == null || user.uid.isEmpty) {
      throw StateError('Anonymous sign-in returned no Firebase user.');
    }
    return AuthIdentity(user.uid);
  }

  @override
  Future<void> deleteCurrentUser() async {
    final user = _resolvedAuth.currentUser;
    if (user == null) throw StateError('There is no Firebase user to delete.');
    await user.delete();
  }
}

abstract interface class AuthAccessPolicy {
  Future<bool> isCloudAccessSuspended();

  Future<void> setCloudAccessSuspended(bool suspended);
}

class SharedPreferencesAuthAccessPolicy implements AuthAccessPolicy {
  SharedPreferencesAuthAccessPolicy({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<bool> isCloudAccessSuspended() async {
    return await _preferences.getBool(
          PreferenceKeys.cloudAccessSuspendedForDeletion,
        ) ??
        false;
  }

  @override
  Future<void> setCloudAccessSuspended(bool suspended) async {
    if (suspended) {
      await _preferences.setBool(
        PreferenceKeys.cloudAccessSuspendedForDeletion,
        true,
      );
    } else {
      await _preferences.remove(PreferenceKeys.cloudAccessSuspendedForDeletion);
    }
  }
}

class AuthService {
  AuthService({
    AuthClient? client,
    AuthAccessPolicy? accessPolicy,
    this.retryDelay = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _client = client ?? FirebaseAuthClient(),
       _accessPolicy = accessPolicy ?? SharedPreferencesAuthAccessPolicy(),
       _clock = clock ?? DateTime.now;

  static final AuthService instance = AuthService();

  final AuthClient _client;
  final AuthAccessPolicy _accessPolicy;
  final Duration retryDelay;
  final DateTime Function() _clock;
  Future<AuthIdentity?>? _signInInFlight;
  DateTime? _lastFailureAt;

  AuthIdentity? get currentUser {
    try {
      return _validIdentity(_client.currentUser);
    } catch (_) {
      return null;
    }
  }

  String? get currentUid => currentUser?.uid;

  Future<AuthIdentity?> ensureSignedIn({bool forceRetry = false}) async {
    if (await _accessPolicy.isCloudAccessSuspended()) return null;
    return _ensureSignedIn(forceRetry: forceRetry);
  }

  Future<AuthIdentity?> _ensureSignedIn({required bool forceRetry}) {
    final existingUser = currentUser;
    if (existingUser != null) return Future.value(existingUser);

    final inFlight = _signInInFlight;
    if (inFlight != null) return inFlight;

    final lastFailureAt = _lastFailureAt;
    if (!forceRetry &&
        lastFailureAt != null &&
        _clock().difference(lastFailureAt) < retryDelay) {
      return Future.value(null);
    }

    late final Future<AuthIdentity?> operation;
    operation = _signIn().whenComplete(() {
      if (identical(_signInInFlight, operation)) _signInInFlight = null;
    });
    _signInInFlight = operation;
    return operation;
  }

  Future<String?> ensureUid({bool forceRetry = false}) async {
    return (await ensureSignedIn(forceRetry: forceRetry))?.uid;
  }

  Future<void> suspendCloudAccessForDeletion() {
    return _accessPolicy.setCloudAccessSuspended(true);
  }

  Future<void> resumeCloudAccessAfterDeletion() {
    return _accessPolicy.setCloudAccessSuspended(false);
  }

  Future<void> deleteCurrentUser() => _client.deleteCurrentUser();

  Future<AuthIdentity?> _signIn() async {
    try {
      final user = _validIdentity(await _client.signInAnonymously());
      if (user == null) {
        throw StateError('Anonymous sign-in returned an empty Firebase UID.');
      }
      _lastFailureAt = null;
      return user;
    } on FirebaseAuthException catch (error) {
      _lastFailureAt = _clock();
      if (kDebugMode) {
        if (error.code == 'operation-not-allowed') {
          debugPrint('Firebase Anonymous Authentication is not enabled.');
        } else {
          debugPrint('Firebase anonymous sign-in is temporarily unavailable.');
        }
      }
      return null;
    } catch (_) {
      _lastFailureAt = _clock();
      if (kDebugMode) {
        debugPrint('Firebase anonymous sign-in is temporarily unavailable.');
      }
      return null;
    }
  }

  AuthIdentity? _validIdentity(AuthIdentity? identity) {
    if (identity == null || identity.uid.trim().isEmpty) return null;
    return identity;
  }
}
