import 'package:scale_guard/scale_guard.dart';
import 'package:test/test.dart';

void main() {
  group('CrossFeatureCouplingRule', () {
    late CrossFeatureCouplingRule rule;
    late ScannerConfig config;

    setUp(() {
      rule = CrossFeatureCouplingRule();
      config = const ScannerConfig();
    });

    test('no findings when no cross-feature imports', () {
      final index = ProjectIndex(
        files: [
          IndexedFile(
            path: 'lib/features/auth/presentation/page.dart',
            lineCount: 10,
            imports: ['lib/features/auth/domain/user.dart'],
            lines: [],
          ),
        ],
      );
      final result = rule.run(index, config);
      expect(result.findings, isEmpty);
      expect(result.penalty, 0);
    });

    test('finding when file in feature A imports feature B', () {
      final index = ProjectIndex(
        files: [
          IndexedFile(
            path: 'lib/features/auth/presentation/page.dart',
            lineCount: 10,
            imports: [
              'lib/features/auth/domain/user.dart',
              'lib/features/settings/domain/prefs.dart'
            ],
            lines: [],
          ),
        ],
      );
      final result = rule.run(index, config);
      expect(result.findings.length, 1);
      expect(result.findings.first.ruleId, 'cross_feature_coupling');
      expect(result.findings.first.file,
          'lib/features/auth/presentation/page.dart');
      expect(result.findings.first.message, contains('settings'));
      expect(result.penalty, greaterThan(0));
    });

    test('no finding for same-feature import', () {
      final index = ProjectIndex(
        files: [
          IndexedFile(
            path: 'lib/features/auth/presentation/page.dart',
            lineCount: 10,
            imports: ['lib/features/auth/domain/user.dart'],
            lines: [],
          ),
        ],
      );
      final result = rule.run(index, config);
      expect(result.findings, isEmpty);
    });

    test('finding has sourceFeaturePath and targetFeaturePath for hotspot', () {
      final index = ProjectIndex(
        files: [
          IndexedFile(
            path: 'lib/features/achievements/domain/use_case.dart',
            lineCount: 10,
            imports: ['lib/features/habits/data/habit_repository.dart'],
            lines: [],
          ),
        ],
      );
      final result = rule.run(index, config);
      expect(result.findings.length, 1);
      final f = result.findings.first;
      expect(f.sourceFeaturePath, 'lib/features/achievements');
      expect(f.targetFeaturePath, 'lib/features/habits');
      expect(ConsoleRenderer.getSourceHotspotKey(f), 'lib/features/achievements');
      expect(ConsoleRenderer.getTargetHotspotKey(f), 'lib/features/habits');
      // Consistency: example shows lib/features/achievements/... => source key is lib/features/achievements
      expect(
        ConsoleRenderer.extractFeaturePathFromFilePath(f.file),
        'lib/features/achievements',
      );
    });
  });

  group('extractFeaturePathFromFilePath', () {
    test('returns lib/features/<name> when path contains /lib/features/', () {
      expect(
        ConsoleRenderer.extractFeaturePathFromFilePath(
            'lib/features/achievements/domain/use_case.dart'),
        'lib/features/achievements',
      );
      expect(
        ConsoleRenderer.extractFeaturePathFromFilePath(
            'lib/features/habits/data/repo.dart'),
        'lib/features/habits',
      );
    });

    test('handles Windows-style paths (backslashes)', () {
      expect(
        ConsoleRenderer.extractFeaturePathFromFilePath(
            r'lib\features\achievements\domain\foo.dart'),
        'lib/features/achievements',
      );
      expect(
        ConsoleRenderer.extractFeaturePathFromFilePath(
            r'lib\features\habit_details\data\bar.dart'),
        'lib/features/habit_details',
      );
    });

    test('returns null when path does not contain /lib/features/', () {
      expect(
        ConsoleRenderer.extractFeaturePathFromFilePath('lib/other/foo.dart'),
        isNull,
      );
      expect(
        ConsoleRenderer.extractFeaturePathFromFilePath('lib/features.dart'),
        isNull,
      );
    });
  });
}
