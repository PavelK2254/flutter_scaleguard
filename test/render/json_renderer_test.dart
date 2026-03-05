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

    test('capHits and hotspotMetrics present when aggregation is set', () {
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
      expect(json.containsKey('capHits'), isTrue);
      expect(json['capHits'], isA<List>());
      expect(json.containsKey('hotspotMetrics'), isTrue);
      final hm = json['hotspotMetrics'] as Map<String, dynamic>;
      expect(hm['totalFindings'], 0);
      expect(hm['largestHotspot'], isNull);
      expect(hm['concentration'], 0.0);
      expect(hm['top3Share'], 0.0);
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

  group('JsonRenderer hotspotMetrics', () {
    test('three hotspots: totalFindings, largestHotspot, concentration, top3Share rounded to 4 decimals', () {
      const pathA = 'lib/features/habit_details/f.dart';
      const pathB = 'lib/features/b/f.dart';
      const pathC = 'lib/features/c/f.dart';
      final findings = <Finding>[
        for (var i = 0; i < 61; i++)
          Finding(
            severity: FindingSeverity.medium,
            ruleId: 'layer_violations',
            file: pathA,
            message: 'msg',
            line: i + 1,
          ),
        for (var i = 0; i < 50; i++)
          Finding(
            severity: FindingSeverity.medium,
            ruleId: 'layer_violations',
            file: pathB,
            message: 'msg',
            line: i + 1,
          ),
        for (var i = 0; i < 47; i++)
          Finding(
            severity: FindingSeverity.medium,
            ruleId: 'layer_violations',
            file: pathC,
            message: 'msg',
            line: i + 1,
          ),
      ];
      const totalFindings = 61 + 50 + 47; // 158
      final moduleIndex = {
        pathA: 'lib/features/habit_details',
        pathB: 'lib/features/b',
        pathC: 'lib/features/c',
      };
      final report = ScanReport(
        score: 70,
        riskLevel: RiskLevel.medium,
        ruleResults: [
          RuleResult(ruleId: 'layer_violations', penalty: 10, findings: findings),
        ],
        uniqueFindings: findings,
        timestamp: DateTime.utc(2025, 1, 1),
        aggregation: CategoryAggregation.fromRuleResults(
          [RuleResult(ruleId: 'layer_violations', penalty: 10, findings: findings)],
          {'layer_violations': 'Structural Risk'},
        ),
        moduleIndex: moduleIndex,
      );
      final jsonStr = JsonRenderer.render(report);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final hm = json['hotspotMetrics'] as Map<String, dynamic>;
      expect(hm['totalFindings'], totalFindings);
      final largest = hm['largestHotspot'] as Map<String, dynamic>?;
      expect(largest, isNotNull);
      expect(largest!['path'], 'lib/features/habit_details');
      expect(largest['findings'], 61);
      expect(hm['concentration'], 0.3861); // 61/158 rounded to 4 decimals
      expect(hm['top3Share'], 1.0); // (61+50+47)/158 = 1.0
    });

    test('no findings: largestHotspot null, concentration and top3Share 0', () {
      final report = ScanReport(
        score: 100,
        riskLevel: RiskLevel.low,
        ruleResults: [],
        uniqueFindings: [],
        timestamp: DateTime.utc(2025, 1, 1),
        aggregation: CategoryAggregation.fromRuleResults(
          [],
          {},
        ),
      );
      final jsonStr = JsonRenderer.render(report);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final hm = json['hotspotMetrics'] as Map<String, dynamic>;
      expect(hm['totalFindings'], 0);
      expect(hm['largestHotspot'], isNull);
      expect(hm['concentration'], 0.0);
      expect(hm['top3Share'], 0.0);
    });
  });

  group('JsonRenderer capHits', () {
    test('no cap hit when penalty below cap', () {
      final results = [
        RuleResult(
          ruleId: 'layer_violations',
          penalty: 10,
          riskValue: 40,
          findings: [],
        ),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        {'layer_violations': 'Structural Risk'},
      );
      final report = ScanReport(
        score: 90,
        riskLevel: RiskLevel.low,
        ruleResults: results,
        uniqueFindings: [],
        timestamp: DateTime.utc(2025, 1, 1),
        aggregation: aggregation,
      );
      final jsonStr = JsonRenderer.render(report);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final capHits = json['capHits'] as List<dynamic>;
      expect(capHits, isEmpty);
    });

    test('cap hit when rawPenalty exceeds cap', () {
      // layer_violations: weight 0.25, cap 20. riskValue 100 => raw 25, final penalty 20 => hit
      final results = [
        RuleResult(
          ruleId: 'layer_violations',
          penalty: 20,
          riskValue: 100,
          findings: [],
        ),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        {'layer_violations': 'Structural Risk'},
      );
      final report = ScanReport(
        score: 80,
        riskLevel: RiskLevel.medium,
        ruleResults: results,
        uniqueFindings: [],
        timestamp: DateTime.utc(2025, 1, 1),
        aggregation: aggregation,
      );
      final jsonStr = JsonRenderer.render(report);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final capHits = json['capHits'] as List<dynamic>;
      expect(capHits, contains('layer_violations'));
      expect(capHits.length, 1);
    });

    test('capHits sorted ascending by rule id', () {
      // Two rules that hit cap: cross_feature_coupling (cap 15), layer_violations (cap 20)
      final results = [
        RuleResult(ruleId: 'layer_violations', penalty: 20, riskValue: 100, findings: []),
        RuleResult(ruleId: 'cross_feature_coupling', penalty: 15, riskValue: 100, findings: []),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        {
          'layer_violations': 'Structural Risk',
          'cross_feature_coupling': 'Coupling Risk',
        },
      );
      final report = ScanReport(
        score: 65,
        riskLevel: RiskLevel.medium,
        ruleResults: results,
        uniqueFindings: [],
        timestamp: DateTime.utc(2025, 1, 1),
        aggregation: aggregation,
      );
      final jsonStr = JsonRenderer.render(report);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final capHits = json['capHits'] as List<dynamic>;
      expect(capHits.length, 2);
      expect(capHits[0], 'cross_feature_coupling');
      expect(capHits[1], 'layer_violations');
    });
  });
}
