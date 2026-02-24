import '../core/config.dart';
import '../core/index.dart';
import '../model/finding.dart';
import '../model/rule_result.dart';
import '../model/severity.dart';
import 'rule.dart';

/// Detects invalid imports between presentation, domain, data.
class LayerViolationsRule implements Rule {
  @override
  String get id => 'layer_violations';

  @override
  double get weight => 0.25;

  @override
  double get cap => 20;

  @override
  RuleResult run(ProjectIndex index, ScannerConfig config) {
    final findings = <Finding>[];
    for (final file in index.files) {
      final fromPath = ProjectIndex.normalizePath(file.path);
      final fromLayer = _layerFromPath(fromPath, config);
      if (fromLayer == null) continue;
      final allowed = config.allowedLayerDependencies[fromLayer];
      if (allowed == null) continue;
      for (final importTarget in file.imports) {
        final toPath = ProjectIndex.normalizePath(importTarget);
        final toLayer = _layerFromPath(toPath, config);
        if (toLayer == null) continue;
        if (!allowed.contains(toLayer)) {
          final severity = (fromLayer == 'presentation' && toLayer == 'data')
              ? FindingSeverity.high
              : FindingSeverity.medium;
          findings.add(Finding(
            severity: severity,
            ruleId: id,
            file: file.path,
            message: 'Layer violation: $fromLayer must not import $toLayer ($importTarget)',
          ));
        }
      }
    }
    double riskValue = 0;
    for (final f in findings) {
      riskValue += f.severity == FindingSeverity.high ? 2 : 1;
    }
    final penalty = (riskValue * weight).clamp(0.0, cap);
    return RuleResult(ruleId: id, penalty: penalty, findings: findings, riskValue: riskValue);
  }

  static String? _layerFromPath(String path, ScannerConfig config) {
    final norm = path.replaceAll('\\', '/');
    for (final entry in config.layerMappings.entries) {
      final segment = entry.key;
      if (norm.contains('/$segment/') || norm.endsWith('/$segment')) {
        return entry.value;
      }
    }
    return null;
  }
}
