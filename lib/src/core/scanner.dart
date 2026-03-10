import 'dart:io';

import 'config.dart';
import 'index.dart';
import 'module_root.dart';
import 'path_utils.dart' as path_utils;
import 'report_debug.dart';
import 'rule_metadata.dart';
import '../model/category_aggregation.dart';
import '../model/finding.dart';
import '../model/rule_result.dart';
import '../model/scan_meta.dart';
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

/// Builds [ProjectIndex] and [ScanMeta] from a project directory.
final _importCache = <String, String?>{};

/// Builds index and scan meta. For index-only use, call [buildIndex] instead.
Future<({ProjectIndex index, ScanMeta meta, Map<String, String> moduleIndex})> buildIndexWithMeta(
    String projectPath, ScannerConfig config,
    {bool includeLines = true}) async {
  final libDir = Directory('$projectPath/lib');
  if (!await libDir.exists()) {
    return (
      index: const ProjectIndex(files: []),
      meta: const ScanMeta(
        schemaVersion: ScanMeta.defaultSchemaVersion,
        scannedFiles: 0,
        ignoredFiles: 0,
        importsTotal: 0,
        importsResolvedToProject: 0,
        importsExternalPackage: 0,
        importsUnresolved: 0,
      ),
      moduleIndex: <String, String>{},
    );
  }
  _importCache.clear();
  final packageName = await _readPackageName(projectPath);
  final files = <IndexedFile>[];
  var scannedFiles = 0;
  var ignoredFiles = 0;
  var totalImports = 0;
  var resolvedToProject = 0;
  var externalPackage = 0;
  var unresolved = 0;
  final rootNorm = path_utils.normalizePath(projectPath);
  final root = rootNorm.endsWith('/')
      ? rootNorm.substring(0, rootNorm.length - 1)
      : rootNorm;
  await for (final entity in libDir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final path = path_utils.normalizePath(entity.path);
    if (!path.endsWith('.dart')) continue;
    String relative =
        path.startsWith(root) ? path.substring(root.length) : path;
    if (relative.startsWith('/')) relative = relative.substring(1);
    if (config.shouldIgnore(relative)) {
      ignoredFiles++;
      continue;
    }
    final content = await entity.readAsString();
    final lineCount = content.split('\n').length;
    final lines = includeLines ? content.split('\n') : <String>[];
    final (imports, counts) =
        _parseImports(content, relative, packageName, _importCache);
    scannedFiles++;
    totalImports += counts.total;
    resolvedToProject += counts.resolvedToProject;
    externalPackage += counts.externalPackage;
    unresolved += counts.unresolved;
    files.add(IndexedFile(
        path: relative, lineCount: lineCount, imports: imports, lines: lines));
  }
  final meta = ScanMeta(
    schemaVersion: ScanMeta.defaultSchemaVersion,
    scannedFiles: scannedFiles,
    ignoredFiles: ignoredFiles,
    importsTotal: totalImports,
    importsResolvedToProject: resolvedToProject,
    importsExternalPackage: externalPackage,
    importsUnresolved: unresolved,
  );
  final moduleIndex = <String, String>{
    for (final f in files)
      path_utils.normalizePath(f.path): moduleRootKey(path_utils.normalizePath(f.path)),
  };
  return (
    index: ProjectIndex(files: files, packageName: packageName),
    meta: meta,
    moduleIndex: moduleIndex,
  );
}

/// Builds [ProjectIndex] from a project directory. For index and [ScanMeta], use [buildIndexWithMeta].
Future<ProjectIndex> buildIndex(
    String projectPath, ScannerConfig config,
    {bool includeLines = true}) async {
  final result = await buildIndexWithMeta(projectPath, config, includeLines: includeLines);
  return result.index;
}

class _ImportCounts {
  _ImportCounts(this.total, this.resolvedToProject, this.externalPackage,
      this.unresolved);
  final int total;
  final int resolvedToProject;
  final int externalPackage;
  final int unresolved;
}

