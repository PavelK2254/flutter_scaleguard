import '../core/module_root.dart';
import '../core/path_utils.dart' as path_utils;
import '../core/rule_metadata.dart';
import '../model/category_aggregation.dart';
import '../model/finding.dart';
import '../model/risk_level.dart';
import '../model/scan_report.dart';
import '../model/severity.dart';
import '../version.dart';

class ConsoleRenderer {
  ConsoleRenderer._();

  static const int _softPenaltyThreshold = 8;
  static const Set<String> _rulesWithTargetHotspot = {
    'cross_feature_coupling',
  };

  /// Renders [report] to the console. [version] should come from [getPackageVersion]
  /// so the banner matches pubspec; if null, uses [fallbackPackageVersion].
  /// When [showStats] is true and report has meta, prints Scan Stats section.
  static void render(ScanReport report, {String? version, bool showStats = false}) {
    final v = version ?? fallbackPackageVersion;
    final versionLabel = v.startsWith('v') ? v : 'v$v';
    print('Flutter ScaleGuard $versionLabel');
    print('Project: ${report.projectPath ?? '<unknown>'}');
    print('');
    print('Architecture Score: ${report.score}/100');
    print('Risk Level: ${_riskLevelLabel(report.riskLevel)}');
    print('');

    final agg = report.aggregation;
    if (agg != null) {
      final useSoft = report.score >= 90 ||
          (agg.totalPenalty <= _softPenaltyThreshold && agg.totalPenalty > 0);
      final summaries = useSoft ? categoryToSummarySoft : categoryToSummary;
      final summary = summaries[agg.dominantCategory] ??
          'No dominant risk category.';
      print('Summary:');
      print(summary);
      print('');

      final pct = agg.totalPenalty > 0
          ? (agg.categoryScores.isNotEmpty
              ? (agg.categoryScores.first.totalPenalty / agg.totalPenalty * 100)
                  .round()
              : 0)
          : 0;
      final dominantSuffix = agg.totalPenalty > 0 && agg.totalPenalty <= _softPenaltyThreshold
          ? ' ($pct% of total penalty, low intensity)'
          : ' ($pct% of total penalty)';
      if (agg.dominantCategory.isNotEmpty || agg.totalPenalty > 0) {
        print('Dominant Risk Category: ${agg.dominantCategory}$dominantSuffix');
      }
      final displayName = ruleIdToDisplayLabel[agg.mostExpensiveRuleId] ??
          agg.mostExpensiveRuleId;
      final mostExpCategory =
          ruleIdToCategory[agg.mostExpensiveRuleId] ?? agg.mostExpensiveRuleId;
      print(
          'Most Expensive Risk: $displayName (-${agg.mostExpensivePenalty}) [$mostExpCategory] [rule: ${agg.mostExpensiveRuleId}]');
      final ruleId = agg.mostExpensiveRuleId;
      final forRule = report.uniqueFindings
          .where((f) => f.ruleId == ruleId)
          .toList();
      (String, int)? sourceTop;
      (String, int)? targetTop;
      if (forRule.isNotEmpty) {
        final sourceCountByKey = <String, int>{};
        Map<String, int>? targetCountByKey;
        final hasTargetHotspot = _rulesWithTargetHotspot.contains(ruleId);
        for (final f in forRule) {
          final sk = getSourceHotspotKey(f, report);
          sourceCountByKey[sk] = (sourceCountByKey[sk] ?? 0) + 1;
          if (hasTargetHotspot) {
            final tk = getTargetHotspotKey(f);
            if (tk != null && tk.isNotEmpty) {
              targetCountByKey ??= <String, int>{};
              targetCountByKey[tk] = (targetCountByKey[tk] ?? 0) + 1;
            }
          }
        }
        sourceTop = _topHotspotEntry(sourceCountByKey);
        targetTop = hasTargetHotspot && targetCountByKey != null && targetCountByKey.isNotEmpty
            ? _topHotspotEntry(targetCountByKey)
            : null;
      }
      _printMostExpensiveHotspot(report, ruleId, sourceTop, targetTop);
      _printMostExpensiveExamples(
          report, ruleId, topSourceHotspotKey: sourceTop?.$1);
      print('');
      print('---');
      print('');
      _printFindingsByCategory(report, agg);
      _printPenaltyByCategory(agg);
      print('---');
      print('');
      _printTopHotspots(report);
      print('---');
      print('');
      final whyMap = useSoft ? categoryToWhySoft : categoryToWhyStandard;
      final why = whyMap[agg.dominantCategory] ?? '';
      print('Why This Matters');
      print(why);
      if (showStats && report.meta != null) _printScanStats(report);
    } else {
      final findings = report.findings;
      if (findings.isEmpty) {
        print('No findings.');
      } else {
        final high =
            findings.where((f) => f.severity == FindingSeverity.high).toList();
        final medium = findings
            .where((f) => f.severity == FindingSeverity.medium)
            .toList();
        if (high.isNotEmpty) {
          print('--- High ---');
          for (final f in high) _printFinding(f);
          print('');
        }
        if (medium.isNotEmpty) {
          print('--- Medium ---');
          for (final f in medium) _printFinding(f);
          print('');
        }
      }
      if (showStats && report.meta != null) _printScanStats(report);
    }
  }

