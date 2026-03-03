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
      final report = ScanReport(
        score: 0,
        riskLevel: RiskLevel.low,
        ruleResults: [result],
        uniqueFindings: result.findings,
        timestamp: DateTime.now().toUtc(),
        moduleIndex: null,
      );
      expect(ConsoleRenderer.getSourceHotspotKey(f, report), 'lib/features/achievements');
      expect(ConsoleRenderer.getTargetHotspotKey(f), 'lib/features/habits');
    });
  });
}
