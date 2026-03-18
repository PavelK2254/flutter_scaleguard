import '../core/config.dart';
import '../core/index.dart';
import '../core/path_utils.dart' as path_utils;
import '../core/rule_metadata.dart';
import '../model/finding.dart';
import '../model/rule_result.dart';
import '../model/severity.dart';
import 'rule.dart';

/// Detects shared/common modules importing feature modules.
class SharedBoundaryLeakageRule implements Rule {
  @override
  String get id => 'shared_boundary_leakage';

  @override
  double get weight => ruleIdToWeight[id]!;

  @override
  double get cap => ruleIdToCap[id]!;

  @override
  String get description => ruleIdToDescription[id] ?? '';

  @override
  String get suggestion => ruleIdToSuggestion[id] ?? '';

  @override
  RuleResult run(ProjectIndex index, ScannerConfig config) {
    final findings = <Finding>[];
    final featureRoots = config.featureRoots.map((r) => path_utils.normalizePath(r)).toList();
    for (final file in index.files) {
      final path = ProjectIndex.normalizePath(file.path);
      final inShared = config.sharedPathSegments.any((s) {
        return path.contains('/$s/') || path.startsWith('$s/');
      });
      if (!inShared) continue;
      for (final importTarget in file.imports) {
        final targetNorm = ProjectIndex.normalizePath(importTarget);
        final inFeature = featureRoots.any((root) {
          final r = root.endsWith('/') ? root : '$root/';
          return targetNorm.startsWith(r);
        });
        if (inFeature) {
          findings.add(Finding(
            severity: FindingSeverity.high,
            ruleId: id,
            file: file.path,
            message:
                'Shared boundary leakage: $path imports feature $importTarget',
          ));
        }
      }
    }
    final riskValue = findings.length.toDouble();
    final penalty = (riskValue * weight).clamp(0.0, cap);
    return RuleResult(
        ruleId: id, penalty: penalty, findings: findings, riskValue: riskValue);
  }
}
