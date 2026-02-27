import 'package:scale_guard/scale_guard.dart';
import 'package:test/test.dart';

void main() {
  group('resolveImportPath', () {
    test('package import for own package resolves to lib path', () {
      final resolved = ProjectIndex.resolveImportPath(
        'lib/features/auth/presentation/page.dart',
        'package:my_app/features/auth/domain/entity.dart',
        'my_app',
      );
      expect(resolved, equals('lib/features/auth/domain/entity.dart'));
    });

    test('package import for external package returns null', () {
      final resolved = ProjectIndex.resolveImportPath(
        'lib/features/auth/page.dart',
        'package:get_it/get_it.dart',
        'my_app',
      );
      expect(resolved, isNull);
    });

    test('package import when packageName is null returns null', () {
      final resolved = ProjectIndex.resolveImportPath(
        'lib/foo.dart',
        'package:my_app/lib/foo.dart',
        null,
      );
      expect(resolved, isNull);
    });

    test('dart import returns null', () {
      expect(
        ProjectIndex.resolveImportPath('lib/foo.dart', 'dart:async', 'my_app'),
        isNull,
      );
    });

    test('flutter import returns null', () {
      expect(
        ProjectIndex.resolveImportPath(
            'lib/foo.dart', 'flutter:material.dart', 'my_app'),
        isNull,
      );
    });

    test('relative import resolves correctly', () {
      final resolved = ProjectIndex.resolveImportPath(
        'lib/features/auth/presentation/page.dart',
        'entity.dart',
        'my_app',
      );
      expect(resolved, equals('lib/features/auth/presentation/entity.dart'));
      final resolved2 = ProjectIndex.resolveImportPath(
        'lib/features/auth/presentation/page.dart',
        '../domain/entity.dart',
        'my_app',
      );
      expect(resolved2, equals('lib/features/auth/domain/entity.dart'));
    });

    test('relative import with .. that would leave lib returns null', () {
      final resolved = ProjectIndex.resolveImportPath(
        'lib/foo.dart',
        '../../outside.dart',
        'my_app',
      );
      expect(resolved, isNull);
    });
  });
}
