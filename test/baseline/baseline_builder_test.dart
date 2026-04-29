import 'package:scale_guard/src/baseline/baseline_builder.dart';
import 'package:scale_guard/src/core/config.dart';
import 'package:scale_guard/src/model/category_aggregation.dart';
import 'package:scale_guard/src/model/finding.dart';
import 'package:scale_guard/src/model/risk_level.dart';
import 'package:scale_guard/src/model/rule_result.dart';
import 'package:scale_guard/src/model/scan_report.dart';
import 'package:scale_guard/src/model/severity.dart';
import 'package:test/test.dart';

void main() {
  test('builds compact baseline summary with deterministic config snapshot', () {
    final findings = [
      const Finding(
        severity: FindingSeverity.high,
        ruleId: 'layer_violations',
        file: 'lib/features/a/a.dart',
        message: 'x',
      ),
      const Finding(
        severity: FindingSeverity.medium,
        ruleId: 'cross_feature_coupling',
        file: 'lib/features/b/b.dart',
        message: 'y',
      ),
    ];
    final results = [
      RuleResult(ruleId: 'layer_violations', penalty: 4, findings: [findings[0]]),
      RuleResult(
          ruleId: 'cross_feature_coupling', penalty: 2, findings: [findings[1]]),
    ];
    final aggregation = CategoryAggregation.fromRuleResults(
      results,
      const {
        'layer_violations': 'Structural Risk',
        'cross_feature_coupling': 'Coupling Risk',
      },
      uniqueFindings: findings,
    );
    final report = ScanReport(
      score: 81,
      riskLevel: RiskLevel.medium,
      ruleResults: results,
      uniqueFindings: findings,
      timestamp: DateTime.utc(2026, 1, 1),
      aggregation: aggregation,
    );
    const config = ScannerConfig(
      featureRoots: ['lib/features'],
      ignoredPatterns: ['a', 'b'],
      ruleEnabled: {'cross_feature_coupling': true, 'layer_violations': true},
    );

    final baseline = BaselineBuilder.fromScan(
      report: report,
      config: config,
      toolVersion: '0.7.0',
      projectRelativePath: '.',
    );

    expect(baseline.baselineVersion, 1);
    expect(baseline.summary.score, 81);
    expect(baseline.summary.riskLevel, RiskLevel.medium);
    expect(baseline.summary.findingsTotal, 2);
    expect(baseline.summary.findingsBySeverity['high'], 1);
    expect(baseline.summary.findingsBySeverity['medium'], 1);
    expect(baseline.configSnapshot, isNotNull);
    expect(baseline.configSnapshot!.ignoreCount, 2);
    expect(baseline.configSnapshot!.featureRoots, ['lib/features']);
    expect(baseline.summary.categoryPenalties['Structural Risk'], 4.0);
    expect(baseline.summary.categoryPenalties['Coupling Risk'], 2.0);
  });
}
