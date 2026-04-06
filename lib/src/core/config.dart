import 'dart:io';

import 'package:yaml/yaml.dart';

import 'ignore_matcher.dart';
import 'path_utils.dart' as path_utils;
import 'scaleguard_yaml.dart';

/// Default LOC threshold for "medium" god file finding.
const int defaultGodFileMediumLoc = 500;

/// Default LOC threshold for "high" god file finding.
const int defaultGodFileHighLoc = 900;

/// Default feature root relative to project (lib).
const String defaultFeatureRoot = 'lib/features';

/// Default shared/common path segments that must not import features.
const List<String> defaultSharedPathSegments = ['shared', 'common'];

/// Default ignore patterns (file path contains or ends with).
/// Segment-based: e.g. /build/ means path contains "/build/".
const List<String> defaultIgnoredPatterns = [
  '.g.dart',
  '.freezed.dart',
  '.gen.dart',
  '/build/',
  '/.dart_tool/',
  '/generated/',
  '/gen/',
  '/ios/',
  '/android/',
  '/test/',
  '/integration_test/',
];

/// Layer names for clean architecture.
const String layerPresentation = 'presentation';
const String layerDomain = 'domain';
const String layerData = 'data';

/// Default path segment that identifies a layer (under feature).
const Map<String, String> defaultLayerMappings = {
  'presentation': layerPresentation,
  'domain': layerDomain,
  'data': layerData,
};

/// Allowed layer dependencies: fromLayer -> Set of layers it may import.
/// MVP: same-layer allowed; presentation->domain; data->domain, data->data; domain->data disallowed unless allowDomainToData.
const Map<String, Set<String>> defaultAllowedLayerDependencies = {
  layerPresentation: {layerPresentation, layerDomain},
  layerDomain: {layerDomain},
  layerData: {layerDomain, layerData},
};

class ScannerConfig {
  const ScannerConfig({
    this.featureRoots = const [defaultFeatureRoot],
    this.layerMappings = defaultLayerMappings,
    this.ignoredPatterns = defaultIgnoredPatterns,
    this.godFileMediumLoc = defaultGodFileMediumLoc,
    this.godFileHighLoc = defaultGodFileHighLoc,
    this.sharedPathSegments = defaultSharedPathSegments,
    this.allowedLayerDependencies = defaultAllowedLayerDependencies,
    this.allowDomainToData = false,
    this.serviceLocatorPatterns = const [
      'GetIt.instance',
      'GetIt.I',
      'Get.find',
      'Provider.of',
      'context.read',
      'context.watch',
      'getIt.',
      'GetIt().',
    ],
    this.routeConstantPrefixes = const ['Routes.', 'AppRoutes.'],
    this.hardcodedUrlPatterns = const [
      'http://',
      'https://',
      'www.',
    ],
    this.ruleEnabled = const {},
    this.failUnder,
  });

  final List<String> featureRoots;
  final Map<String, String> layerMappings;
  final List<String> ignoredPatterns;
  final int godFileMediumLoc;
  final int godFileHighLoc;
  final List<String> sharedPathSegments;
  final Map<String, Set<String>> allowedLayerDependencies;
  final bool allowDomainToData;
  final List<String> serviceLocatorPatterns;
  final List<String> routeConstantPrefixes;
  final List<String> hardcodedUrlPatterns;

  /// Explicit rule toggles from config; absent ids default to enabled.
  final Map<String, bool> ruleEnabled;

  /// Optional minimum score for CI when not overridden by `--fail-under`.
  final int? failUnder;

  bool isRuleEnabled(String ruleId) => ruleEnabled[ruleId] ?? true;

  /// Load config from project root ([scaleguard.yaml] primary, else [risk_scanner.yaml]).
  /// Warnings from parsing are discarded; use [loadWithDiagnostics] to observe them.
  static Future<ScannerConfig> load(String projectPath) async {
    final r = await loadWithDiagnostics(projectPath);
    return r.config;
  }

  /// Loads config and returns recoverable parse warnings (e.g. unknown keys).
  static Future<({ScannerConfig config, List<String> warnings})>
      loadWithDiagnostics(String projectPath) async {
    final warnings = <String>[];
    final dir = path_utils.normalizePath(projectPath);
    final base = dir.endsWith('/') ? dir : '$dir/';
    final scaleguardFile = File('${base}scaleguard.yaml');
    final riskFile = File('${base}risk_scanner.yaml');
    final hasScale = await scaleguardFile.exists();
    final hasRisk = await riskFile.exists();

    if (hasScale && hasRisk) {
      warnings.add(
          'Both scaleguard.yaml and risk_scanner.yaml exist; only scaleguard.yaml is loaded. risk_scanner.yaml is ignored.');
    }

    if (hasScale) {
      final content = await scaleguardFile.readAsString();
      final yaml = loadYaml(content) as YamlMap?;
      if (yaml == null || yaml.isEmpty) {
        return (config: const ScannerConfig(), warnings: warnings);
      }
      final parsed = parseScaleguardYaml(yaml, warnings);
      final config = _mergeScaleguard(const ScannerConfig(), parsed, warnings);
      return (config: config, warnings: warnings);
    }

    if (hasRisk) {
      final content = await riskFile.readAsString();
      final yaml = loadYaml(content) as YamlMap?;
      if (yaml == null || yaml.isEmpty) {
        return (config: const ScannerConfig(), warnings: warnings);
      }
      return (config: _fromRiskScannerYaml(yaml), warnings: warnings);
    }

    return (config: const ScannerConfig(), warnings: warnings);
  }

