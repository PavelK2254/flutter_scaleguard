import 'dart:convert';

import 'package:scale_guard/scale_guard.dart';
import 'package:test/test.dart';

void main() {
  final ruleIdToCategory = {
    'layer_violations': 'Structural Risk',
    'cross_feature_coupling': 'Coupling Risk',
    'god_files': 'Maintainability Risk',
    'hardcoded_scale_risks': 'Configuration / Release Risk',
  };

  group('JsonRenderer penalties', () {
    test('penalties block present with total and byCategory when aggregation has penalty', () {
      final results = [
        RuleResult(ruleId: 'layer_violations', penalty: 10, findings: []),
        RuleResult(ruleId: 'cross_feature_coupling', penalty: 5, findings: []),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        ruleIdToCategory,
      );
      final report = ScanReport(
        score: 85,
        riskLevel: RiskLevel.low,
        ruleResults: results,
        uniqueFindings: [],
        timestamp: DateTime.utc(2025, 1, 1),
        aggregation: aggregation,
      );
      final jsonStr = JsonRenderer.render(report);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(json.containsKey('penalties'), isTrue);
      final penalties = json['penalties'] as Map<String, dynamic>;
      expect(penalties['total'], 15.0);
      final byCategory = penalties['byCategory'] as Map<String, dynamic>;
      expect(byCategory.length, 4);
      expect(byCategory['Structural Risk'], 10.0);
      expect(byCategory['Coupling Risk'], 5.0);
      expect(byCategory['Maintainability Risk'], 0.0);
      expect(byCategory['Configuration / Release Risk'], 0.0);
      final keys = byCategory.keys.toList();
      expect(keys[0], 'Structural Risk');
      expect(keys[1], 'Coupling Risk');
      final byRule = penalties['byRule'] as Map<String, dynamic>;
      expect(byRule.length, 2);
      final ruleKeys = byRule.keys.toList();
      expect(ruleKeys[0], 'layer_violations');
      expect(ruleKeys[1], 'cross_feature_coupling');
      expect(byRule['layer_violations'], 10.0);
      expect(byRule['cross_feature_coupling'], 5.0);
    });

    test('penalties block when totalPenalty == 0 has total 0, empty byCategory and byRule', () {
      final results = [
        RuleResult(ruleId: 'layer_violations', penalty: 0, findings: []),
        RuleResult(ruleId: 'cross_feature_coupling', penalty: 0, findings: []),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        ruleIdToCategory,
      );
      final report = ScanReport(
        score: 100,
        riskLevel: RiskLevel.low,
        ruleResults: results,
        uniqueFindings: [],
        timestamp: DateTime.utc(2025, 1, 1),
        aggregation: aggregation,
      );
      final jsonStr = JsonRenderer.render(report);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(json.containsKey('penalties'), isTrue);
      final penalties = json['penalties'] as Map<String, dynamic>;
      expect(penalties['total'], 0.0);
      final byCategory = penalties['byCategory'] as Map<String, dynamic>;
      expect(byCategory, isEmpty);
      final byRule = penalties['byRule'] as Map<String, dynamic>;
      expect(byRule, isEmpty);
    });
  });
}
