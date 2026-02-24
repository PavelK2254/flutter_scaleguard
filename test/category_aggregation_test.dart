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
    });
  });
}
