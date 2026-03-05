import '../core/config.dart';
import '../core/index.dart';
import '../core/path_utils.dart' as path_utils;
import '../model/finding.dart';
import '../model/rule_result.dart';
import '../model/severity.dart';
import 'rule.dart';

/// Detects service locator / global state in presentation/domain.
/// Skips lib/di/ and lib/core/di/ (composition roots). Requires usage (e.g. '(' on line) to avoid import-only false positives.
class ServiceLocatorAbuseRule implements Rule {
  @override
  String get id => 'service_locator_abuse';

  @override
  double get weight => 0.18;

  @override
  double get cap => 14;

  static bool _isDiPath(String normalizedPath) {
    return normalizedPath.startsWith('lib/di/') ||
        normalizedPath.startsWith('lib/core/di/');
  }

  @override
  RuleResult run(ProjectIndex index, ScannerConfig config) {
    final findings = <Finding>[];
    final pathToLayer = <String, String?>{};
    for (final f in index.files) {
      pathToLayer[f.path] =
          _layerFromPath(ProjectIndex.normalizePath(f.path), config);
    }
    final patternRegexes = _buildPatternRegexes(config.serviceLocatorPatterns);
    for (final file in index.files) {
      final normPath = path_utils.normalizePath(file.path);
      if (_isDiPath(normPath)) continue;
      final layer = pathToLayer[file.path];
      if (layer == null || layer == 'data') continue;
      if (file.lines.isEmpty) continue;
      for (var i = 0; i < file.lines.length; i++) {
        final line = file.lines[i];
        final trimmed = line.trim();
        if (trimmed.startsWith('//') || trimmed.startsWith('/*')) continue;
        if (trimmed.startsWith('import ') || trimmed.startsWith('export ')) {
          continue;
        }
        if (!line.contains('(')) continue;
        for (var p = 0; p < config.serviceLocatorPatterns.length; p++) {
          final pattern = config.serviceLocatorPatterns[p];
          final re = patternRegexes[p];
          final matches = re != null ? re.hasMatch(line) : line.contains(pattern);
          if (matches) {
            findings.add(Finding(
              severity: FindingSeverity.medium,
              ruleId: id,
              file: file.path,
              line: i + 1,
              message: 'Service locator / global access in $layer: "$pattern"',
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

  /// Build word-boundary regex per pattern when pattern starts/ends with word chars; null means use substring fallback.
  static List<RegExp?> _buildPatternRegexes(List<String> patterns) {
    return patterns.map((pattern) {
      try {
        final escaped = RegExp.escape(pattern);
        final startBoundary = pattern.isNotEmpty && RegExp(r'\w').hasMatch(pattern[0]);
        final endBoundary = pattern.isNotEmpty && RegExp(r'\w').hasMatch(pattern[pattern.length - 1]);
        final regex = '${startBoundary ? r'\b' : ''}$escaped${endBoundary ? r'\b' : ''}';
        return RegExp(regex);
      } catch (_) {
        return null;
      }
    }).toList();
  }

  static String? _layerFromPath(String path, ScannerConfig config) {
    final norm = path_utils.normalizePath(path);
    for (final entry in config.layerMappings.entries) {
      final segment = entry.key;
      if (norm.contains('/$segment/') || norm.endsWith('/$segment')) {
        return entry.value;
      }
    }
    return null;
  }
}
