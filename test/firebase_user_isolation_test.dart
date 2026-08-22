import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/services/user_database_paths.dart';

void main() {
  test('different Firebase UIDs have isolated user roots', () {
    final first = UserDatabasePaths('uid-A');
    final second = UserDatabasePaths('uid-B');

    expect(first.root, 'users/uid-A');
    expect(second.root, 'users/uid-B');
    expect(first.root, isNot(second.root));
    expect(first.cosmetics, 'users/uid-A/cosmetics');
    expect(second.cosmetics, 'users/uid-B/cosmetics');
    expect(first.cosmetics, isNot(second.cosmetics));
  });

  test(
    'all existing user data keeps its schema under the authenticated UID',
    () {
      final paths = UserDatabasePaths('firebase-user-123');

      expect(paths.settings, 'users/firebase-user-123/settings');
      expect(paths.coins, 'users/firebase-user-123/coins');
      expect(paths.cosmetics, 'users/firebase-user-123/cosmetics');
      expect(paths.dailyStatsRoot, 'users/firebase-user-123/daily_stats');
      expect(
        paths.dailyStats('2026-08-15'),
        'users/firebase-user-123/daily_stats/2026-08-15',
      );
    },
  );

  test('an empty or path-like UID cannot construct a database path', () {
    expect(() => UserDatabasePaths(''), throwsArgumentError);
    expect(() => UserDatabasePaths('   '), throwsArgumentError);
    expect(() => UserDatabasePaths('uid/other'), throwsArgumentError);
  });

  test('production Dart code has no legacy shared-user fallback', () {
    final legacyUid = ['demo', 'user'].join('_');
    final productionFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in productionFiles) {
      expect(
        file.readAsStringSync(),
        isNot(contains(legacyUid)),
        reason: '${file.path} must resolve cloud paths from Firebase Auth.',
      );
    }
  });

  test('background statistics sync is wired to its isolate auth service', () {
    final source = File(
      'lib/services/monitoring_service.dart',
    ).readAsStringSync();

    expect(source, contains('DartPluginRegistrant.ensureInitialized()'));
    expect(source, contains('_authService.ensureSignedIn(forceRetry: true)'));
    expect(source, contains('authService: _authService'));
  });

  test('Realtime Database rules isolate users and deny all other access', () {
    final rulesFile = File('database.rules.json');
    final rules =
        jsonDecode(rulesFile.readAsStringSync()) as Map<String, dynamic>;
    final root = rules['rules'] as Map<String, dynamic>;
    final users = root['users'] as Map<String, dynamic>;
    final user = users[r'$uid'] as Map<String, dynamic>;

    expect(root['.read'], isFalse);
    expect(root['.write'], isFalse);
    expect(user['.read'], 'auth != null && auth.uid === \$uid');
    expect(user['.write'], 'auth != null && auth.uid === \$uid');

    final firebaseConfig =
        jsonDecode(File('firebase.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(
      (firebaseConfig['database'] as Map<String, dynamic>)['rules'],
      'database.rules.json',
    );
  });
}
