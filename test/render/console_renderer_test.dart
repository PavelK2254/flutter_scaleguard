import 'dart:async';

import 'package:scale_guard/scale_guard.dart';
import 'package:test/test.dart';

/// Minimal mapping for tests (matches rule_metadata.ruleIdToCategory for used rules).
const _ruleIdToCategory = {
  'cross_feature_coupling': 'Coupling Risk',
  'layer_violations': 'Structural Risk',
};

void main() {
  group('ConsoleRenderer hotspot/example consistency', () {
    List<String> capturePrint(void Function() body) {
      final lines = <String>[];
      runZoned(body,
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) => lines.add(line),
          ));
      return lines;
    }

    test('Hotspot (source) and Examples come from same feature when possible',
        () {
      // Top source: achievements (4 findings). Examples should be 3 from achievements.
      final findings = [
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/features/achievements/domain/a.dart',
          message: 'import habits',
          sourceFeaturePath: 'lib/features/achievements',
          targetFeaturePath: 'lib/features/habits',
          fromFeature: 'achievements',
          toFeature: 'habits',
          resolvedImportedPath: 'lib/features/habits/repo.dart',
        ),
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/features/achievements/domain/b.dart',
          message: 'import habits',
          sourceFeaturePath: 'lib/features/achievements',
          targetFeaturePath: 'lib/features/habits',
          fromFeature: 'achievements',
          toFeature: 'habits',
          resolvedImportedPath: 'lib/features/habits/repo.dart',
        ),
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/features/achievements/data/c.dart',
          message: 'import habits',
          sourceFeaturePath: 'lib/features/achievements',
          targetFeaturePath: 'lib/features/habits',
          fromFeature: 'achievements',
          toFeature: 'habits',
          resolvedImportedPath: 'lib/features/habits/repo.dart',
        ),
        Finding(
          severity: FindingSeverity.medium,
          ruleId: 'cross_feature_coupling',
          file: 'lib/features/habit_details/data/d.dart',
          message: 'import habits',
          sourceFeaturePath: 'lib/features/habit_details',
          targetFeaturePath: 'lib/features/habits',
          fromFeature: 'habit_details',
          toFeature: 'habits',
          resolvedImportedPath: 'lib/features/habits/repo.dart',
        ),
      ];
      final results = [
        RuleResult(
          ruleId: 'cross_feature_coupling',
          penalty: 10,
          findings: findings,
        ),
        RuleResult(
          ruleId: 'layer_violations',
          penalty: 1,
          findings: [],
        ),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        _ruleIdToCategory,
        uniqueFindings: findings,
      );
      final report = ScanReport(
        score: 80,
        riskLevel: RiskLevel.low,
        ruleResults: results,
        uniqueFindings: findings,
        timestamp: DateTime.now().toUtc(),
        aggregation: aggregation,
      );
      final lines = capturePrint(() => ConsoleRenderer.render(report));

      expect(
        lines.any((l) => l.startsWith('Hotspot (source): lib/features/achievements')),
        isTrue,
        reason: 'Top source should be achievements (4 findings)',
      );
      final examplesStart =
          lines.indexWhere((l) => l == 'Examples:');
      expect(examplesStart, greaterThanOrEqualTo(0));
      final exampleLines = lines
          .skip(examplesStart + 1)
          .take(5)
          .where((l) => l.trimLeft().startsWith('lib/'))
          .toList();
      expect(exampleLines, isNotEmpty);
      for (final line in exampleLines) {
        if (line.contains('(+') || line.startsWith('(Note:')) break;
        expect(
          line.contains('lib/features/achievements/'),
          isTrue,
          reason: 'Examples should be from printed hotspot (achievements)',
        );
      }
      expect(
        lines.any((l) => l.contains('hotspot/example mismatch detected')),
        isFalse,
        reason: 'No mismatch when all examples are from hotspot',
      );
    });

    test('mismatch note when examples include findings from non-hotspot feature',
        () {
      // Top source: achievements with 4 findings but only 2 unique files.
      // habit_details has 2 findings (2 files). So we take 2 from achievements,
      // then 1 from habit_details -> one example has different source -> mismatch.
      final findings = [
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/features/achievements/domain/a.dart',
          message: 'x',
          sourceFeaturePath: 'lib/features/achievements',
          targetFeaturePath: 'lib/features/habits',
          fromFeature: 'achievements',
          toFeature: 'habits',
          resolvedImportedPath: 'lib/features/habits/repo.dart',
        ),
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/features/achievements/domain/b.dart',
          message: 'x',
          sourceFeaturePath: 'lib/features/achievements',
          targetFeaturePath: 'lib/features/habits',
          fromFeature: 'achievements',
          toFeature: 'habits',
          resolvedImportedPath: 'lib/features/habits/repo.dart',
        ),
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/features/habit_details/data/c.dart',
          message: 'x',
          sourceFeaturePath: 'lib/features/habit_details',
          targetFeaturePath: 'lib/features/habits',
          fromFeature: 'habit_details',
          toFeature: 'habits',
          resolvedImportedPath: 'lib/features/habits/repo.dart',
        ),
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/features/habit_details/data/d.dart',
          message: 'x',
          sourceFeaturePath: 'lib/features/habit_details',
          targetFeaturePath: 'lib/features/habits',
          fromFeature: 'habit_details',
          toFeature: 'habits',
          resolvedImportedPath: 'lib/features/habits/repo.dart',
        ),
      ];
      final results = [
        RuleResult(
          ruleId: 'cross_feature_coupling',
          penalty: 10,
          findings: findings,
        ),
        RuleResult(ruleId: 'layer_violations', penalty: 1, findings: []),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        _ruleIdToCategory,
        uniqueFindings: findings,
      );
      final report = ScanReport(
        score: 80,
        riskLevel: RiskLevel.low,
        ruleResults: results,
        uniqueFindings: findings,
        timestamp: DateTime.now().toUtc(),
        aggregation: aggregation,
      );
      final lines = capturePrint(() => ConsoleRenderer.render(report));

      // achievements has 2 findings, habit_details has 2. Tie-break: alphabetical -> achievements.
      expect(
        lines.any((l) => l.startsWith('Hotspot (source): lib/features/achievements')),
        isTrue,
      );
      // We have 2 unique files in achievements, 2 in habit_details. We take 2 from achievements, then 1 from habit_details.
      // So one example is from habit_details -> mismatch.
      expect(
        lines.any((l) => l.contains('hotspot/example mismatch detected')),
        isTrue,
        reason: 'Mismatch note when an example is from a non-hotspot feature',
      );
    });
  });
}
