import 'package:scale_guard/scale_guard.dart';
import 'package:test/test.dart';

void main() {
  group('shouldIgnore with default patterns', () {
    late ScannerConfig config;

    setUp(() {
      config = const ScannerConfig();
    });

    test('.g.dart and .freezed.dart are ignored', () {
      expect(config.shouldIgnore('lib/features/auth/user.g.dart'), isTrue);
      expect(config.shouldIgnore('lib/features/auth/user.freezed.dart'), isTrue);
    });

    test('build/ is ignored', () {
      expect(config.shouldIgnore('lib/build/foo.dart'), isTrue);
    });

    test('generated/ is ignored', () {
      expect(config.shouldIgnore('lib/generated/code.dart'), isTrue);
      expect(config.shouldIgnore('lib/src/generated/foo.dart'), isTrue);
    });

    test('test/ and integration_test/ are ignored', () {
      expect(config.shouldIgnore('lib/test/foo_test.dart'), isTrue);
      expect(config.shouldIgnore('lib/integration_test/app_test.dart'), isTrue);
    });

    test('normal lib path is not ignored', () {
      expect(config.shouldIgnore('lib/features/auth/presentation/page.dart'),
          isFalse);
    });
  });
}
