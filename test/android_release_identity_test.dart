import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android production identity is consistent', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/postureguard/app/MainActivity.kt',
    ).readAsStringSync();

    expect(gradle, contains('namespace = "com.postureguard.app"'));
    expect(gradle, contains('applicationId = "com.postureguard.app"'));
    expect(gradle, isNot(contains('com.example.postureguard')));
    expect(activity, startsWith('package com.postureguard.app'));
    expect(
      File(
        'android/app/src/main/kotlin/com/example/postureguard/MainActivity.kt',
      ).existsSync(),
      isFalse,
    );
  });

  test('Android display name and launcher resources are production-ready', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final strings = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:label="@string/app_name"'));
    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
    expect(strings, contains('<string name="app_name">Posture Guard</string>'));
    expect(
      File(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml',
      ).existsSync(),
      isTrue,
    );

    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      final directory = 'android/app/src/main/res/mipmap-$density';
      expect(File('$directory/ic_launcher.png').lengthSync(), greaterThan(0));
      expect(
        File('$directory/ic_launcher_round.png').lengthSync(),
        greaterThan(0),
      );
      expect(
        File('$directory/ic_launcher_foreground.png').lengthSync(),
        greaterThan(0),
      );
    }
  });

  test('notifications use the branded monochrome small icon', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final notificationService = File(
      'lib/services/notification_service.dart',
    ).readAsStringSync();
    final monitoringService = File(
      'lib/services/monitoring_service.dart',
    ).readAsStringSync();
    final icon = File(
      'android/app/src/main/res/drawable/ic_stat_posture_guard.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('com.postureguard.app.service.NOTIFICATION_ICON'),
    );
    expect(manifest, contains('@drawable/ic_stat_posture_guard'));
    expect(notificationService, contains("'@drawable/ic_stat_posture_guard'"));
    expect(monitoringService, contains('notificationIcon: const'));
    expect(icon, contains('android:fillColor="#FFFFFFFF"'));
    expect(icon, isNot(contains('Posture Guard')));
  });
}
