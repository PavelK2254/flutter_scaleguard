import 'dart:io';

import 'package:yaml/yaml.dart';

/// Default LOC threshold for "medium" god file finding.
const int defaultGodFileMediumLoc = 500;

/// Default LOC threshold for "high" god file finding.
const int defaultGodFileHighLoc = 900;

/// Default feature root relative to project (lib).
const String defaultFeatureRoot = 'lib/features';

/// Default shared/common path segments that must not import features.
const List<String> defaultSharedPathSegments = ['shared', 'common'];

/// Default ignore patterns (file path contains or ends with).
const List<String> defaultIgnoredPatterns = [
  '.g.dart',
  '.freezed.dart',
  '.gen.dart',
  '/build/',
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
/// presentation -> domain; domain -> (none from other layers); data -> domain.
const Map<String, Set<String>> defaultAllowedLayerDependencies = {
  layerPresentation: {layerDomain},
  layerDomain: {},
  layerData: {layerDomain},
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
  });

  final List<String> featureRoots;
  final Map<String, String> layerMappings;
  final List<String> ignoredPatterns;
  final int godFileMediumLoc;
  final int godFileHighLoc;
  final List<String> sharedPathSegments;
  final Map<String, Set<String>> allowedLayerDependencies;
  final List<String> serviceLocatorPatterns;
  final List<String> routeConstantPrefixes;
  final List<String> hardcodedUrlPatterns;

  /// Load config from project root. If [risk_scanner.yaml] exists, merge with defaults.
  static Future<ScannerConfig> load(String projectPath) async {
    final dir = projectPath.replaceAll('\\', '/');
    final base = dir.endsWith('/') ? dir : '$dir/';
    final file = File('${base}risk_scanner.yaml');
    if (!await file.exists()) {
      return const ScannerConfig();
    }
    final content = await file.readAsString();
    final yaml = loadYaml(content) as YamlMap?;
    if (yaml == null || yaml.isEmpty) return const ScannerConfig();
    return _fromYaml(yaml);
  }

  static ScannerConfig _fromYaml(YamlMap yaml) {
    List<String> list(String key, List<String> fallback) {
      final v = yaml[key];
      if (v == null) return fallback;
      if (v is YamlList) return v.map((e) => e.toString()).toList();
      return fallback;
    }

    final featureRoots = list('feature_roots', [defaultFeatureRoot]);
    final ignoredPatterns = list('ignored_patterns', defaultIgnoredPatterns);
    final sharedPathSegments = list('shared_path_segments', defaultSharedPathSegments);
    final godFileMediumLoc = (yaml['god_file_medium_loc'] as int?) ?? defaultGodFileMediumLoc;
    final godFileHighLoc = (yaml['god_file_high_loc'] as int?) ?? defaultGodFileHighLoc;

    Map<String, String> layerMappings = defaultLayerMappings;
    final lm = yaml['layer_mappings'];
    if (lm is YamlMap) {
      layerMappings = Map.fromEntries(
        lm.entries.map((e) => MapEntry(e.key.toString(), e.value.toString())),
      );
    }

    Map<String, Set<String>> allowedLayerDependencies = defaultAllowedLayerDependencies;
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
    final routeConstantPrefixes = list('route_constant_prefixes', const ['Routes.', 'AppRoutes.']);
    final hardcodedUrlPatterns = list('hardcoded_url_patterns', const ['http://', 'https://', 'www.']);

    return ScannerConfig(
      featureRoots: featureRoots,
      layerMappings: layerMappings,
      ignoredPatterns: ignoredPatterns,
      godFileMediumLoc: godFileMediumLoc,
      godFileHighLoc: godFileHighLoc,
      sharedPathSegments: sharedPathSegments,
      allowedLayerDependencies: allowedLayerDependencies,
      serviceLocatorPatterns: serviceLocatorPatterns,
      routeConstantPrefixes: routeConstantPrefixes,
      hardcodedUrlPatterns: hardcodedUrlPatterns,
    );
  }

  /// Returns true if [path] should be ignored (e.g. generated files).
  bool shouldIgnore(String path) {
    final normalized = path.replaceAll('\\', '/');
    for (final p in ignoredPatterns) {
      if (normalized.contains(p) || normalized.endsWith(p)) return true;
    }
    return false;
  }
}