/// Returns category for counting: resolvedToProject, externalPackage, or unresolved.
String _classifyImport(String target, String? resolved, String? packageName) {
  if (resolved != null && resolved.isNotEmpty) return 'resolvedToProject';
  if (target.startsWith('dart:') || target.startsWith('flutter:')) {
    return 'externalPackage';
  }
  if (target.startsWith('package:')) {
    if (packageName == null) return 'externalPackage';
    final rest = target.substring(8).trim();
    final slash = rest.indexOf('/');
    final pkg = slash < 0 ? rest : rest.substring(0, slash);
    if (pkg != packageName) return 'externalPackage';
  }
  return 'unresolved';
}

(List<String>, _ImportCounts) _parseImports(
    String content, String fromPath, String? packageName,
    Map<String, String?> cache) {
  final result = <String>[];
  var total = 0;
  var resolvedToProject = 0;
  var externalPackage = 0;
  var unresolved = 0;
  final sourceDir = fromPath.contains('/')
      ? fromPath.substring(0, fromPath.lastIndexOf('/') + 1)
      : '';
  for (final line in content.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('/*')) continue;
    for (final re in [_importRegex, _exportRegex]) {
      final m = re.firstMatch(trimmed);
      if (m != null) {
        final target = m.group(1)!;
        final cacheKey = '$sourceDir|$target';
        final resolved = cache.putIfAbsent(
          cacheKey,
          () => ProjectIndex.resolveImportPath(fromPath, target, packageName),
        );
        total++;
        final category = _classifyImport(target, resolved, packageName);
        switch (category) {
          case 'resolvedToProject':
            resolvedToProject++;
            break;
          case 'externalPackage':
            externalPackage++;
            break;
          default:
            unresolved++;
        }
        if (resolved != null && resolved.isNotEmpty) result.add(resolved);
        break;
      }
    }
  }
  return (result, _ImportCounts(total, resolvedToProject, externalPackage, unresolved));
}

Future<String?> _readPackageName(String projectPath) async {
  final pubspec = File('$projectPath/pubspec.yaml');
  if (!await pubspec.exists()) return null;
  final content = await pubspec.readAsString();
  final match = RegExp(r'name:\s*(\S+)').firstMatch(content);
  return match?.group(1);
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
Future<ScanReport> runScan(String projectPath,
    {ScannerConfig? config,
    List<Rule>? rules,
    String? projectDisplayName,
    String? scanPath}) async {
  final resolvedConfig = config ?? await ScannerConfig.load(projectPath);
  final (:index, :meta, :moduleIndex) = await buildIndexWithMeta(projectPath, resolvedConfig);
  final ruleList = rules ?? defaultRules;
  final results = <RuleResult>[];
  for (final rule in ruleList) {
    results.add(rule.run(index, resolvedConfig));
  }
  final scoreResult = ScoringEngine.run(results);
  final uniqueFindings = _computeUniqueFindings(results);
  final aggregation = CategoryAggregation.fromRuleResults(
    results,
    ruleIdToCategory,
    uniqueFindings: uniqueFindings,
  );
  var report = ScanReport(
    score: scoreResult.score,
    riskLevel: scoreResult.riskLevel,
    ruleResults: results,
    uniqueFindings: uniqueFindings,
    timestamp: DateTime.now().toUtc(),
    projectPath: projectPath,
    projectDisplayName: projectDisplayName,
    scanPath: scanPath,
    aggregation: aggregation,
    meta: meta,
    moduleIndex: moduleIndex,
  );
  report = report.copyWith(
    capHits: ReportDebug.computeCapHits(results),
    hotspotMetrics: ReportDebug.computeHotspotMetrics(report),
  );
  return report;
}

/// Flattens findings from [results], sorts deterministically, dedupes by fingerprint.
List<Finding> _computeUniqueFindings(List<RuleResult> results) {
  final all = <Finding>[];
  for (final r in results) all.addAll(r.findings);
  all.sort((a, b) {
    final sev = b.severity.index.compareTo(a.severity.index);
    if (sev != 0) return sev;
    final file = a.file.compareTo(b.file);
    if (file != 0) return file;
    final al = a.line ?? 0;
    final bl = b.line ?? 0;
    final lineCmp = al.compareTo(bl);
    if (lineCmp != 0) return lineCmp;
    return a.evidenceNormalized.compareTo(b.evidenceNormalized);
  });
  final seen = <String>{};
  final out = <Finding>[];
  for (final f in all) {
    if (seen.add(f.fingerprint)) out.add(f);
  }
  return out;
}