  static ScannerConfig _mergeScaleguard(
    ScannerConfig base,
    ScaleguardParsed parsed,
    List<String> warnings,
  ) {
    var medium =
        parsed.godFileMediumLoc ?? base.godFileMediumLoc;
    var high = parsed.godFileHighLoc ?? base.godFileHighLoc;
    if (medium >= high) {
      warnings.add(
          'god_file_medium_loc must be less than god_file_high_loc; values were swapped.');
      final t = medium;
      medium = high;
      high = t;
    }
    if (medium >= high) {
      warnings.add(
          'God file thresholds still invalid after swap; using defaults.');
      medium = defaultGodFileMediumLoc;
      high = defaultGodFileHighLoc;
    }

    final roots = parsed.featureRoots ?? base.featureRoots;
    final mergedIgnore = mergeIgnoredPatterns(defaultIgnoredPatterns, parsed.ignoreEntries);

    return ScannerConfig(
      featureRoots: roots,
      layerMappings: base.layerMappings,
      ignoredPatterns: mergedIgnore,
      godFileMediumLoc: medium,
      godFileHighLoc: high,
      sharedPathSegments: base.sharedPathSegments,
      allowedLayerDependencies: base.allowedLayerDependencies,
      allowDomainToData: base.allowDomainToData,
      serviceLocatorPatterns: base.serviceLocatorPatterns,
      routeConstantPrefixes: base.routeConstantPrefixes,
      hardcodedUrlPatterns: base.hardcodedUrlPatterns,
      ruleEnabled: Map<String, bool>.from(parsed.ruleEnabled),
      failUnder: parsed.failUnder,
    );
  }

  static ScannerConfig _fromRiskScannerYaml(YamlMap yaml) {
    List<String> list(String key, List<String> fallback) {
      final v = yaml[key];
      if (v == null) return fallback;
      if (v is YamlList) return v.map((e) => e.toString()).toList();
      return fallback;
    }

    final featureRoots = list('feature_roots', [defaultFeatureRoot]);
    final ignoredPatterns = list('ignored_patterns', defaultIgnoredPatterns);
    final sharedPathSegments =
        list('shared_path_segments', defaultSharedPathSegments);
    final godFileMediumLoc =
        _readYamlInt(yaml['god_file_medium_loc']) ?? defaultGodFileMediumLoc;
    final godFileHighLoc =
        _readYamlInt(yaml['god_file_high_loc']) ?? defaultGodFileHighLoc;

    Map<String, String> layerMappings = defaultLayerMappings;
    final lm = yaml['layer_mappings'];
    if (lm is YamlMap) {
      layerMappings = Map.fromEntries(
        lm.entries.map((e) => MapEntry(e.key.toString(), e.value.toString())),
      );
    }

    Map<String, Set<String>> allowedLayerDependencies =
        defaultAllowedLayerDependencies;
    final ald = yaml['allowed_layer_dependencies'];
    if (ald is YamlMap) {
      allowedLayerDependencies = {};
      for (final e in ald.entries) {
        final key = e.key.toString();
        final val = e.value;
        if (val is YamlList) {
          allowedLayerDependencies[key] = val.map((x) => x.toString()).toSet();
        }
      }
    }

    final allowDomainToData = (yaml['allow_domain_to_data'] as bool?) ?? false;
    if (allowDomainToData &&
        allowedLayerDependencies.containsKey(layerDomain)) {
      allowedLayerDependencies = Map.from(allowedLayerDependencies);
      allowedLayerDependencies[layerDomain] = {
        ...?allowedLayerDependencies[layerDomain],
        layerData,
      };
    }

    final serviceLocatorPatterns = list('service_locator_patterns', const [
      'GetIt.instance',
      'GetIt.I',
      'Get.find',
      'Provider.of',
      'context.read',
      'context.watch',
      'getIt.',
      'GetIt().',
    ]);
    final routeConstantPrefixes =
        list('route_constant_prefixes', const ['Routes.', 'AppRoutes.']);
    final hardcodedUrlPatterns =
        list('hardcoded_url_patterns', const ['http://', 'https://', 'www.']);

    return ScannerConfig(
      featureRoots: featureRoots,
      layerMappings: layerMappings,
      ignoredPatterns: ignoredPatterns,
      godFileMediumLoc: godFileMediumLoc,
      godFileHighLoc: godFileHighLoc,
      sharedPathSegments: sharedPathSegments,
      allowedLayerDependencies: allowedLayerDependencies,
      allowDomainToData: allowDomainToData,
      serviceLocatorPatterns: serviceLocatorPatterns,
      routeConstantPrefixes: routeConstantPrefixes,
      hardcodedUrlPatterns: hardcodedUrlPatterns,
    );
  }

  static int? _readYamlInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return null;
  }

  /// Returns true if [path] should be ignored (e.g. generated files).
  bool shouldIgnore(String path) {
    final normalized = path_utils.normalizePath(path);
    return shouldIgnoreNormalizedPath(normalized, ignoredPatterns);
  }
}

/// Defaults first, then [extras], deduplicated by exact pattern string.
List<String> mergeIgnoredPatterns(List<String> defaults, List<String> extras) {
  final seen = <String>{};
  final out = <String>[];
  for (final p in defaults) {
    if (seen.add(p)) out.add(p);
  }
  for (final p in extras) {
    if (seen.add(p)) out.add(p);
  }
  return out;
}
