import '../core/config.dart';
import '../core/index.dart';
import '../core/path_utils.dart' as path_utils;
import '../model/finding.dart';
import '../model/rule_result.dart';
import '../model/severity.dart';
import 'rule.dart';

/// Layer classifier for clean architecture.
enum Layer {
  presentation,
  domain,
  data,
  unknown,
}

/// Default path patterns when layer_mappings don't match (segment in path).
/// Order: presentation > domain > data (first match wins).
const Map<Layer, List<String>> _defaultPathPatterns = {
  Layer.presentation: [
    '/presentation/',
    '/ui/',
    '/widgets/',
    '/pages/',
    '/bloc/',
    '/cubit/',
  ],
  Layer.domain: ['/domain/', '/usecases/', '/entities/'],
  Layer.data: [
    '/data/',
    '/datasource/',
    '/datasources/',
    '/remote/',
    '/local/',
    '/repository/',
    '/repositories/',
  ],
};

/// Priority order for layer classification (first match wins).
const _layerPriority = [Layer.presentation, Layer.domain, Layer.data];

/// Classifies [path] to a layer using [config].layerMappings if available, else default path patterns.
/// Enforces priority: presentation > domain > data. When using layerMappings, longest matching segment wins per layer.
Layer classifyPath(String path, ScannerConfig config) {
  final norm = path_utils.normalizePath(path);
  if (config.layerMappings.isNotEmpty) {
    for (final layer in _layerPriority) {
      final layerName = layer.name;
      final segments = config.layerMappings.entries
          .where((e) => e.value == layerName)
          .map((e) => e.key)
          .toList();
      segments.sort((a, b) => b.length.compareTo(a.length));
      for (final segment in segments) {
        if (norm.contains('/$segment/') || norm.endsWith('/$segment')) {
          return layer;
        }
      }
    }
  }
  for (final layer in _layerPriority) {
    for (final pattern in _defaultPathPatterns[layer]!) {
      if (norm.contains(pattern)) return layer;
    }
  }
  return Layer.unknown;
}

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
      final fromLayer = classifyPath(fromPath, config);
      if (fromLayer == Layer.unknown) continue;
      final rawAllowed = config.allowedLayerDependencies[fromLayer.name];
      if (rawAllowed == null) continue;
      Set<String> allowed = rawAllowed;
      if (config.allowDomainToData && fromLayer == Layer.domain) {
        allowed = {...allowed, Layer.data.name};
      }
      for (final importTarget in file.imports) {
        final toPath = ProjectIndex.normalizePath(importTarget);
        final toLayer = classifyPath(toPath, config);
        if (toLayer == Layer.unknown) continue;
        if (fromLayer == toLayer) continue;
        if (!allowed.contains(toLayer.name)) {
          final severity = (fromLayer == Layer.presentation &&
                  toLayer == Layer.data)
              ? FindingSeverity.high
              : FindingSeverity.medium;
          final message =
              'Layer boundary crossed: ${fromLayer.name} imports ${toLayer.name} (may increase coupling and future refactor cost).';
          final evidenceSnippet = "import '$importTarget';";
          findings.add(Finding(
            severity: severity,
            ruleId: id,
            file: file.path,
            message: '$message\n$evidenceSnippet',
            resolvedImportedPath: importTarget,
            fromLayer: fromLayer.name,
            toLayer: toLayer.name,
          ));
        }
      }
    }
    double riskValue = 0;
    for (final f in findings) {
      riskValue += f.severity == FindingSeverity.high ? 2 : 1;
    }
    final penalty = (riskValue * weight).clamp(0.0, cap);
    return RuleResult(
        ruleId: id, penalty: penalty, findings: findings, riskValue: riskValue);
  }
}
