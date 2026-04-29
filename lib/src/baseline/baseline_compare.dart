import '../core/hotspot_utils.dart';
import '../core/rule_metadata.dart';
import '../model/risk_level.dart';
import '../model/scan_report.dart';
import '../model/severity.dart';
import 'baseline_model.dart';

class BaselineComparator {
  const BaselineComparator._();

  static const int _scoreMeaningfulThreshold = 2;
  static const double _categoryMeaningfulThreshold = 2.0;
  static const int _hotspotLimit = 3;
  static const int _topCategoryLimit = 3;

  static BaselineComparison compare({
    required ScaleGuardBaseline baseline,
    required ScanReport currentReport,
    required BaselineConfigSnapshot currentConfigSnapshot,
  }) {
    final currentSummary = _buildCurrentSummary(currentReport);

    final scoreDelta = currentSummary.score - baseline.summary.score;
    final riskDirection =
        _riskDirection(baseline.summary.riskLevel, currentSummary.riskLevel);
    final categoryDeltas =
        _categoryDeltas(baseline.summary.categoryPenalties, currentSummary.categoryPenalties);
    final hotspotDeltas =
        _hotspotDeltas(baseline.summary.topHotspots, currentSummary.topHotspots);
    final findingsDelta = _findingsDelta(baseline.summary, currentSummary);
    final hasConfigMismatch =
        _hasConfigMismatch(baseline.configSnapshot, currentConfigSnapshot);

    final meaningful = scoreDelta.abs() >= _scoreMeaningfulThreshold ||
        riskDirection != BaselineRiskDirection.same ||
        categoryDeltas.any((d) => d.delta.abs() >= _categoryMeaningfulThreshold) ||
        hotspotDeltas.any((d) => d.changeType != HotspotChangeType.unchanged);

    return BaselineComparison(
      scoreDelta: scoreDelta,
      riskDirection: riskDirection,
      meaningful: meaningful,
      categoryDeltas: categoryDeltas,
      hotspotDeltas: hotspotDeltas,
      findingsDelta: findingsDelta,
      hasConfigMismatch: hasConfigMismatch,
    );
  }

  static BaselineRiskDirection _riskDirection(RiskLevel baseline, RiskLevel current) {
    if (baseline == current) return BaselineRiskDirection.same;
    if (current.index > baseline.index) return BaselineRiskDirection.up;
    return BaselineRiskDirection.down;
  }

  static List<CategoryDelta> _categoryDeltas(
      Map<String, double> baseline, Map<String, double> current) {
    final keys = <String>{...baseline.keys, ...current.keys}.toList()..sort();
    final deltas = <CategoryDelta>[];
    for (final key in keys) {
      final delta = (current[key] ?? 0.0) - (baseline[key] ?? 0.0);
      if (delta == 0) continue;
      deltas.add(CategoryDelta(category: key, delta: delta));
    }
    deltas.sort((a, b) {
      final byAbs = b.delta.abs().compareTo(a.delta.abs());
      if (byAbs != 0) return byAbs;
      return a.category.compareTo(b.category);
    });
    return deltas.take(_topCategoryLimit).toList(growable: false);
  }

  static List<HotspotDelta> _hotspotDeltas(
      List<BaselineHotspot> baseline, List<BaselineHotspot> current) {
    final baselineMap = {for (final e in baseline.take(_hotspotLimit)) e.path: e};
    final currentMap = {for (final e in current.take(_hotspotLimit)) e.path: e};
    final paths = <String>{...baselineMap.keys, ...currentMap.keys}.toList()..sort();
    final deltas = <HotspotDelta>[];
    for (final path in paths) {
      final baselineValue = baselineMap[path];
      final currentValue = currentMap[path];
      late final HotspotChangeType type;
      if (baselineValue == null && currentValue != null) {
        type = HotspotChangeType.entered;
      } else if (baselineValue != null && currentValue == null) {
        type = HotspotChangeType.exited;
      } else if (baselineValue != null && currentValue != null) {
        type = baselineValue.risk == currentValue.risk
            ? HotspotChangeType.unchanged
            : HotspotChangeType.changed;
      } else {
        continue;
      }
      deltas.add(HotspotDelta(
        path: path,
        changeType: type,
        currentRisk: currentValue?.risk,
        baselineRisk: baselineValue?.risk,
      ));
    }
    deltas.sort((a, b) => a.path.compareTo(b.path));
    return deltas;
  }

  static FindingsDelta _findingsDelta(BaselineSummary baseline, BaselineSummary current) {
    int getSeverity(BaselineSummary summary, String key) =>
        summary.findingsBySeverity[key] ?? 0;

    return FindingsDelta(
      totalDelta: current.findingsTotal - baseline.findingsTotal,
      highDelta: getSeverity(current, 'high') - getSeverity(baseline, 'high'),
      mediumDelta: getSeverity(current, 'medium') - getSeverity(baseline, 'medium'),
      lowDelta: getSeverity(current, 'low') - getSeverity(baseline, 'low'),
    );
  }

  static bool _hasConfigMismatch(
      BaselineConfigSnapshot? baseline, BaselineConfigSnapshot current) {
    if (baseline == null) return false;
    if (baseline.ignoreCount != current.ignoreCount) return true;
    if (!_sameStringList(baseline.featureRoots, current.featureRoots)) return true;
    if (!_sameStringList(baseline.enabledRuleIds, current.enabledRuleIds)) return true;
    return false;
  }

  static bool _sameStringList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static BaselineSummary _buildCurrentSummary(ScanReport report) {
    final severity = <String, int>{'high': 0, 'medium': 0, 'low': 0};
    for (final finding in report.uniqueFindings) {
      switch (finding.severity) {
        case FindingSeverity.high:
          severity['high'] = (severity['high'] ?? 0) + 1;
          break;
        case FindingSeverity.medium:
          severity['medium'] = (severity['medium'] ?? 0) + 1;
          break;
      }
    }
    final topHotspots = <BaselineHotspot>[];
    final hotspotEntries = <MapEntry<String, int>>[];
    final countByPath = <String, int>{};
    for (final finding in report.uniqueFindings) {
      final hotspotKey = HotspotUtils.getSourceHotspotKey(finding, report);
      countByPath[hotspotKey] = (countByPath[hotspotKey] ?? 0) + 1;
    }
    hotspotEntries.addAll(countByPath.entries);
    hotspotEntries.sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.compareTo(b.key);
    });
    for (final entry in hotspotEntries.take(_hotspotLimit)) {
      topHotspots.add(BaselineHotspot(path: entry.key, risk: entry.value));
    }

    final categoryPenalties = <String, double>{};
    for (final category in allCategories) {
      categoryPenalties[category] = 0;
    }
    final aggPenalties = report.aggregation?.penaltyByCategory;
    if (aggPenalties != null) {
      categoryPenalties.addAll(aggPenalties);
    }

    return BaselineSummary(
      score: report.score,
      riskLevel: report.riskLevel,
      categoryPenalties: categoryPenalties,
      findingsTotal: report.uniqueFindings.length,
      findingsBySeverity: severity,
      topHotspots: topHotspots,
    );
  }
}
