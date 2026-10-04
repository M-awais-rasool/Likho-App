import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/api/api_client.dart';

void main() {
  test('appVersion is the version in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)!.group(1);
    expect(appVersion, version);
  });

  test('requests say the platform and version', () {
    final h = deviceHeaders();
    expect(h['X-Likho-App-Version'], appVersion);
    expect(h['X-Likho-Platform'], isNotEmpty);
  });
}
