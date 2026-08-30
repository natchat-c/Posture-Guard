import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

({int width, int height, int colorType}) _pngInfo(String path) {
  final bytes = File(path).readAsBytesSync();
  expect(bytes.length, greaterThan(26), reason: path);
  expect(bytes.sublist(1, 4), [0x50, 0x4e, 0x47], reason: path);
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  return (
    width: data.getUint32(16),
    height: data.getUint32(20),
    colorType: bytes[25],
  );
}

void main() {
  test('iOS display identity and permission text are release-facing', () {
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    expect(
      info,
      contains(
        '<key>CFBundleDisplayName</key>\n\t<string>Posture Guard</string>',
      ),
    );
    expect(
      info,
      contains('<key>CFBundleName</key>\n\t<string>Posture Guard</string>'),
    );
    expect(info, isNot(contains('<string>Postureguard</string>')));
    expect(
      info,
      contains(
        'Posture Guard uses the front camera for optional posture '
        'assistance. Images are processed on this device and are never saved '
        'or uploaded.',
      ),
    );
    expect(info, isNot(contains('NSLocation')));
    expect(info, isNot(contains('Usage Access')));

    final portraitEntries = RegExp(
      '<string>UIInterfaceOrientation[^<]+</string>',
    ).allMatches(info).map((match) => match.group(0)).toList();
    expect(portraitEntries, hasLength(2));
    expect(
      portraitEntries,
      everyElement('<string>UIInterfaceOrientationPortrait</string>'),
    );
  });

  test('all Apple icon slots use correctly sized opaque PNG files', () {
    const directory = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final contents =
        jsonDecode(File('$directory/Contents.json').readAsStringSync())
            as Map<String, dynamic>;
    final images = (contents['images'] as List<dynamic>).cast<Map>();
    expect(images, isNotEmpty);

    for (final image in images) {
      final filename = image['filename'] as String;
      final points = double.parse((image['size'] as String).split('x').first);
      final scale = int.parse((image['scale'] as String).replaceAll('x', ''));
      final expectedPixels = (points * scale).round();
      final file = File('$directory/$filename');
      expect(file.existsSync(), isTrue, reason: filename);
      final png = _pngInfo(file.path);
      expect(png.width, expectedPixels, reason: filename);
      expect(png.height, expectedPixels, reason: filename);
      expect(png.colorType, 2, reason: '$filename must not contain alpha');
    }
  });

  test('native launch screen uses the approved full-logo asset on white', () {
    const directory = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
    final expected = <String, int>{
      'LaunchImage.png': 220,
      'LaunchImage@2x.png': 440,
      'LaunchImage@3x.png': 660,
    };
    for (final entry in expected.entries) {
      final png = _pngInfo('$directory/${entry.key}');
      expect(png.width, entry.value);
      expect(png.height, entry.value);
    }

    final storyboard = File(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();
    expect(storyboard, contains('image="LaunchImage"'));
    expect(storyboard, contains('red="1" green="1" blue="1" alpha="1"'));
    expect(storyboard, contains('width="220" height="220"'));
    expect(storyboard, isNot(contains('Flutter')));
  });

  test('existing Firebase iOS registration remains internally consistent', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final firebaseOptions = File(
      'lib/firebase_options.dart',
    ).readAsStringSync();

    expect(
      RegExp(
        r'PRODUCT_BUNDLE_IDENTIFIER = com\.example\.postureguard;',
      ).allMatches(project),
      hasLength(3),
    );
    expect(
      firebaseOptions,
      contains("iosBundleId: 'com.example.postureguard'"),
    );
    expect(
      firebaseOptions,
      contains("appId: '1:616136459870:ios:41b05d69081fa01ae216cf'"),
    );
  });
}
