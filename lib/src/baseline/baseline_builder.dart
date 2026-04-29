import '../core/config.dart';
import '../core/hotspot_utils.dart';
import '../core/rule_metadata.dart';
import '../model/scan_report.dart';
import '../model/severity.dart';
import 'baseline_model.dart';

class BaselineBuilder {
  const BaselineBuilder._();

  static const int baselineVersion = 1;
  static const int _topHotspotsLimit = 3;

  static ScaleGuardBaseline fromScan({
    required ScanReport report,
    required ScannerConfig config,
    String? toolVersion,
    String? projectRelativePath,
  }) {
    final categoryPenalties = <String, double>{};
    if (report.aggregation != null) {
      categoryPenalties.addAll(report.aggregation!.penaltyByCategory);
    }

    final severityCounts = <String, int>{'high': 0, 'medium': 0, 'low': 0};
    for (final finding in report.uniqueFindings) {
      switch (finding.severity) {
        case FindingSeverity.high:
          severityCounts['high'] = (severityCounts['high'] ?? 0) + 1;
          break;
        case FindingSeverity.medium:
          severityCounts['medium'] = (severityCounts['medium'] ?? 0) + 1;
          break;
      }
    }

    final hotspotEntries = HotspotUtils.getOrderedHotspotEntries(report);
    final topHotspots = hotspotEntries
        .take(_topHotspotsLimit)
        .map((e) => BaselineHotspot(path: e.path, risk: e.count))
        .toList(growable: false);

    final enabledRuleIds = <String>[];
    for (final ruleId in ruleIdToCategory.keys) {
      if (config.isRuleEnabled(ruleId)) {
        enabledRuleIds.add(ruleId);
      }
    }
    enabledRuleIds.sort();

    final summary = BaselineSummary(
      score: report.score,
      riskLevel: report.riskLevel,
      categoryPenalties: categoryPenalties,
      findingsTotal: report.uniqueFindings.length,
      findingsBySeverity: severityCounts,
      topHotspots: topHotspots,
    );

    final configSnapshot = BaselineConfigSnapshot(
      enabledRuleIds: enabledRuleIds,
      ignoreCount: config.ignoredPatterns.length,
      featureRoots: [...config.featureRoots]..sort(),
    );

    return ScaleGuardBaseline(
      baselineVersion: baselineVersion,
      createdAt: DateTime.now().toUtc(),
      toolVersion: toolVersion,
      projectRelativePath: projectRelativePath,
      configSnapshot: configSnapshot,
      summary: summary,
    );
  }
}
