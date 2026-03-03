import 'category_aggregation.dart';
import 'finding.dart';
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