  static void _printScanStats(ScanReport report) {
    final m = report.meta!;
    print('');
    print('Scan Stats');
    print(
        'Files scanned: ${m.scannedFiles} (${m.ignoredFiles} ignored)');
    print(
        'Imports: ${m.importsResolvedToProject}/${m.importsTotal} resolved | ${m.importsExternalPackage} external | ${m.importsUnresolved} unresolved');
  }

  static const int _maxEvidenceLength = 80;
  static const int _maxPathLength = 56;

  /// Middle truncation that preserves the full last path segment (filename).
  /// If s.length <= maxLen returns s. Otherwise returns prefix + '...' + suffix
  /// where suffix is from the last '/' to end (or whole s if no '/').
  static String _truncateMiddle(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    final lastSlash = s.lastIndexOf('/');
    final suffix = lastSlash < 0 ? s : s.substring(lastSlash);
    final prefixLen = maxLen - 3 - suffix.length;
    if (prefixLen <= 0) return '...$suffix';
    return '${s.substring(0, prefixLen)}...$suffix';
  }

  static void _printMostExpensiveHotspot(
    ScanReport report,
    String ruleId,
    (String, int)? sourceTop,
    (String, int)? targetTop,
  ) {
    if (sourceTop != null) {
      print('Hotspot (source): ${sourceTop.$1} (${sourceTop.$2} findings)');
    }
    if (targetTop != null) {
      print('Hotspot (target): ${targetTop.$1} (${targetTop.$2} findings)');
    }
  }

  /// Top entry by count desc then key asc. Returns (key, count) or null if empty.
  static (String, int)? _topHotspotEntry(Map<String, int> countByKey) {
    if (countByKey.isEmpty) return null;
    final entries = countByKey.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    final e = entries.first;
    return (e.key, e.value);
  }

  /// Ordered hotspot keys by count desc then key asc.
  static List<String> _orderedSourceHotspotKeys(Map<String, int> countByKey) {
    final entries = countByKey.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    return [for (final e in entries) e.key];
  }

  static void _printMostExpensiveExamples(
    ScanReport report,
    String ruleId, {
    String? topSourceHotspotKey,
  }) {
    final forRule = report.uniqueFindings
        .where((f) => f.ruleId == ruleId)
        .toList();
    if (forRule.isEmpty) return;
    // Deterministic ordering within a rule: severity desc, file asc, line asc, resolvedImportedPath asc.
    forRule.sort((a, b) {
      final sev = b.severity.index.compareTo(a.severity.index);
      if (sev != 0) return sev;
      final file = _normPath(a.file).compareTo(_normPath(b.file));
      if (file != 0) return file;
      final al = a.line ?? 0;
      final bl = b.line ?? 0;
      final lineCmp = al.compareTo(bl);
      if (lineCmp != 0) return lineCmp;
      final resA = a.resolvedImportedPath ?? '';
      final resB = b.resolvedImportedPath ?? '';
      return resA.compareTo(resB);
    });

    // Count findings per source hotspot key for this rule.
    final sourceCountByKey = <String, int>{};
    for (final f in forRule) {
      final key = getSourceHotspotKey(f, report);
      sourceCountByKey[key] = (sourceCountByKey[key] ?? 0) + 1;
    }
    const maxExamples = 3;
    final seenFiles = <String>{};
    final examples = <Finding>[];
    // Determine the primary hotspot key to use for examples.
    String? primaryKey;
    if (topSourceHotspotKey != null &&
        sourceCountByKey.containsKey(topSourceHotspotKey)) {
      primaryKey = topSourceHotspotKey;
    } else {
      final orderedKeys = _orderedSourceHotspotKeys(sourceCountByKey);
      if (orderedKeys.isNotEmpty) {
        primaryKey = orderedKeys.first;
      }
    }
    if (primaryKey != null) {
      for (final f in forRule) {
        if (getSourceHotspotKey(f, report) != primaryKey) continue;
        if (!seenFiles.add(f.file)) continue;
        examples.add(f);
        if (examples.length >= maxExamples) break;
      }
    }

    print('Examples:');
    for (final f in examples) {
      final loc = f.line != null ? ':${f.line}' : '';
      final String evidence;
      if (ruleId == 'cross_feature_coupling' &&
          f.fromFeature != null &&
          f.toFeature != null) {
        final String pathStr;
        if (f.targetFeaturePath != null &&
            f.resolvedImportedPath != null &&
            f.resolvedImportedPath!.startsWith(f.targetFeaturePath!)) {
          final tail = f.resolvedImportedPath!.length > f.targetFeaturePath!.length + 1
              ? f.resolvedImportedPath!.substring(f.targetFeaturePath!.length + 1)
              : '';
          final tailMax = _maxPathLength - f.targetFeaturePath!.length - 2;
          pathStr = tailMax > 0
              ? '${f.targetFeaturePath}/${_truncateMiddle(tail, tailMax)}'
              : '${f.targetFeaturePath}/...';
        } else {
          final path = f.resolvedImportedPath ?? f.file;
          pathStr = _truncateMiddle(path, _maxPathLength);
        }
        evidence = '${f.fromFeature} -> ${f.toFeature} $pathStr';
      } else {
        evidence = f.message.length > _maxEvidenceLength
            ? '${f.message.substring(0, _maxEvidenceLength)}...'
            : f.message;
      }
      print('  ${f.file}$loc $evidence');
    }
    final more = forRule.length - examples.length;
    if (more > 0) print('  (+$more more)');
  }

