import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'auth_service.dart';

class UserDatabasePaths {
  UserDatabasePaths(String uid) : uid = _validateUid(uid);

  final String uid;

  String get root => 'users/$uid';

  String get settings => '$root/settings';

  String get coins => '$root/coins';

  String get cosmetics => '$root/cosmetics';

  String get dailyStatsRoot => '$root/daily_stats';

  String dailyStats(String dateKey) => '$dailyStatsRoot/$dateKey';

  static String _validateUid(String value) {
    final uid = value.trim();
    if (uid.isEmpty || uid.contains('/')) {
      throw ArgumentError.value(value, 'uid', 'Must be a non-empty path key.');
    }
    return uid;
  }
}

class CloudAuthenticationUnavailable implements Exception {
  const CloudAuthenticationUnavailable();

  @override
  String toString() => 'Firebase user authentication is unavailable.';
}

class UserDatabaseReferenceFactory {
  UserDatabaseReferenceFactory({
    AuthService? authService,
    FirebaseDatabase? database,
  }) : _authService = authService ?? AuthService.instance,
       _database = database;

  final AuthService _authService;
  final FirebaseDatabase? _database;

  Future<DatabaseReference> settings() {
    return _reference((paths) => paths.settings);
  }

  Future<DatabaseReference> coins() {
    return _reference((paths) => paths.coins);
  }

  Future<DatabaseReference> cosmetics() {
    return _reference((paths) => paths.cosmetics);
  }

  Future<DatabaseReference> dailyStatsRoot() {
    return _reference((paths) => paths.dailyStatsRoot);
  }

  Future<DatabaseReference> dailyStats(String dateKey) {
    return _reference((paths) => paths.dailyStats(dateKey));
  }

  Future<DatabaseReference> _reference(
    String Function(UserDatabasePaths paths) pathFor,
  ) async {
    if (_database == null && Firebase.apps.isEmpty) {
      throw const CloudAuthenticationUnavailable();
    }
    final uid = await _authService.ensureUid();
    if (uid == null) throw const CloudAuthenticationUnavailable();
    final database = _database ?? FirebaseDatabase.instance;
    return database.ref(pathFor(UserDatabasePaths(uid)));
  }
}
