import '../model/rule_result.dart';
import '../model/scan_report.dart';
import '../model/hotspot_metrics.dart';
import 'hotspot_utils.dart';
import 'rule_metadata.dart';

/// Shared helpers for debug-only report data (capHits, hotspotMetrics).
/// Used by scanner to populate report and by JsonRenderer when report has nulls.
class ReportDebug {
  ReportDebug._();

  static const double _capEpsilon = 1e-6;

  /// Rule ids where rawPenalty > cap and final penalty at cap. Sorted ascending.
  static List<String> computeCapHits(List<RuleResult> ruleResults) {
    final hitIds = <String>[];
    for (final r in ruleResults) {
      final weight = ruleIdToWeight[r.ruleId];
      final cap = ruleIdToCap[r.ruleId];
      if (weight == null || cap == null) continue;
      final rawPenalty = (r.riskValue ?? 0) * weight;
      if (rawPenalty > cap && r.penalty >= cap - _capEpsilon)
        hitIds.add(r.ruleId);
    }
    hitIds.sort((a, b) => a.compareTo(b));
    return hitIds;
  }

  static double _round4(double x) => (x * 10000).round() / 10000;

  /// Hotspot concentration metrics from report.
  static HotspotMetrics computeHotspotMetrics(ScanReport report) {
    final totalFindings = report.uniqueFindings.length;
    if (totalFindings == 0) {
      return const HotspotMetrics(
        totalFindings: 0,
        concentration: 0.0,
        top3Share: 0.0,
      );
    }
    final ordered = HotspotUtils.getOrderedHotspotEntries(report);
    final top3Sum = ordered.take(3).fold<int>(0, (s, e) => s + e.count);
    return HotspotMetrics(
      totalFindings: totalFindings,
      concentration:
          _round4(ordered.isEmpty ? 0.0 : ordered.first.count / totalFindings),
      top3Share: _round4(top3Sum / totalFindings),
      largestHotspot: ordered.isEmpty
          ? null
          : LargestHotspot(
              path: ordered.first.path,
              findings: ordered.first.count,
            ),
    );
  }
}
