import '../core/config.dart';
import '../core/index.dart';
import '../model/finding.dart';
import '../model/rule_result.dart';
import '../model/severity.dart';
import 'rule.dart';

/// Detects hardcoded URLs, endpoints in presentation/domain layers.
class HardcodedScaleRisksRule implements Rule {
  @override
  String get id => 'hardcoded_scale_risks';

  @override
  double get weight => 0.1;

  @override
  double get cap => 10;

  @override
  RuleResult run(ProjectIndex index, ScannerConfig config) {
    final findings = <Finding>[];
    final pathToLayer = <String, String?>{};
    for (final f in index.files) {
      pathToLayer[f.path] =
          _layerFromPath(ProjectIndex.normalizePath(f.path), config);
    }
    for (final file in index.files) {
      final layer = pathToLayer[file.path];
      if (layer == null || layer == 'data') continue;
      if (file.lines.isEmpty) continue;
      for (var i = 0; i < file.lines.length; i++) {
        final line = file.lines[i];
        if (line.trim().startsWith('//')) continue;
        for (final pattern in config.hardcodedUrlPatterns) {
          if (line.contains(pattern)) {
            findings.add(Finding(
              severity: FindingSeverity.medium,
              ruleId: id,
              file: file.path,
              line: i + 1,
              message: 'Hardcoded URL/endpoint pattern in $layer: "$pattern"',
            ));
            break;
          }
        }
      }
    }
    final riskValue = findings.length.toDouble();
    final penalty = (riskValue * weight).clamp(0.0, cap);
    return RuleResult(
        ruleId: id, penalty: penalty, findings: findings, riskValue: riskValue);
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
