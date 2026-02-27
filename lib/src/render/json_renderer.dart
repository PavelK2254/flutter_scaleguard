import 'dart:convert';

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
    return const JsonEncoder.withIndent('  ').convert(map);
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
