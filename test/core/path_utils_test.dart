import 'package:scale_guard/src/core/path_utils.dart';
import 'package:test/test.dart';

void main() {
  group('normalizePath', () {
    test('converts Windows backslashes to forward slashes', () {
      expect(normalizePath(r'lib\features\auth\page.dart'),
          equals('lib/features/auth/page.dart'));
      expect(normalizePath(r'C:\dev\proj\lib\foo.dart'),
          equals('C:/dev/proj/lib/foo.dart'));
    });

    test('collapses duplicate slashes', () {
      expect(normalizePath('lib//features///page.dart'),
          equals('lib/features/page.dart'));
    });

    test('resolves . and .. segments', () {
      expect(normalizePath('a/b/../c'), equals('a/c'));
      expect(normalizePath('lib/features/auth/../domain/entity.dart'),
          equals('lib/features/domain/entity.dart'));
      expect(normalizePath('a/./b/./c'), equals('a/b/c'));
      expect(normalizePath('a/b/../..'), equals(''));
    });

    test('preserves case', () {
      expect(normalizePath('Lib/Features/Page.dart'),
          equals('Lib/Features/Page.dart'));
    });

    test('empty or blank returns empty', () {
      expect(normalizePath(''), equals(''));
    });
  });

  group('toProjectRelativePath', () {
    test('returns relative path when absolute is under project root', () {
      expect(
        toProjectRelativePath('C/proj/lib/foo.dart', 'C/proj'),
        equals('lib/foo.dart'),
      );
      expect(
        toProjectRelativePath('C/proj/lib/features/auth/page.dart', 'C/proj'),
        equals('lib/features/auth/page.dart'),
      );
    });

    test('returns empty when path equals root', () {
      expect(toProjectRelativePath('C/proj', 'C/proj'), equals(''));
    });

    test('returns path as-is when not under root', () {
      expect(
        toProjectRelativePath('C/other/lib/foo.dart', 'C/proj'),
        equals('C/other/lib/foo.dart'),
      );
    });
  });

  group('toAbsolutePath', () {
    test('joins project root and relative path', () {
      expect(
        toAbsolutePath('C/proj', 'lib/foo.dart'),
        equals('C/proj/lib/foo.dart'),
      );
      expect(toAbsolutePath('C/proj', ''), equals('C/proj'));
    });
  });
}
