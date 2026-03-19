import '../core/hotspot_utils.dart';
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
  /// When [showDebug] is true, appends Debug Details (penalties, capHits, hotspot metrics).
  static void render(ScanReport report,
      {String? version, bool showStats = false, bool showDebug = false}) {
    final v = version ?? fallbackPackageVersion;
    final versionLabel = v.startsWith('v') ? v : 'v$v';
    print('Flutter ScaleGuard $versionLabel');
    print(
        'Project: ${report.projectDisplayName ?? report.projectPath ?? '<unknown>'}');
    print('Scan Path: ${report.scanPath ?? report.projectPath ?? '<unknown>'}');
    print('');
    print('Architecture Score: ${report.score}/100');
    print('Risk Level: ${_riskLevelLabel(report.riskLevel)}');
    print('');

    final agg = report.aggregation;
    if (agg != null) {
      final useSoft = report.score >= 90 ||
          (agg.totalPenalty <= _softPenaltyThreshold && agg.totalPenalty > 0);
      final summaries = useSoft ? categoryToSummarySoft : categoryToSummary;
      final summary =
          summaries[agg.dominantCategory] ?? 'No dominant risk category.';
      print('Summary:');
      print(summary);
      print('');

      final pct = agg.totalPenalty > 0
          ? (agg.categoryScores.isNotEmpty
              ? (agg.categoryScores.first.totalPenalty / agg.totalPenalty * 100)
                  .round()
              : 0)
          : 0;
      final dominantSuffix =
          agg.totalPenalty > 0 && agg.totalPenalty <= _softPenaltyThreshold
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
      final forRule =
          report.uniqueFindings.where((f) => f.ruleId == ruleId).toList();
      (String, int)? sourceTop;
      (String, int)? targetTop;
      if (forRule.isNotEmpty) {
        final sourceCountByKey = <String, int>{};
        Map<String, int>? targetCountByKey;
        final hasTargetHotspot = _rulesWithTargetHotspot.contains(ruleId);
        for (final f in forRule) {
          final sk = HotspotUtils.getSourceHotspotKey(f, report);
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
        targetTop = hasTargetHotspot &&
                targetCountByKey != null &&
                targetCountByKey.isNotEmpty
            ? _topHotspotEntry(targetCountByKey)
            : null;
      }
      _printMostExpensiveHotspot(report, ruleId, sourceTop, targetTop);
      _printMostExpensiveExamples(report, ruleId,
          topSourceHotspotKey: sourceTop?.$1);
      if (!showDebug && report.capHits != null && report.capHits!.isNotEmpty) {
        _printCapHitNote(report.capHits!);
      }
      print('');
      print('---');
      print('');
      if (report.uniqueFindings.isNotEmpty) {
        _printTopFixPriorities(report);
        print('');
        _printHotspots(report);
        print('---');
        print('');
      }
      _printFindingsByCategory(report, agg);
      _printCITip();
      if (showStats && report.meta != null) _printScanStats(report);
      if (showDebug) _printDebugDetails(report);
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
      if (showDebug) _printDebugDetails(report);
    }
  }

  static void _printScanStats(ScanReport report) {
    final m = report.meta!;
    print('');
    print('Scan Stats');
    print('Files scanned: ${m.scannedFiles} (${m.ignoredFiles} ignored)');
    print(
        'Imports: ${m.importsResolvedToProject}/${m.importsTotal} resolved | ${m.importsExternalPackage} external | ${m.importsUnresolved} unresolved');
  }

  /// Prints Debug Details section when [showDebug] is true. Only prints header if at least one block has content.
  static void _printDebugDetails(ScanReport report) {
    final agg = report.aggregation;
    final hasPenaltyByCategory =
        agg != null && agg.totalPenalty > 0 && agg.penaltyByCategory.isNotEmpty;
    final hasPenaltyByRule = agg != null && agg.penaltyByRule.isNotEmpty;
    final hasCapHits = report.capHits != null && report.capHits!.isNotEmpty;
    final hasHotspotMetrics = report.hotspotMetrics != null;

    if (!hasPenaltyByCategory &&
        !hasPenaltyByRule &&
        !hasCapHits &&
        !hasHotspotMetrics) {
      return;
    }

    print('');
    print('---');
    print('Debug Details');
    print('');

    if (hasPenaltyByCategory) {
      _printPenaltyByCategory(agg);
    }

    if (hasPenaltyByRule) {
      print('Penalty by Rule');
      final entries = agg.penaltyByRule.entries.toList()
        ..sort((a, b) {
          final byVal = b.value.compareTo(a.value);
          if (byVal != 0) return byVal;
          return a.key.compareTo(b.key);
        });
      for (final e in entries) {
        print('${e.key}: -${e.value.toStringAsFixed(2)}');
      }
      print('');
    }

    if (hasCapHits) {
      print('Cap Hits');
      final sorted = List<String>.from(report.capHits!)..sort();
      for (final id in sorted) {
        print(id);
      }
      print('');
    }

    if (hasHotspotMetrics) {
      final hm = report.hotspotMetrics!;
      print('Hotspot Metrics');
      print('totalFindings: ${hm.totalFindings}');
      print('concentration: ${hm.concentration.toStringAsFixed(4)}');
      print('top3Share: ${hm.top3Share.toStringAsFixed(4)}');
      if (hm.largestHotspot != null) {
        print(
            'largestHotspot: ${hm.largestHotspot!.path} (${hm.largestHotspot!.findings} findings)');
      }
      print('');
    }
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
    final forRule =
        report.uniqueFindings.where((f) => f.ruleId == ruleId).toList();
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
      final key = HotspotUtils.getSourceHotspotKey(f, report);
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
        if (HotspotUtils.getSourceHotspotKey(f, report) != primaryKey) continue;
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
          final tail =
              f.resolvedImportedPath!.length > f.targetFeaturePath!.length + 1
                  ? f.resolvedImportedPath!
                      .substring(f.targetFeaturePath!.length + 1)
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

  /// One-line cap-hit note (default output only). [capHits] must be non-empty; sorted alphabetically.
  static void _printCapHitNote(List<String> capHits) {
    final sorted = List<String>.from(capHits)..sort();
    final names = sorted.join(', ');
    if (sorted.length == 1) {
      print(
          'Note: $names reached its penalty cap (score may understate severity for this rule).');
    } else {
      print(
          'Note: $names reached their penalty caps (score may understate severity for these rules).');
    }
  }

  static void _printFindingsByCategory(
      ScanReport report, CategoryAggregation aggregation) {
    print('Findings by Category:');
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
        final forRule =
            report.uniqueFindings.where((f) => f.ruleId == r.ruleId).toList();
        final uniqueCount = forRule.length;
        final fileCount = forRule.map((f) => f.file).toSet().length;
        final label = ruleIdToDisplayLabel[r.ruleId] ?? r.ruleId;
        print('  - $label ($uniqueCount across $fileCount files)');
        final description = ruleIdToDescription[r.ruleId] ?? '';
        if (description.isNotEmpty) {
          print('  $description');
        }
        final suggestion = ruleIdToSuggestion[r.ruleId] ?? '';
        if (suggestion.isNotEmpty) {
          print('  Suggestion: $suggestion');
        }
      }
      print('');
    }
  }

  static void _printCITip() {
    print('---');
    print('');
    print('Tip:');
    print('Use ScaleGuard in CI to prevent architecture drift:');
    print('scale_guard scan . --fail-under 70');
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

  /// Source hotspot key; delegates to [HotspotUtils.getSourceHotspotKey].
  static String getSourceHotspotKey(Finding f, ScanReport report) =>
      HotspotUtils.getSourceHotspotKey(f, report);

  /// Target hotspot key from [Finding.resolvedImportedPath]. Returns null if none or external.
  static String? getTargetHotspotKey(Finding f) {
    final path = f.resolvedImportedPath;
    if (path == null || path.isEmpty) return null;
    final norm = _normPath(path);
    if (!norm.startsWith('lib/')) return null;
    return moduleRootKey(norm);
  }

  /// Per-path, per-rule finding counts. Used by Top Fix Priorities and Hotspots.
  static Map<String, Map<String, int>> _getRuleCountByPath(ScanReport report) {
    final ruleCountByKey = <String, Map<String, int>>{};
    for (final f in report.uniqueFindings) {
      final key = HotspotUtils.getSourceHotspotKey(f, report);
      ruleCountByKey[key] ??= {};
      ruleCountByKey[key]![f.ruleId] =
          (ruleCountByKey[key]![f.ruleId] ?? 0) + 1;
    }
    return ruleCountByKey;
  }

  /// Dominant rule for a path: rule with highest count; ties broken by rule id asc.
  static String? _dominantRuleForPath(Map<String, int> ruleCounts) {
    if (ruleCounts.isEmpty) return null;
    final entries = ruleCounts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    return entries.first.key;
  }

  /// First line or sentence of suggestion for use as short hint. Returns null if empty.
  static String? _shortHint(String suggestion) {
    final t = suggestion.trim();
    if (t.isEmpty) return null;
    final firstLine =
        t.contains('\n') ? t.substring(0, t.indexOf('\n')).trim() : t;
    final firstSentence = firstLine.contains('.')
        ? firstLine.substring(0, firstLine.indexOf('.') + 1).trim()
        : firstLine;
    return firstSentence.isEmpty ? null : firstSentence;
  }

  static void _printTopFixPriorities(ScanReport report) {
    final ordered = HotspotUtils.getOrderedHotspotEntries(report);
    if (ordered.isEmpty) return;
    final ruleCountByKey = _getRuleCountByPath(report);
    final topN = ordered.take(3).toList();
    print('Top Fix Priorities:');
    print('');
    for (var i = 0; i < topN.length; i++) {
      final e = topN[i];
      final ruleCounts = ruleCountByKey[e.path] ?? {};
      final dominant = _dominantRuleForPath(ruleCounts);
      print('${i + 1}. ${e.path}');
      print('   - ${e.count} findings');
      if (dominant != null) {
        print('   - dominant: $dominant');
        final suggestion = ruleIdToSuggestion[dominant] ?? '';
        final hint = _shortHint(suggestion);
        if (hint != null && hint.isNotEmpty) {
          print('   - $hint');
        }
      }
      print('');
    }
  }

  static void _printHotspots(ScanReport report) {
    print('Hotspots:');
    print('');
    final ordered = HotspotUtils.getOrderedHotspotEntries(report);
    if (ordered.isEmpty) return;
    final ruleCountByKey = _getRuleCountByPath(report);
    for (final e in ordered) {
      print('${e.path} (${e.count} findings)');
      final ruleCounts = ruleCountByKey[e.path] ?? {};
      final sorted = ruleCounts.entries.toList()
        ..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          if (byCount != 0) return byCount;
          return a.key.compareTo(b.key);
        });
      for (final r in sorted) {
        print('  - ${r.key}: ${r.value}');
      }
      print('');
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
