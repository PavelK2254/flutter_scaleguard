import 'dart:io';

import 'config.dart';
import 'index.dart';
import 'rule_metadata.dart';
import '../model/category_aggregation.dart';
import '../model/rule_result.dart';
import '../model/scan_report.dart';
import '../rules/cross_feature_coupling.dart';
import '../rules/god_files.dart';
import '../rules/hardcoded_scale_risks.dart';
import '../rules/layer_violations.dart';
import '../rules/navigation_coupling.dart';
import '../rules/rule.dart';
import '../rules/service_locator_abuse.dart';
import '../rules/shared_boundary_leakage.dart';
import '../scoring/scoring_engine.dart';

final _importRegex = RegExp(r'''import\s+['"]([^'"]+)['"]''');
final _exportRegex = RegExp(r'''export\s+['"]([^'"]+)['"]''');

/// Builds [ProjectIndex] from a project directory.
Future<ProjectIndex> buildIndex(String projectPath, ScannerConfig config, {bool includeLines = true}) async {
  final libDir = Directory('$projectPath/lib');
  if (!await libDir.exists()) {
    return const ProjectIndex(files: []);
  }
  final packageName = await _readPackageName(projectPath);
  final files = <IndexedFile>[];
  final root = projectPath.replaceAll('\\', '/').replaceFirst(RegExp(r'/$'), '');
  await for (final entity in libDir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final path = entity.path.replaceAll('\\', '/');
    if (!path.endsWith('.dart')) continue;
    String relative = path.startsWith(root) ? path.substring(root.length) : path;
    if (relative.startsWith('/')) relative = relative.substring(1);
    if (config.shouldIgnore(relative)) continue;
    final content = await entity.readAsString();
    final lineCount = content.split('\n').length;
    final lines = includeLines ? content.split('\n') : <String>[];
    final imports = _parseImports(content, relative, packageName);
    files.add(IndexedFile(path: relative, lineCount: lineCount, imports: imports, lines: lines));
  }
  return ProjectIndex(files: files, packageName: packageName);
}

Future<String?> _readPackageName(String projectPath) async {
  final pubspec = File('$projectPath/pubspec.yaml');
  if (!await pubspec.exists()) return null;
  final content = await pubspec.readAsString();
  final match = RegExp(r'name:\s*(\S+)').firstMatch(content);
  return match?.group(1);
}

List<String> _parseImports(String content, String fromPath, String? packageName) {
  final result = <String>[];
  for (final line in content.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('/*')) continue;
    for (final re in [_importRegex, _exportRegex]) {
      final m = re.firstMatch(trimmed);
      if (m != null) {
        final target = m.group(1)!;
        final resolved = ProjectIndex.resolveImportPath(fromPath, target, packageName);
        if (resolved != null && resolved.isNotEmpty) result.add(resolved);
        break;
      }
    }
  }
  return result;
}

/// Default rules (all 7) for a full scan.
List<Rule> get defaultRules => [
      CrossFeatureCouplingRule(),
      LayerViolationsRule(),
      GodFilesRule(),
      HardcodedScaleRisksRule(),
      ServiceLocatorAbuseRule(),
      SharedBoundaryLeakageRule(),
      NavigationCouplingRule(),
    ];

/// Runs a full scan: loads config, builds index, runs [rules], computes score, returns report.
Future<ScanReport> runScan(String projectPath, {ScannerConfig? config, List<Rule>? rules}) async {
  final resolvedConfig = config ?? await ScannerConfig.load(projectPath);
  final index = await buildIndex(projectPath, resolvedConfig);
  final ruleList = rules ?? defaultRules;
  final results = <RuleResult>[];
  for (final rule in ruleList) {
    results.add(rule.run(index, resolvedConfig));
  }
  final scoreResult = ScoringEngine.run(results);
  final aggregation =
      CategoryAggregation.fromRuleResults(results, ruleIdToCategory);
  return ScanReport(
    score: scoreResult.score,
    riskLevel: scoreResult.riskLevel,
    ruleResults: results,
    timestamp: DateTime.now().toUtc(),
    projectPath: projectPath,
    aggregation: aggregation,
  );
}
