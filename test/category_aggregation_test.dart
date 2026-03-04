import 'package:scale_guard/scale_guard.dart';
import 'package:test/test.dart';

void main() {
  final ruleIdToCategory = {
    'layer_violations': 'Structural Risk',
    'shared_boundary_leakage': 'Structural Risk',
    'cross_feature_coupling': 'Coupling Risk',
    'service_locator_abuse': 'Coupling Risk',
    'god_files': 'Maintainability Risk',
    'hardcoded_scale_risks': 'Configuration / Release Risk',
  };

  group('CategoryAggregation', () {
    test('empty results yields empty aggregation', () {
      final agg = CategoryAggregation.fromRuleResults([], ruleIdToCategory);
      expect(agg.totalPenalty, 0.0);
      expect(agg.categoryScores, isEmpty);
      expect(agg.dominantCategory, '');
      expect(agg.mostExpensiveRuleId, '');
      expect(agg.mostExpensivePenalty, 0.0);
      expect(agg.penaltyByCategory.length, 4);
      expect(agg.penaltyByCategory['Structural Risk'], 0.0);
      expect(agg.penaltyByCategory['Coupling Risk'], 0.0);
      expect(agg.penaltyByCategory['Maintainability Risk'], 0.0);
      expect(agg.penaltyByCategory['Configuration / Release Risk'], 0.0);
    });

    test('all zero penalty yields empty aggregation (no risk signal)', () {
      final results = [
        RuleResult(ruleId: 'layer_violations', penalty: 0, findings: []),
        RuleResult(ruleId: 'god_files', penalty: 0, findings: []),
      ];
      final agg =
          CategoryAggregation.fromRuleResults(results, ruleIdToCategory);
      expect(agg.totalPenalty, 0.0);
      expect(agg.categoryScores, isEmpty);
      expect(agg.dominantCategory, '');
      expect(agg.mostExpensiveRuleId, '');
      expect(agg.mostExpensivePenalty, 0.0);
      expect(agg.penaltyByCategory.length, 4);
      expect(agg.penaltyByCategory['Structural Risk'], 0.0);
      expect(agg.penaltyByCategory['Configuration / Release Risk'], 0.0);
    });

    test('single rule aggregates to one category', () {
      final results = [
        RuleResult(
          ruleId: 'layer_violations',
          penalty: 10,
          findings: [
            Finding(
              severity: FindingSeverity.high,
              ruleId: 'layer_violations',
              file: 'a.dart',
              message: 'm',
            ),
            Finding(
              severity: FindingSeverity.medium,
              ruleId: 'layer_violations',
              file: 'b.dart',
              message: 'm',
            ),
          ],
        ),
      ];
      final agg =
          CategoryAggregation.fromRuleResults(results, ruleIdToCategory);
      expect(agg.totalPenalty, 10.0);
      expect(agg.categoryScores.length, 1);
      expect(agg.categoryScores.first.category, 'Structural Risk');
      expect(agg.categoryScores.first.totalPenalty, 10.0);
      expect(agg.categoryScores.first.highCount, 1);
      expect(agg.categoryScores.first.mediumCount, 1);
      expect(agg.dominantCategory, 'Structural Risk');
      expect(agg.mostExpensiveRuleId, 'layer_violations');
      expect(agg.mostExpensivePenalty, 10.0);
      expect(agg.penaltyByCategory['Structural Risk'], 10.0);
      expect(agg.penaltyByCategory['Coupling Risk'], 0.0);
      expect(agg.penaltyByCategory['Maintainability Risk'], 0.0);
      expect(agg.penaltyByCategory['Configuration / Release Risk'], 0.0);
    });

    test('penaltyByCategory has all four canonical keys, correct values, deterministic order', () {
      final results = [
        RuleResult(ruleId: 'god_files', penalty: 5, findings: []),
        RuleResult(ruleId: 'layer_violations', penalty: 10, findings: []),
        RuleResult(ruleId: 'cross_feature_coupling', penalty: 10, findings: []),
      ];
      final agg =
          CategoryAggregation.fromRuleResults(results, ruleIdToCategory);
      expect(agg.totalPenalty, 25.0);
      expect(agg.penaltyByCategory.length, 4);
      expect(agg.penaltyByCategory['Structural Risk'], 10.0);
      expect(agg.penaltyByCategory['Coupling Risk'], 10.0);
      expect(agg.penaltyByCategory['Maintainability Risk'], 5.0);
      expect(agg.penaltyByCategory['Configuration / Release Risk'], 0.0);
      // Order: penalty desc, then name asc. So Coupling 10, Structural 10, Maintainability 5, Config 0.
      final keys = agg.penaltyByCategory.keys.toList();
      expect(keys[0], 'Coupling Risk');
      expect(keys[1], 'Structural Risk');
      expect(keys[2], 'Maintainability Risk');
      expect(keys[3], 'Configuration / Release Risk');
    });

    test('category scores sorted by totalPenalty desc then category asc', () {
      final results = [
        RuleResult(ruleId: 'god_files', penalty: 5, findings: []),
        RuleResult(ruleId: 'layer_violations', penalty: 10, findings: []),
        RuleResult(ruleId: 'cross_feature_coupling', penalty: 10, findings: []),
      ];
      final agg =
          CategoryAggregation.fromRuleResults(results, ruleIdToCategory);
      expect(agg.totalPenalty, 25.0);
      expect(agg.categoryScores.length, 3);
      expect(agg.categoryScores[0].totalPenalty, 10.0);
      expect(agg.categoryScores[1].totalPenalty, 10.0);
      expect(agg.categoryScores[2].totalPenalty, 5.0);
      expect(agg.categoryScores[0].category, 'Coupling Risk');
      expect(agg.categoryScores[1].category, 'Structural Risk');
      expect(agg.categoryScores[2].category, 'Maintainability Risk');
    });

    test('dominant category tie broken alphabetically', () {
      final results = [
        RuleResult(ruleId: 'layer_violations', penalty: 10, findings: []),
        RuleResult(ruleId: 'cross_feature_coupling', penalty: 10, findings: []),
      ];
      final agg =
          CategoryAggregation.fromRuleResults(results, ruleIdToCategory);
      expect(agg.categoryScores.length, 2);
      expect(agg.dominantCategory, 'Coupling Risk');
    });

    test('most expensive rule is highest penalty, tie broken by ruleId', () {
      final results = [
        RuleResult(ruleId: 'aaa', penalty: 15, findings: []),
        RuleResult(ruleId: 'zzz', penalty: 15, findings: []),
      ];
      final map = {'aaa': 'A', 'zzz': 'B'};
      final agg = CategoryAggregation.fromRuleResults(results, map);
      expect(agg.mostExpensiveRuleId, 'aaa');
      expect(agg.mostExpensivePenalty, 15.0);
    });

    test('unknown ruleId falls back to ruleId as category', () {
      final results = [
        RuleResult(ruleId: 'unknown_rule', penalty: 3, findings: []),
      ];
      final agg =
          CategoryAggregation.fromRuleResults(results, ruleIdToCategory);
      expect(agg.categoryScores.length, 1);
      expect(agg.categoryScores.first.category, 'unknown_rule');
      expect(agg.dominantCategory, 'unknown_rule');
      expect(agg.mostExpensiveRuleId, 'unknown_rule');
      expect(agg.penaltyByCategory['unknown_rule'], 3.0);
      expect(
        agg.penaltyByCategory.values.fold(0.0, (a, b) => a + b),
        agg.totalPenalty,
      );
    });

    test('uniqueFindings dedupes counts by fingerprint', () {
      final dup = Finding(
        severity: FindingSeverity.high,
        ruleId: 'layer_violations',
        file: 'a.dart',
        message: 'm',
      );
      final results = [
        RuleResult(
          ruleId: 'layer_violations',
          penalty: 10,
          findings: [dup, dup],
        ),
      ];
      final uniqueFindings = [dup];
      final agg = CategoryAggregation.fromRuleResults(
        results,
        ruleIdToCategory,
        uniqueFindings: uniqueFindings,
      );
      expect(agg.totalPenalty, 10.0);
      expect(agg.categoryScores.length, 1);
      expect(agg.categoryScores.first.highCount, 1);
      expect(agg.categoryScores.first.mediumCount, 0);
    });
  });
}
