import '../core/rule_metadata.dart';
import '../model/category_aggregation.dart';
import '../model/finding.dart';
import '../model/risk_level.dart';
import '../model/scan_report.dart';
import '../model/severity.dart';
import '../version.dart';

class ConsoleRenderer {
  ConsoleRenderer._();

  /// Renders [report] to the console. [version] should come from [getPackageVersion]
  /// so the banner matches pubspec; if null, uses [fallbackPackageVersion].
  static void render(ScanReport report, {String? version}) {
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
      final summary = categoryToSummary[agg.dominantCategory] ??
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
      print(
          'Dominant Risk Category: ${agg.dominantCategory} ($pct% of total penalty)');
      final displayName = ruleIdToDisplayLabel[agg.mostExpensiveRuleId] ??
          agg.mostExpensiveRuleId;
      print('Most Expensive Risk: $displayName (-${agg.mostExpensivePenalty})');
      print('');
      print('---');
      print('');
      _printFindingsByCategory(report, agg);
      print('---');
      print('');
      _printTopHotspots(report);
      print('---');
      print('');
      final why = categoryToWhyItMatters[agg.dominantCategory] ?? '';
      print('Why This Matters');
      print(why);
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
    }
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
        final label = ruleIdToDisplayLabel[r.ruleId] ?? r.ruleId;
        print('  - $label (${r.findings.length})');
      }
      print('');
    }
  }

  static void _printTopHotspots(ScanReport report) {
    print('Top Hotspots');
    print('');
    final findings = report.findings;
    if (findings.isEmpty) {
      return;
    }
    final countByKey = <String, int>{};
    for (final f in findings) {
      final segments = f.file.split('/');
      final key = segments.length >= 2
          ? '${segments[0]}/${segments[1]}'
          : (segments.isNotEmpty ? segments[0] : 'lib');
      countByKey[key] = (countByKey[key] ?? 0) + 1;
    }
    final entries = countByKey.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    final top3 = entries.take(3).toList();
    for (var i = 0; i < top3.length; i++) {
      print('${i + 1}. ${top3[i].key} (${top3[i].value} findings)');
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
