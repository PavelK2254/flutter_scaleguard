import 'category_aggregation.dart';
import 'finding.dart';
import 'hotspot_metrics.dart';
import 'risk_level.dart';
import 'rule_result.dart';
import 'scan_meta.dart';

class ScanReport {
  const ScanReport({
    required this.score,
    required this.riskLevel,
    required this.ruleResults,
    required this.uniqueFindings,
    required this.timestamp,
    this.projectPath,
    this.aggregation,
    this.meta,
    this.moduleIndex,
    this.capHits,
    this.hotspotMetrics,
  });

  final int score;
  final RiskLevel riskLevel;
  final List<RuleResult> ruleResults;
  /// Deduplicated findings (by fingerprint), deterministically sorted.
  final List<Finding> uniqueFindings;
  final DateTime timestamp;
  final String? projectPath;
  final CategoryAggregation? aggregation;
  final ScanMeta? meta;
  /// Map from normalized file path to module root key (e.g. lib/feature/add_card). Built during scan.
  final Map<String, String>? moduleIndex;
  /// Rule ids that hit their penalty cap. Sorted ascending. Populated during scan for debug output.
  final List<String>? capHits;
  /// Hotspot concentration metrics. Populated during scan for debug output.
  final HotspotMetrics? hotspotMetrics;

  /// Returns a copy of this report with the given fields replaced.
  ScanReport copyWith({
    int? score,
    RiskLevel? riskLevel,
    List<RuleResult>? ruleResults,
    List<Finding>? uniqueFindings,
    DateTime? timestamp,
    String? projectPath,
    CategoryAggregation? aggregation,
    ScanMeta? meta,
    Map<String, String>? moduleIndex,
    List<String>? capHits,
    HotspotMetrics? hotspotMetrics,
  }) {
    return ScanReport(
      score: score ?? this.score,
      riskLevel: riskLevel ?? this.riskLevel,
      ruleResults: ruleResults ?? this.ruleResults,
      uniqueFindings: uniqueFindings ?? this.uniqueFindings,
      timestamp: timestamp ?? this.timestamp,
      projectPath: projectPath ?? this.projectPath,
      aggregation: aggregation ?? this.aggregation,
      meta: meta ?? this.meta,
      moduleIndex: moduleIndex ?? this.moduleIndex,
      capHits: capHits ?? this.capHits,
      hotspotMetrics: hotspotMetrics ?? this.hotspotMetrics,
    );
  }

  List<Finding> get findings {
    final list = <Finding>[];
    for (final r in ruleResults) {
      list.addAll(r.findings);
    }
    list.sort((a, b) {
      final sev = a.severity.index.compareTo(b.severity.index);
      if (sev != 0) return sev;
      final file = a.file.compareTo(b.file);
      if (file != 0) return file;
      final al = a.line ?? 0;
      final bl = b.line ?? 0;
      return al.compareTo(bl);
    });
    return list;
  }
}
