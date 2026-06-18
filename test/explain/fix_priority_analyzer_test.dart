import 'package:scale_guard/scale_guard.dart';
import 'package:scale_guard/src/core/rule_metadata.dart';
import 'package:scale_guard/src/explain/fix_priority_analyzer.dart';
import 'package:scale_guard/src/explain/score_breakdown.dart';
import 'package:test/test.dart';

void main() {
  group('analyzeFixPriorities', () {
    test('returns empty when no aggregation or zero penalty', () {
      final report = ScanReport(
        score: 100,
        riskLevel: RiskLevel.low,
        ruleResults: const [],
        uniqueFindings: const [],
        timestamp: DateTime.utc(2026, 1, 1),
      );
      expect(analyzeFixPriorities(report), isEmpty);
    });

    test('ranks by penalty desc, finding count desc, rule id asc', () {
      final findings = [
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/features/a/a.dart',
          message: 'm',
        ),
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/features/a/b.dart',
          message: 'm',
        ),
        Finding(
          severity: FindingSeverity.medium,
          ruleId: 'god_files',
          file: 'lib/features/b/big.dart',
          message: 'm',
        ),
        Finding(
          severity: FindingSeverity.medium,
          ruleId: 'service_locator_abuse',
          file: 'lib/features/c/c.dart',
          message: 'm',
        ),
      ];
      final results = [
        RuleResult(
          ruleId: 'cross_feature_coupling',
          penalty: 10,
          findings: findings.where((f) => f.ruleId == 'cross_feature_coupling').toList(),
        ),
        RuleResult(
          ruleId: 'god_files',
          penalty: 6,
          findings: findings.where((f) => f.ruleId == 'god_files').toList(),
        ),
        RuleResult(
          ruleId: 'service_locator_abuse',
          penalty: 6,
          findings: findings.where((f) => f.ruleId == 'service_locator_abuse').toList(),
        ),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        ruleIdToCategory,
        uniqueFindings: findings,
      );
      final report = ScanReport(
        score: 78,
        riskLevel: RiskLevel.medium,
        ruleResults: results,
        uniqueFindings: findings,
        timestamp: DateTime.utc(2026, 1, 1),
        aggregation: aggregation,
      );

      final priorities = analyzeFixPriorities(report);
      expect(priorities.length, 3);
      expect(priorities[0].ruleId, 'cross_feature_coupling');
      expect(priorities[0].impact, 'High');
      expect(priorities[0].estimatedScoreGain, 10);
      expect(priorities[1].ruleId, 'god_files');
      expect(priorities[2].ruleId, 'service_locator_abuse');
    });

    test('assigns impact labels from penalty thresholds', () {
      final findings = [
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/features/a/a.dart',
          message: 'm',
        ),
      ];
      final results = [
        RuleResult(
          ruleId: 'cross_feature_coupling',
          penalty: 2,
          findings: findings,
        ),
        RuleResult(
          ruleId: 'layer_violations',
          penalty: 18,
          findings: const [],
        ),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        ruleIdToCategory,
        uniqueFindings: findings,
      );
      final report = ScanReport(
        score: 80,
        riskLevel: RiskLevel.medium,
        ruleResults: results,
        uniqueFindings: findings,
        timestamp: DateTime.utc(2026, 1, 1),
        aggregation: aggregation,
      );

      expect(analyzeFixPriorities(report).single.impact, 'Low');
    });

    test('marks capped rules and limits to top 3', () {
      final findings = <Finding>[];
      final results = <RuleResult>[];
      for (final ruleId in [
        'cross_feature_coupling',
        'layer_violations',
        'god_files',
        'service_locator_abuse',
        'hardcoded_scale_risks',
      ]) {
        findings.add(Finding(
          severity: FindingSeverity.medium,
          ruleId: ruleId,
          file: 'lib/features/x/$ruleId.dart',
          message: 'm',
        ));
        results.add(RuleResult(
          ruleId: ruleId,
          penalty: 5,
          findings: [findings.last],
        ));
      }
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        ruleIdToCategory,
        uniqueFindings: findings,
      );
      final report = ScanReport(
        score: 75,
        riskLevel: RiskLevel.medium,
        ruleResults: results,
        uniqueFindings: findings,
        timestamp: DateTime.utc(2026, 1, 1),
        aggregation: aggregation,
        capHits: ['cross_feature_coupling'],
      );

      final priorities = analyzeFixPriorities(report, limit: 3);
      expect(priorities.length, 3);
      expect(priorities.any((p) => p.ruleId == 'cross_feature_coupling' && p.isCapped),
          isTrue);
    });

    test('builds deterministic why lines', () {
      final findings = [
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/features/a/a.dart',
          message: 'm',
        ),
        Finding(
          severity: FindingSeverity.medium,
          ruleId: 'service_locator_abuse',
          file: 'lib/features/a/a.dart',
          message: 'm',
        ),
        Finding(
          severity: FindingSeverity.medium,
          ruleId: 'service_locator_abuse',
          file: 'lib/features/b/b.dart',
          message: 'm',
        ),
      ];
      final results = [
        RuleResult(
          ruleId: 'cross_feature_coupling',
          penalty: 5,
          findings: [findings.first],
        ),
        RuleResult(
          ruleId: 'service_locator_abuse',
          penalty: 4,
          findings: findings.sublist(1),
        ),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        ruleIdToCategory,
        uniqueFindings: findings,
      );
      final report = ScanReport(
        score: 91,
        riskLevel: RiskLevel.low,
        ruleResults: results,
        uniqueFindings: findings,
        timestamp: DateTime.utc(2026, 1, 1),
        aggregation: aggregation,
      );

      final byRule = {
        for (final p in analyzeFixPriorities(report)) p.ruleId: p.why,
      };
      expect(byRule['cross_feature_coupling'],
          '1 findings relate to feature-to-feature imports.');
      expect(byRule['service_locator_abuse'],
          'Service locator usage appears across 2 module paths.');
    });
  });

  group('scoreBreakdownEntries', () {
    test('returns only non-zero categories in penalty order', () {
      final results = [
        RuleResult(ruleId: 'cross_feature_coupling', penalty: 12, findings: []),
        RuleResult(ruleId: 'god_files', penalty: 8, findings: []),
        RuleResult(ruleId: 'layer_violations', penalty: 6, findings: []),
        RuleResult(
            ruleId: 'hardcoded_scale_risks', penalty: 4, findings: []),
      ];
      final agg = CategoryAggregation.fromRuleResults(
        results,
        ruleIdToCategory,
      );
      final entries = scoreBreakdownEntries(agg);
      expect(entries.map((e) => e.key).toList(), [
        'Coupling Risk',
        'Maintainability Risk',
        'Structural Risk',
        'Configuration / Release Risk',
      ]);
      expect(entries.map((e) => e.value).toList(), [12, 8, 6, 4]);
    });

    test('returns empty when total penalty is zero', () {
      final agg = CategoryAggregation.fromRuleResults([], ruleIdToCategory);
      expect(scoreBreakdownEntries(agg), isEmpty);
    });
  });
}
