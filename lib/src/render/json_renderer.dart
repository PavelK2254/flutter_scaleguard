import 'dart:convert';

import '../model/category_aggregation.dart';
import '../model/finding.dart';
import '../model/risk_level.dart';
import '../model/rule_result.dart';
import '../model/scan_meta.dart';
import '../model/scan_report.dart';
import '../model/severity.dart';

class JsonRenderer {
  JsonRenderer._();

  static String render(ScanReport report) {
    final map = <String, Object>{
      'score': report.score,
      'riskLevel': _riskLevelString(report.riskLevel),
      'timestamp': report.timestamp.toIso8601String(),
      'findings': report.findings.map(_findingToMap).toList(),
      'ruleResults': report.ruleResults.map(_ruleResultToMap).toList(),
    };
    if (report.meta != null) {
      map['meta'] = _metaToMap(report.meta!);
    }
    if (report.projectPath != null) {
      map['projectPath'] = report.projectPath!;
    }
    if (report.aggregation != null) {
      map['penalties'] =
          _penaltiesToMap(report.aggregation!, report.ruleResults);
    }
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Penalties as positive magnitudes. byCategory keys in order: penalty desc, then name asc.
  /// byRule: rules with penalty > 0, sorted penalty desc then ruleId asc; values rounded to 2 decimals.
  static Map<String, Object> _penaltiesToMap(
    CategoryAggregation aggregation,
    List<RuleResult> ruleResults,
  ) {
    if (aggregation.totalPenalty == 0) {
      return <String, Object>{
        'total': 0.0,
        'byCategory': <String, Object>{},
        'byRule': <String, Object>{},
      };
    }
    final byCategory = <String, Object>{};
    for (final e in aggregation.penaltyByCategory.entries) {
      byCategory[e.key] = e.value;
    }
    final withPenalty =
        ruleResults.where((r) => r.penalty > 0).toList()
          ..sort((a, b) {
            final byPenalty = b.penalty.compareTo(a.penalty);
            if (byPenalty != 0) return byPenalty;
            return a.ruleId.compareTo(b.ruleId);
          });
    final byRule = <String, Object>{};
    for (final r in withPenalty) {
      byRule[r.ruleId] = (r.penalty * 100).round() / 100;
    }
    return <String, Object>{
      'total': aggregation.totalPenalty,
      'byCategory': byCategory,
      'byRule': byRule,
    };
  }

  static Map<String, Object> _metaToMap(ScanMeta meta) {
    return <String, Object>{
      'schemaVersion': meta.schemaVersion,
      'scannedFiles': meta.scannedFiles,
      'ignoredFiles': meta.ignoredFiles,
      'imports': <String, Object>{
        'total': meta.importsTotal,
        'resolvedToProject': meta.importsResolvedToProject,
        'externalPackage': meta.importsExternalPackage,
        'unresolved': meta.importsUnresolved,
      },
    };
  }

  static String _riskLevelString(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return 'Low';
      case RiskLevel.medium:
        return 'Medium';
      case RiskLevel.high:
        return 'High';
    }
  }

  static Map<String, Object> _findingToMap(Finding f) {
    final map = <String, Object>{
      'severity': f.severity == FindingSeverity.high ? 'high' : 'medium',
      'ruleId': f.ruleId,
      'file': f.file,
      'message': f.message,
    };
    if (f.line != null) map['line'] = f.line!;
    return map;
  }

  static Map<String, Object> _ruleResultToMap(RuleResult r) {
    final map = <String, Object>{
      'ruleId': r.ruleId,
      'penalty': r.penalty,
      'findings': r.findings.map(_findingToMap).toList(),
    };
    if (r.riskValue != null) map['riskValue'] = r.riskValue!;
    return map;
  }
}
