import 'dart:convert';
import 'dart:io';

import '../core/rule_metadata.dart';
import '../model/risk_level.dart';
import 'baseline_model.dart';

class BaselineLoadResult {
  const BaselineLoadResult({this.baseline, this.warning});

  final ScaleGuardBaseline? baseline;
  final String? warning;
}

class BaselineStore {
  const BaselineStore._();

  static const String baselineRelativePath = '.scaleguard/baseline.json';

  static String baselinePathForProject(String projectPath) =>
      '$projectPath/$baselineRelativePath';

  static Future<BaselineLoadResult> load(String baselinePath) async {
    final file = File(baselinePath);
    if (!await file.exists()) {
      return const BaselineLoadResult(
        warning:
            'Baseline not found at .scaleguard/baseline.json. Run with --save-baseline first.',
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on FileSystemException catch (e) {
      return BaselineLoadResult(
          warning: 'Unable to read baseline file: ${e.message}');
    } on FormatException catch (e) {
      return BaselineLoadResult(warning: 'Invalid baseline JSON: ${e.message}');
    }

    if (decoded is! Map<String, dynamic>) {
      return const BaselineLoadResult(
          warning: 'Invalid baseline format: expected top-level JSON object.');
    }

    try {
      final parsed = _parseBaseline(decoded);
      return BaselineLoadResult(baseline: parsed);
    } on UnsupportedError catch (e) {
      return BaselineLoadResult(warning: e.message);
    } on FormatException catch (e) {
      return BaselineLoadResult(warning: 'Invalid baseline format: ${e.message}');
    }
  }

  static Future<void> save(String baselinePath, ScaleGuardBaseline baseline) async {
    final file = File(baselinePath);
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final json = const JsonEncoder.withIndent('  ').convert(_toJson(baseline));
    await file.writeAsString('$json\n');
  }

  static ScaleGuardBaseline _parseBaseline(Map<String, dynamic> json) {
    final baselineVersion = _readRequiredInt(json, 'baselineVersion');
    if (baselineVersion != 1) {
      throw UnsupportedError(
          'Unsupported baselineVersion: $baselineVersion. Please create a new baseline.');
    }
    final createdAtRaw = json['createdAt'];
    if (createdAtRaw is! String) {
      throw const FormatException('createdAt must be an ISO timestamp string.');
    }
    final createdAt = DateTime.tryParse(createdAtRaw)?.toUtc();
    if (createdAt == null) {
      throw const FormatException('createdAt is not a valid ISO timestamp.');
    }
    final summaryRaw = json['summary'];
    if (summaryRaw is! Map<String, dynamic>) {
      throw const FormatException('summary must be an object.');
    }
    final summary = _parseSummary(summaryRaw);
    final configRaw = json['configSnapshot'];
    BaselineConfigSnapshot? configSnapshot;
    if (configRaw is Map<String, dynamic>) {
      configSnapshot = _parseConfigSnapshot(configRaw);
    }
    final projectRaw = json['project'];
    String? relativePath;
    if (projectRaw is Map<String, dynamic>) {
      final v = projectRaw['relativePath'];
      if (v is String) relativePath = v;
    }

    return ScaleGuardBaseline(
      baselineVersion: baselineVersion,
      createdAt: createdAt,
      toolVersion: json['toolVersion'] as String?,
      projectRelativePath: relativePath,
      configSnapshot: configSnapshot,
      summary: summary,
    );
  }

  static BaselineSummary _parseSummary(Map<String, dynamic> json) {
    final score = _readRequiredInt(json, 'score');
    final risk = _parseRiskLevel(json['riskLevel']);
    final categoryPenaltiesRaw = json['categoryPenalties'];
    if (categoryPenaltiesRaw is! Map<String, dynamic>) {
      throw const FormatException('summary.categoryPenalties must be an object.');
    }
    final categoryPenalties = <String, double>{};
    for (final entry in categoryPenaltiesRaw.entries) {
      final value = entry.value;
      if (value is num) {
        categoryPenalties[entry.key] = value.toDouble();
      }
    }
    for (final category in allCategories) {
      categoryPenalties.putIfAbsent(category, () => 0.0);
    }

    final findingsRaw = json['findings'];
    if (findingsRaw is! Map<String, dynamic>) {
      throw const FormatException('summary.findings must be an object.');
    }
    final findingsTotal = _readRequiredInt(findingsRaw, 'total');
    final bySeverityRaw = findingsRaw['bySeverity'];
    final findingsBySeverity = <String, int>{'high': 0, 'medium': 0, 'low': 0};
    if (bySeverityRaw is Map<String, dynamic>) {
      for (final key in findingsBySeverity.keys) {
        final value = bySeverityRaw[key];
        if (value is int) findingsBySeverity[key] = value;
      }
    }

    final topHotspots = <BaselineHotspot>[];
    final hotspotsRaw = json['topHotspots'];
    if (hotspotsRaw is List) {
      for (final entry in hotspotsRaw) {
        if (entry is! Map<String, dynamic>) continue;
        final path = entry['path'];
        final riskValue = entry['risk'];
        if (path is String && riskValue is int) {
          topHotspots.add(
              BaselineHotspot(path: path, risk: riskValue, loc: entry['loc'] as int?));
        }
      }
    }

    return BaselineSummary(
      score: score,
      riskLevel: risk,
      categoryPenalties: categoryPenalties,
      findingsTotal: findingsTotal,
      findingsBySeverity: findingsBySeverity,
      topHotspots: topHotspots,
    );
  }

  static BaselineConfigSnapshot _parseConfigSnapshot(Map<String, dynamic> json) {
    final enabledRaw = json['enabledRuleIds'];
    final enabledRuleIds = <String>[];
    if (enabledRaw is List) {
      for (final item in enabledRaw) {
        if (item is String) enabledRuleIds.add(item);
      }
    }
    enabledRuleIds.sort();

    final rootsRaw = json['featureRoots'];
    final featureRoots = <String>[];
    if (rootsRaw is List) {
      for (final item in rootsRaw) {
        if (item is String) featureRoots.add(item);
      }
    }
    featureRoots.sort();

    final ignoreCountValue = json['ignoreCount'];
    final ignoreCount = ignoreCountValue is int ? ignoreCountValue : 0;

    return BaselineConfigSnapshot(
      enabledRuleIds: enabledRuleIds,
      ignoreCount: ignoreCount,
      featureRoots: featureRoots,
    );
  }

  static Map<String, dynamic> _toJson(ScaleGuardBaseline baseline) {
    return {
      'baselineVersion': baseline.baselineVersion,
      'toolVersion': baseline.toolVersion,
      'createdAt': baseline.createdAt.toUtc().toIso8601String(),
      if (baseline.projectRelativePath != null)
        'project': {'relativePath': baseline.projectRelativePath},
      if (baseline.configSnapshot != null)
        'configSnapshot': {
          'enabledRuleIds': baseline.configSnapshot!.enabledRuleIds,
          'ignoreCount': baseline.configSnapshot!.ignoreCount,
          'featureRoots': baseline.configSnapshot!.featureRoots,
        },
      'summary': {
        'score': baseline.summary.score,
        'riskLevel': _riskLevelText(baseline.summary.riskLevel),
        'categoryPenalties': baseline.summary.categoryPenalties,
        'topHotspots': [
          for (final hotspot in baseline.summary.topHotspots)
            {
              'path': hotspot.path,
              'risk': hotspot.risk,
              if (hotspot.loc != null) 'loc': hotspot.loc,
            }
        ],
        'findings': {
          'total': baseline.summary.findingsTotal,
          'bySeverity': baseline.summary.findingsBySeverity,
        },
      },
    };
  }

  static int _readRequiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int) {
      throw FormatException('$key must be an integer.');
    }
    return value;
  }

  static RiskLevel _parseRiskLevel(dynamic value) {
    if (value is! String) {
      throw const FormatException('riskLevel must be a string.');
    }
    switch (value.toLowerCase()) {
      case 'low':
        return RiskLevel.low;
      case 'medium':
        return RiskLevel.medium;
      case 'high':
        return RiskLevel.high;
      default:
        throw FormatException('unknown riskLevel: $value');
    }
  }

  static String _riskLevelText(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return 'Low';
      case RiskLevel.medium:
        return 'Medium';
      case RiskLevel.high:
        return 'High';
    }
  }
}
