import 'package:flutter_test/flutter_test.dart';

import 'package:wisklauncher/domain/services/java_runtime_manager.dart';

void main() {
  group('JavaRuntimeManager.recommendedMajorFor', () {
    test('uses explicit declaration when present', () {
      expect(
          JavaRuntimeManager.recommendedMajorFor(
              versionDeclared: 21, versionId: '1.21.4'),
          21);
    });

    test('1.8.9 -> Java 8', () {
      expect(
          JavaRuntimeManager.recommendedMajorFor(
              versionDeclared: null, versionId: '1.8.9'),
          8);
    });

    test('1.18.2 -> Java 17', () {
      expect(
          JavaRuntimeManager.recommendedMajorFor(
              versionDeclared: null, versionId: '1.18.2'),
          17);
    });

    test('1.21 -> Java 21', () {
      expect(
          JavaRuntimeManager.recommendedMajorFor(
              versionDeclared: null, versionId: '1.21.4'),
          21);
    });
  });
}
