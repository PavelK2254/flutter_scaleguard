import 'package:scale_guard/src/baseline/baseline_compare.dart';
import 'package:scale_guard/src/baseline/baseline_model.dart';
import 'package:scale_guard/src/model/category_aggregation.dart';
import 'package:scale_guard/src/model/finding.dart';
import 'package:scale_guard/src/model/risk_level.dart';
import 'package:scale_guard/src/model/rule_result.dart';
import 'package:scale_guard/src/model/scan_report.dart';
import 'package:scale_guard/src/model/severity.dart';
import 'package:test/test.dart';

void main() {
  test('compare computes score/risk/category/hotspot deltas', () {
    final baseline = ScaleGuardBaseline(
      baselineVersion: 1,
      createdAt: DateTime.utc(2026, 1, 1),
      summary: const BaselineSummary(
        score: 70,
        riskLevel: RiskLevel.high,
        categoryPenalties: {'Structural Risk': 10, 'Coupling Risk': 5},
        findingsTotal: 5,
        findingsBySeverity: {'high': 2, 'medium': 3, 'low': 0},
        topHotspots: [BaselineHotspot(path: 'lib/a', risk: 4)],
      ),
      configSnapshot: BaselineConfigSnapshot(
        enabledRuleIds: ['cross_feature_coupling', 'layer_violations'],
        ignoreCount: 2,
        featureRoots: ['lib/features'],
      ),
    );

    final findings = [
      const Finding(
        severity: FindingSeverity.medium,
        ruleId: 'layer_violations',
        file: 'lib/a',
        message: 'x',
      ),
      const Finding(
        severity: FindingSeverity.medium,
        ruleId: 'cross_feature_coupling',
        file: 'lib/b',
        message: 'y',
      ),
    ];
    final results = [
      RuleResult(ruleId: 'layer_violations', penalty: 8, findings: [findings[0]]),
      RuleResult(
          ruleId: 'cross_feature_coupling', penalty: 2, findings: [findings[1]]),
    ];
    final report = ScanReport(
      score: 75,
      riskLevel: RiskLevel.medium,
      ruleResults: results,
      uniqueFindings: findings,
      timestamp: DateTime.utc(2026, 1, 1),
      aggregation: CategoryAggregation.fromRuleResults(
        results,
        const {
          'layer_violations': 'Structural Risk',
          'cross_feature_coupling': 'Coupling Risk',
        },
        uniqueFindings: findings,
      ),
    );

    const currentConfig = BaselineConfigSnapshot(
      enabledRuleIds: ['cross_feature_coupling', 'layer_violations'],
      ignoreCount: 3,
      featureRoots: ['lib/features'],
    );

    final comparison = BaselineComparator.compare(
      baseline: baseline,
      currentReport: report,
      currentConfigSnapshot: currentConfig,
    );

    expect(comparison.scoreDelta, 5);
    expect(comparison.riskDirection, BaselineRiskDirection.down);
    expect(comparison.meaningful, isTrue);
    expect(comparison.categoryDeltas, isNotEmpty);
    expect(comparison.hotspotDeltas, isNotEmpty);
    expect(comparison.findingsDelta.totalDelta, -3);
    expect(comparison.hasConfigMismatch, isTrue);
  });
}
