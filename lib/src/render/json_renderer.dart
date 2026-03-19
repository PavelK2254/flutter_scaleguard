import 'dart:convert';

import '../core/hotspot_utils.dart';
import '../core/report_debug.dart';
import '../model/category_aggregation.dart';
import '../model/finding.dart';
import '../model/hotspot_metrics.dart';
import '../model/risk_level.dart';
import '../model/rule_result.dart';
import '../model/scan_meta.dart';
import '../model/scan_report.dart';
import '../model/severity.dart';
import '../version.dart';

class JsonRenderer {
  JsonRenderer._();

  static const String jsonSchemaVersion = '1.0';

  /// Renders [report] to JSON. [version] is the tool version (e.g. from [getPackageVersion]);
  /// if null, uses [fallbackPackageVersion].
  static String render(ScanReport report, {String? version}) {
    final toolVersion = version ?? fallbackPackageVersion;
    final map = <String, Object>{
      'toolVersion': toolVersion,
      'schemaVersion': jsonSchemaVersion,
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
      map['penalties'] = _penaltiesToMap(report.aggregation!);
    }
    final capHitsRaw =
        report.capHits ?? ReportDebug.computeCapHits(report.ruleResults);
    map['capHits'] = List<String>.from(capHitsRaw)..sort();
    map['hotspotMetrics'] = report.hotspotMetrics != null
        ? _hotspotMetricsToJsonMap(report.hotspotMetrics!)
        : _hotspotMetricsToMap(report);
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Penalties as positive magnitudes. byCategory and byRule from aggregation.
  static Map<String, Object> _penaltiesToMap(CategoryAggregation aggregation) {
    if (aggregation.totalPenalty == 0) {
      return <String, Object>{
        'total': 0.0,
        'byCategory': <String, Object>{},
        'byRule': <String, Object>{},
      };
    }
    final categoryEntries = aggregation.penaltyByCategory.entries.toList()
      ..sort((a, b) {
        final byValue = b.value.compareTo(a.value);
        if (byValue != 0) return byValue;
        return a.key.compareTo(b.key);
      });
    final byCategory = <String, Object>{
      for (final e in categoryEntries) e.key: e.value,
    };
    final byRule = <String, Object>{
      for (final e in aggregation.penaltyByRule.entries) e.key: e.value,
    };
    return <String, Object>{
      'total': aggregation.totalPenalty,
      'byCategory': byCategory,
      'byRule': byRule,
    };
  }

  static double _round4(double x) => (x * 10000).round() / 10000;

  static Map<String, dynamic> _hotspotMetricsToJsonMap(HotspotMetrics m) {
    return <String, dynamic>{
      'totalFindings': m.totalFindings,
      'largestHotspot': m.largestHotspot == null
          ? null
          : <String, Object>{
              'path': m.largestHotspot!.path,
              'findings': m.largestHotspot!.findings,
            },
      'concentration': m.concentration,
      'top3Share': m.top3Share,
    };
  }

  static Map<String, dynamic> _hotspotMetricsToMap(ScanReport report) {
    final totalFindings = report.uniqueFindings.length;
    if (totalFindings == 0) {
      return <String, dynamic>{
        'totalFindings': 0,
        'largestHotspot': null,
        'concentration': 0.0,
        'top3Share': 0.0,
      };
    }
    final ordered = HotspotUtils.getOrderedHotspotEntries(report);
    final top3Sum = ordered.take(3).fold<int>(0, (s, e) => s + e.count);
    return <String, dynamic>{
      'totalFindings': totalFindings,
      'largestHotspot': ordered.isEmpty
          ? null
          : <String, Object>{
              'path': ordered.first.path,
              'findings': ordered.first.count,
            },
      'concentration':
          _round4(ordered.isEmpty ? 0.0 : ordered.first.count / totalFindings),
      'top3Share': _round4(top3Sum / totalFindings),
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