  static void _printFindingsByCategory(
      ScanReport report, CategoryAggregation aggregation) {
    print('Findings by Category');
    print('');
    final ruleIdToCat = ruleIdToCategory;
    for (final cs in aggregation.categoryScores) {
      final ruleResultsInCategory = report.ruleResults
          .where((r) => (ruleIdToCat[r.ruleId] ?? r.ruleId) == cs.category)
          .where((r) => r.findings.isNotEmpty)
          .toList();
      if (ruleResultsInCategory.isEmpty) continue;
      ruleResultsInCategory.sort((a, b) => a.ruleId.compareTo(b.ruleId));
      print(cs.category);
      for (final r in ruleResultsInCategory) {
        final forRule = report.uniqueFindings
            .where((f) => f.ruleId == r.ruleId)
            .toList();
        final uniqueCount = forRule.length;
        final fileCount = forRule.map((f) => f.file).toSet().length;
        final label = ruleIdToDisplayLabel[r.ruleId] ?? r.ruleId;
        print('  - $label ($uniqueCount across $fileCount files)');
      }
      print('');
    }
  }

  /// Prints penalty totals by category when [aggregation.totalPenalty] > 0.
  /// Order: penalty desc, then name asc. Format: two decimals, negative (e.g. -12.25, -0.00).
  static void _printPenaltyByCategory(CategoryAggregation aggregation) {
    if (aggregation.totalPenalty <= 0) return;
    print('Penalty by Category');
    for (final e in aggregation.penaltyByCategory.entries) {
      final value = e.value;
      final formatted = value.toStringAsFixed(2);
      print('${e.key}: -$formatted');
    }
    print('Total Penalty: -${aggregation.totalPenalty.toStringAsFixed(2)}');
    print('');
  }

  /// Normalize path separators for deterministic comparison and extraction.
  static String _normPath(String p) => path_utils.normalizePath(p);

  /// Source hotspot key from [Finding.file]. Uses [report.moduleIndex] when present,
  /// otherwise [moduleRootKey] on normalized path. Deterministic across platforms.
  static String getSourceHotspotKey(Finding f, ScanReport report) {
    final norm = _normPath(f.file);
    return report.moduleIndex?[norm] ?? moduleRootKey(norm);
  }

  /// Target hotspot key from [Finding.resolvedImportedPath]. Returns null if none or external.
  static String? getTargetHotspotKey(Finding f) {
    final path = f.resolvedImportedPath;
    if (path == null || path.isEmpty) return null;
    final norm = _normPath(path);
    if (!norm.startsWith('lib/')) return null;
    return moduleRootKey(norm);
  }

  static void _printTopHotspots(ScanReport report) {
    print('Top Hotspots');
    print('');
    final findings = report.uniqueFindings;
    if (findings.isEmpty) {
      return;
    }
    final countByKey = <String, int>{};
    final ruleCountByKey = <String, Map<String, int>>{};
    for (final f in findings) {
      final key = getSourceHotspotKey(f, report);
      countByKey[key] = (countByKey[key] ?? 0) + 1;
      ruleCountByKey[key] ??= {};
      ruleCountByKey[key]![f.ruleId] = (ruleCountByKey[key]![f.ruleId] ?? 0) + 1;
    }
    final entries = countByKey.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    final top3 = entries.take(3).toList();
    for (final e in top3) {
      final ruleCounts = ruleCountByKey[e.key]!;
      final topRules = ruleCounts.entries.toList()
        ..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          if (byCount != 0) return byCount;
          return a.key.compareTo(b.key);
        });
      final top2 = topRules.take(2).toList();
      final rulePart = top2.isEmpty
          ? ''
          : ' — ${top2.map((r) => '${r.key}: ${r.value}').join(', ')}';
      print('${e.key} (${e.value} findings)$rulePart');
    }
  }

  static String _riskLevelLabel(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return 'Low';
      case RiskLevel.medium:
        return 'Medium';
      case RiskLevel.high:
        return 'High';
    }
  }

  static void _printFinding(Finding f) {
    final loc = f.line != null ? ':${f.line}' : '';
    final label = ruleIdToDisplayLabel[f.ruleId] ?? f.ruleId;
    print('  [$label] ${f.file}$loc');
    print('    ${f.message}');
  }
}
