import '../core/config.dart';
import '../core/index.dart';
import '../core/path_utils.dart' as path_utils;
import '../core/rule_metadata.dart';
import '../model/finding.dart';
import '../model/rule_result.dart';
import '../model/severity.dart';
import 'rule.dart';

/// Detects feature folders importing other feature folders directly.
class CrossFeatureCouplingRule implements Rule {
  @override
  String get id => 'cross_feature_coupling';

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
    final featureRoots =
        config.featureRoots.map((r) => path_utils.normalizePath(r)).toList();
    final pathToFeature = <String, String>{};
    for (final f in index.files) {
      final path = ProjectIndex.normalizePath(f.path);
      final feature = _featureFromPath(path, featureRoots);
      if (feature != null) pathToFeature[path] = feature;
    }
    for (final file in index.files) {
      final path = ProjectIndex.normalizePath(file.path);
      final fromFeature = _featureFromPath(path, featureRoots);
      if (fromFeature == null) continue;
      for (final importTarget in file.imports) {
        final targetNorm = ProjectIndex.normalizePath(importTarget);
        final toFeature = _featureFromPath(targetNorm, featureRoots);
        if (toFeature != null && toFeature != fromFeature) {
          final first = path_utils.normalizePath(featureRoots.first);
          final base = first.endsWith('/') ? first : '$first/';
          findings.add(Finding(
            severity: FindingSeverity.high,
            ruleId: id,
            file: file.path,
            message:
                'Cross-feature import: $path imports $importTarget (feature $toFeature)',
            resolvedImportedPath: importTarget,
            fromFeature: fromFeature,
            toFeature: toFeature,
            sourceFeaturePath: '$base$fromFeature',
            targetFeaturePath: '$base$toFeature',
          ));
        }
      }
    }
    final riskValue = findings.length.toDouble();
    final penalty = (riskValue * weight).clamp(0.0, cap);
    return RuleResult(
        ruleId: id, penalty: penalty, findings: findings, riskValue: riskValue);
  }

  static String? _featureFromPath(String path, List<String> featureRoots) {
    final norm = path_utils.normalizePath(path);
    for (final root in featureRoots) {
      final r = root.endsWith('/') ? root : '$root/';
      if (norm.startsWith(r)) {
        final after = norm.substring(r.length);
        final segment = after.contains('/')
            ? after.substring(0, after.indexOf('/'))
            : after;
        return segment.isNotEmpty ? segment : null;
      }
    }
    return null;
  }
}
