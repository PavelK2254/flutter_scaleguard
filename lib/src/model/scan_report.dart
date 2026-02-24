import 'category_aggregation.dart';
import 'finding.dart';
import 'risk_level.dart';
import 'rule_result.dart';

class ScanReport {
  const ScanReport({
    required this.score,
    required this.riskLevel,
    required this.ruleResults,
    required this.timestamp,
    this.projectPath,
    this.aggregation,
  });

  final int score;
  final RiskLevel riskLevel;
  final List<RuleResult> ruleResults;
  final DateTime timestamp;
  final String? projectPath;
  final CategoryAggregation? aggregation;

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
