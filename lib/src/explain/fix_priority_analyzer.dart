import '../core/hotspot_utils.dart';
import '../core/rule_metadata.dart';
import '../model/scan_report.dart';
import 'fix_priority.dart';

/// Rules with penalty > 0, ranked by penalty, finding count, rule id.
List<FixPriority> analyzeFixPriorities(ScanReport report, {int limit = 3}) {
  final agg = report.aggregation;
  if (agg == null || agg.totalPenalty <= 0 || report.uniqueFindings.isEmpty) {
    return const [];
  }

  final capHits = report.capHits ?? const [];
  final totalPenalty = agg.totalPenalty;
  final findingsByRule = <String, int>{};
  final distinctHotspotsByRule = <String, Set<String>>{};

  for (final f in report.uniqueFindings) {
    findingsByRule[f.ruleId] = (findingsByRule[f.ruleId] ?? 0) + 1;
    distinctHotspotsByRule
        .putIfAbsent(f.ruleId, () => {})
        .add(HotspotUtils.getSourceHotspotKey(f, report));
  }

  final candidates = report.ruleResults.where((r) => r.penalty > 0).toList()
    ..sort((a, b) {
      final byPenalty = b.penalty.compareTo(a.penalty);
      if (byPenalty != 0) return byPenalty;
      final countA = findingsByRule[a.ruleId] ?? 0;
      final countB = findingsByRule[b.ruleId] ?? 0;
      final byCount = countB.compareTo(countA);
      if (byCount != 0) return byCount;
      return a.ruleId.compareTo(b.ruleId);
    });

  final priorities = <FixPriority>[];
  for (final rule in candidates) {
    final findingCount = findingsByRule[rule.ruleId] ?? 0;
    if (findingCount == 0) continue;
    final hotspotCount =
        distinctHotspotsByRule[rule.ruleId]?.length ?? findingCount;
    priorities.add(FixPriority(
      actionTitle: ruleIdToFixActionTitle[rule.ruleId] ??
          ruleIdToDisplayLabel[rule.ruleId] ??
          rule.ruleId,
      ruleId: rule.ruleId,
      area: ruleIdToCategory[rule.ruleId] ?? rule.ruleId,
      impact: _impactLabel(rule.penalty, totalPenalty),
      estimatedScoreGain: rule.penalty.round(),
      why: _buildWhy(rule.ruleId, findingCount, hotspotCount),
      isCapped: capHits.contains(rule.ruleId),
    ));
    if (priorities.length >= limit) break;
  }
  return priorities;
}

String _impactLabel(double penalty, double totalPenalty) {
  if (penalty >= 10 || (totalPenalty > 0 && penalty / totalPenalty >= 0.35)) {
    return 'High';
  }
  if (penalty >= 4 || (totalPenalty > 0 && penalty / totalPenalty >= 0.15)) {
    return 'Medium';
  }
  return 'Low';
}

String _buildWhy(String ruleId, int findingCount, int hotspotCount) {
  switch (ruleId) {
    case 'cross_feature_coupling':
      return '$findingCount findings relate to feature-to-feature imports.';
    case 'god_files':
      return '$findingCount files exceed god-file thresholds.';
    case 'service_locator_abuse':
      if (hotspotCount > 1) {
        return 'Service locator usage appears across $hotspotCount module paths.';
      }
      return '$findingCount findings relate to global dependency access.';
    case 'layer_violations':
      return '$findingCount findings cross layer boundaries.';
    default:
      final description = ruleIdToDescription[ruleId] ?? '';
      final short = _firstSentence(description);
      if (short.isEmpty) {
        return '$findingCount findings detected for this rule.';
      }
      final topic =
          short.endsWith('.') ? short.substring(0, short.length - 1) : short;
      return '$findingCount findings relate to ${topic.toLowerCase()}.';
  }
}

String _firstSentence(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '';
  final dot = trimmed.indexOf('.');
  if (dot >= 0) return trimmed.substring(0, dot + 1);
  return trimmed;
}
