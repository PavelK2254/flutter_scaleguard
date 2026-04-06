import 'package:scale_guard/src/core/ignore_matcher.dart';
import 'package:test/test.dart';

void main() {
  group('globPathMatch', () {
    test('prefix with ** matches subtree', () {
      expect(
        globPathMatch('lib/generated/foo.dart', 'lib/generated/**'),
        isTrue,
      );
      expect(
        globPathMatch('lib/generated/a/b.dart', 'lib/generated/**'),
        isTrue,
      );
      expect(
        globPathMatch('lib/other/foo.dart', 'lib/generated/**'),
        isFalse,
      );
    });

    test('**/*.g.dart matches nested generated files', () {
      expect(globPathMatch('lib/a.g.dart', '**/*.g.dart'), isTrue);
      expect(globPathMatch('lib/foo/bar.g.dart', '**/*.g.dart'), isTrue);
      expect(globPathMatch('lib/foo/bar.dart', '**/*.g.dart'), isFalse);
    });

    test('* matches within single segment only', () {
      expect(globPathMatch('lib/foo.dart', 'lib/*.dart'), isTrue);
      expect(globPathMatch('lib/sub/foo.dart', 'lib/*.dart'), isFalse);
    });
  });

  group('shouldIgnoreNormalizedPath', () {
    test('literal uses substring / suffix', () {
      expect(
        shouldIgnoreNormalizedPath('lib/foo.g.dart', ['.g.dart']),
        isTrue,
      );
      expect(
        shouldIgnoreNormalizedPath('lib/build/x.dart', ['/build/']),
        isTrue,
      );
    });

    test('glob pattern does not use substring fallback', () {
      expect(
        shouldIgnoreNormalizedPath('lib/extra/lib/generated/x.dart',
            ['lib/generated/**']),
        isFalse,
      );
      expect(
        shouldIgnoreNormalizedPath('lib/generated/x.dart', ['lib/generated/**']),
        isTrue,
      );
    });
  });

  group('validateGlobPattern', () {
    test('rejects ** embedded in segment', () {
      expect(validateGlobPattern('foo**bar'), isNotNull);
    });

    test('accepts ** as own segment', () {
      expect(validateGlobPattern('lib/**'), isNull);
    });
  });
}
