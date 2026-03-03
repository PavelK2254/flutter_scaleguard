import 'package:scale_guard/src/core/path_utils.dart' as path_utils;
import 'package:scale_guard/src/core/module_root.dart';
import 'package:test/test.dart';

void main() {
  group('moduleRootKey', () {
    test('lib/features/<name>/... → lib/features/<name>', () {
      expect(
        moduleRootKey('lib/features/habit_details/domain/use_case.dart'),
        'lib/features/habit_details',
      );
      expect(
        moduleRootKey('lib/features/achievements/data/repo.dart'),
        'lib/features/achievements',
      );
    });

    test('lib/feature/<name>/... → lib/feature/<name>', () {
      expect(
        moduleRootKey('lib/feature/add_card/domain/use_case.dart'),
        'lib/feature/add_card',
      );
      expect(
        moduleRootKey('lib/feature/buy_gift_card/data/repo.dart'),
        'lib/feature/buy_gift_card',
      );
    });

    test('lib/modules/<name>/... → lib/modules/<name>', () {
      expect(
        moduleRootKey('lib/modules/auth/domain/entity.dart'),
        'lib/modules/auth',
      );
    });

    test('lib/src/<name>/... → lib/src/<name>', () {
      expect(
        moduleRootKey('lib/src/network/http_client.dart'),
        'lib/src/network',
      );
    });

    test('fallback depth-3 → lib/<a>/<b>', () {
      expect(
        moduleRootKey('lib/core/network/http_client.dart'),
        'lib/core/network',
      );
    });

    test('fallback depth-2 → lib/<a>', () {
      expect(
        moduleRootKey('lib/core/foo.dart'),
        'lib/core',
      );
    });

    test('Windows path normalizes to lib/feature/add_card', () {
      expect(
        moduleRootKey(path_utils.normalizePath(r'lib\feature\add_card\domain\use_case.dart')),
        'lib/feature/add_card',
      );
    });

    test('lib/other/foo.dart returns lib/other (fallback depth-2)', () {
      expect(moduleRootKey('lib/other/foo.dart'), 'lib/other');
    });

    test('lib/features.dart returns lib (fallback depth-2 single segment)', () {
      expect(moduleRootKey('lib/features.dart'), 'lib');
    });
  });
}
