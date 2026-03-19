import 'dart:async';

import 'package:scale_guard/scale_guard.dart';
import 'package:scale_guard/src/core/rule_metadata.dart' as meta;
import 'package:test/test.dart';

/// Minimal mapping for tests (matches rule_metadata.ruleIdToCategory for used rules).
const _ruleIdToCategory = {
  'cross_feature_coupling': 'Coupling Risk',
  'layer_violations': 'Structural Risk',
};

List<String> _capturePrint(void Function() body) {
  final lines = <String>[];
  runZoned(body,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => lines.add(line),
      ));
  return lines;
}

void main() {
  group('ConsoleRenderer hotspot/example consistency', () {
    test('Hotspot (source) and Examples come from same feature when possible',
        () {
      // Top source: achievements (4 findings). Examples should be 3 from achievements.
      final findings = [
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/features/achievements/domain/a.dart',
          message: 'import habits',
          sourceFeaturePath: 'lib/features/achievements',
          targetFeaturePath: 'lib/features/habits',
          fromFeature: 'achievements',
          toFeature: 'habits',
          resolvedImportedPath: 'lib/features/habits/repo.dart',
        ),
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/features/achievements/domain/b.dart',
          message: 'import habits',
          sourceFeaturePath: 'lib/features/achievements',
          targetFeaturePath: 'lib/features/habits',
          fromFeature: 'achievements',
          toFeature: 'habits',
          resolvedImportedPath: 'lib/features/habits/repo.dart',
        ),
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/features/achievements/data/c.dart',
          message: 'import habits',
          sourceFeaturePath: 'lib/features/achievements',
          targetFeaturePath: 'lib/features/habits',
          fromFeature: 'achievements',
          toFeature: 'habits',
          resolvedImportedPath: 'lib/features/habits/repo.dart',
        ),
        Finding(
          severity: FindingSeverity.medium,
          ruleId: 'cross_feature_coupling',
          file: 'lib/features/habit_details/data/d.dart',
          message: 'import habits',
          sourceFeaturePath: 'lib/features/habit_details',
          targetFeaturePath: 'lib/features/habits',
          fromFeature: 'habit_details',
          toFeature: 'habits',
          resolvedImportedPath: 'lib/features/habits/repo.dart',
        ),
      ];
      final results = [
        RuleResult(
          ruleId: 'cross_feature_coupling',
          penalty: 10,
          findings: findings,
        ),
        RuleResult(
          ruleId: 'layer_violations',
          penalty: 1,
          findings: [],
        ),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        _ruleIdToCategory,
        uniqueFindings: findings,
      );
      final report = ScanReport(
        score: 80,
        riskLevel: RiskLevel.low,
        ruleResults: results,
        uniqueFindings: findings,
        timestamp: DateTime.now().toUtc(),
        aggregation: aggregation,
      );
      final lines = _capturePrint(() => ConsoleRenderer.render(report));

      expect(
        lines.any(
            (l) => l.startsWith('Hotspot (source): lib/features/achievements')),
        isTrue,
        reason: 'Top source should be achievements (4 findings)',
      );
      final examplesStart = lines.indexWhere((l) => l == 'Examples:');
      expect(examplesStart, greaterThanOrEqualTo(0));
      final exampleLines = lines
          .skip(examplesStart + 1)
          .take(5)
          .where((l) => l.trimLeft().startsWith('lib/'))
          .toList();
      expect(exampleLines, isNotEmpty);
      for (final line in exampleLines) {
        if (line.contains('(+') || line.startsWith('(Note:')) break;
        expect(
          line.contains('lib/features/achievements/'),
          isTrue,
          reason: 'Examples should be from printed hotspot (achievements)',
        );
      }
      expect(
        lines.any((l) => l.contains('hotspot/example mismatch detected')),
        isFalse,
        reason: 'No mismatch when all examples are from hotspot',
      );
    });

    test(
        'when top hotspot has only 2 findings and N=3, only 2 examples from that hotspot are shown',
        () {
      // Top source: achievements with 2 findings (2 files).
      // habit_details has 2 findings (2 files). We should show only the 2 achievements examples,
      // and none from habit_details, even though N=3.
      final findings = [
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/features/achievements/domain/a.dart',
          message: 'x',
          sourceFeaturePath: 'lib/features/achievements',
          targetFeaturePath: 'lib/features/habits',
          fromFeature: 'achievements',
          toFeature: 'habits',
          resolvedImportedPath: 'lib/features/habits/repo.dart',
        ),
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/features/achievements/domain/b.dart',
          message: 'x',
          sourceFeaturePath: 'lib/features/achievements',
          targetFeaturePath: 'lib/features/habits',
          fromFeature: 'achievements',
          toFeature: 'habits',
          resolvedImportedPath: 'lib/features/habits/repo.dart',
        ),
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/features/habit_details/data/c.dart',
          message: 'x',
          sourceFeaturePath: 'lib/features/habit_details',
          targetFeaturePath: 'lib/features/habits',
          fromFeature: 'habit_details',
          toFeature: 'habits',
          resolvedImportedPath: 'lib/features/habits/repo.dart',
        ),
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/features/habit_details/data/d.dart',
          message: 'x',
          sourceFeaturePath: 'lib/features/habit_details',
          targetFeaturePath: 'lib/features/habits',
          fromFeature: 'habit_details',
          toFeature: 'habits',
          resolvedImportedPath: 'lib/features/habits/repo.dart',
        ),
      ];
      final results = [
        RuleResult(
          ruleId: 'cross_feature_coupling',
          penalty: 10,
          findings: findings,
        ),
        RuleResult(ruleId: 'layer_violations', penalty: 1, findings: []),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        _ruleIdToCategory,
        uniqueFindings: findings,
      );
      final report = ScanReport(
        score: 80,
        riskLevel: RiskLevel.low,
        ruleResults: results,
        uniqueFindings: findings,
        timestamp: DateTime.now().toUtc(),
        aggregation: aggregation,
      );
      final lines = _capturePrint(() => ConsoleRenderer.render(report));

      expect(
        lines.any(
            (l) => l.startsWith('Hotspot (source): lib/features/achievements')),
        isTrue,
      );
      final examplesStart = lines.indexWhere((l) => l == 'Examples:');
      expect(examplesStart, greaterThanOrEqualTo(0));
      final exampleLines = lines
          .skip(examplesStart + 1)
          .take(5)
          .where((l) => l.trimLeft().startsWith('lib/'))
          .toList();
      // Only the two achievements findings should be used as examples.
      expect(exampleLines.length, 2);
      for (final line in exampleLines) {
        if (line.contains('(+')) break;
        expect(
          line.contains('lib/features/achievements/'),
          isTrue,
        );
      }
      expect(
        lines.any((l) => l.contains('hotspot/example mismatch detected')),
        isFalse,
        reason: 'Mismatch note is no longer used',
      );
    });
  });

  group('Summary intensity (soft vs standard)', () {
    test('score 97 with small penalty uses soft summary', () {
      final results = [
        RuleResult(
          ruleId: 'cross_feature_coupling',
          penalty: 5,
          findings: [
            Finding(
              severity: FindingSeverity.medium,
              ruleId: 'cross_feature_coupling',
              file: 'lib/a.dart',
              message: 'x',
            ),
          ],
        ),
        RuleResult(ruleId: 'layer_violations', penalty: 0, findings: []),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        _ruleIdToCategory,
      );
      final report = ScanReport(
        score: 97,
        riskLevel: RiskLevel.low,
        ruleResults: results,
        uniqueFindings: results.expand((r) => r.findings).toList(),
        timestamp: DateTime.now().toUtc(),
        aggregation: aggregation,
      );
      final lines = _capturePrint(() => ConsoleRenderer.render(report));
      final fullOutput = lines.join('\n');
      expect(fullOutput,
          contains(meta.categoryToSummarySoft[meta.categoryCouplingRisk]));
      expect(fullOutput,
          isNot(contains(meta.categoryToSummary[meta.categoryCouplingRisk])));
      final dominantLine =
          lines.where((l) => l.startsWith('Dominant Risk Category:')).single;
      expect(dominantLine, contains(', low intensity)'));
    });

    test('score 70 with larger penalty uses standard summary', () {
      final results = [
        RuleResult(
          ruleId: 'cross_feature_coupling',
          penalty: 20,
          findings: [
            Finding(
              severity: FindingSeverity.high,
              ruleId: 'cross_feature_coupling',
              file: 'lib/a.dart',
              message: 'x',
            ),
          ],
        ),
        RuleResult(ruleId: 'layer_violations', penalty: 0, findings: []),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        _ruleIdToCategory,
      );
      final report = ScanReport(
        score: 70,
        riskLevel: RiskLevel.medium,
        ruleResults: results,
        uniqueFindings: results.expand((r) => r.findings).toList(),
        timestamp: DateTime.now().toUtc(),
        aggregation: aggregation,
      );
      final lines = _capturePrint(() => ConsoleRenderer.render(report));
      final fullOutput = lines.join('\n');
      expect(fullOutput,
          contains(meta.categoryToSummary[meta.categoryCouplingRisk]));
      expect(
          fullOutput,
          isNot(
              contains(meta.categoryToSummarySoft[meta.categoryCouplingRisk])));
      final dominantLine =
          lines.where((l) => l.startsWith('Dominant Risk Category:')).single;
      expect(dominantLine, isNot(contains('low intensity')));
    });
  });

  group('Top Hotspots module-level (lib/feature/<name>)', () {
    test('reports module-level hotspots not coarse lib/feature', () {
      // Fixture: findings under lib/feature/add_card, lib/feature/buy_gift_card, lib/feature/card_management.
      final findings = [
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/feature/add_card/domain/use_case.dart',
          message: 'x',
          resolvedImportedPath: 'lib/feature/buy_gift_card/repo.dart',
        ),
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/feature/buy_gift_card/data/repo.dart',
          message: 'x',
          resolvedImportedPath: 'lib/feature/add_card/domain/entity.dart',
        ),
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'cross_feature_coupling',
          file: 'lib/feature/card_management/ui/page.dart',
          message: 'x',
          resolvedImportedPath: 'lib/feature/add_card/domain/entity.dart',
        ),
      ];
      final moduleIndex = {
        'lib/feature/add_card/domain/use_case.dart': 'lib/feature/add_card',
        'lib/feature/buy_gift_card/data/repo.dart': 'lib/feature/buy_gift_card',
        'lib/feature/card_management/ui/page.dart':
            'lib/feature/card_management',
      };
      final results = [
        RuleResult(
          ruleId: 'cross_feature_coupling',
          penalty: 10,
          findings: findings,
        ),
        RuleResult(ruleId: 'layer_violations', penalty: 0, findings: []),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        _ruleIdToCategory,
        uniqueFindings: findings,
      );
      final report = ScanReport(
        score: 70,
        riskLevel: RiskLevel.medium,
        ruleResults: results,
        uniqueFindings: findings,
        timestamp: DateTime.now().toUtc(),
        aggregation: aggregation,
        moduleIndex: moduleIndex,
      );
      final lines = _capturePrint(() => ConsoleRenderer.render(report));

      final hotspotsStart = lines.indexWhere((l) => l == 'Hotspots:');
      expect(hotspotsStart, greaterThanOrEqualTo(0));
      final hotspotsBlock =
          lines.skip(hotspotsStart + 2).takeWhile((l) => l != '---').toList();

      // Must show module-level roots, not a single coarse lib/feature.
      expect(
        hotspotsBlock.any((l) => l.startsWith('lib/feature/add_card (')),
        isTrue,
      );
      expect(
        hotspotsBlock.any((l) => l.startsWith('lib/feature/buy_gift_card (')),
        isTrue,
      );
      expect(
        hotspotsBlock.any((l) => l.startsWith('lib/feature/card_management (')),
        isTrue,
      );
      // Must NOT collapse to a single "lib/feature (" line.
      final coarseLine = hotspotsBlock.where((l) =>
          l.startsWith('lib/feature (') && !l.startsWith('lib/feature/'));
      expect(coarseLine.length, 0,
          reason: 'Hotspots must be module-level, not coarse lib/feature');
    });
  });

  group('Most Expensive Risk examples for layer_violations', () {
    test('examples are from main_flow and no target hotspot is printed', () {
      final findings = [
        Finding(
          severity: FindingSeverity.high,
          ruleId: 'layer_violations',
          file: 'lib/feature/main_flow/presentation/page_a.dart',
          message: 'layer violation A',
        ),
        Finding(
          severity: FindingSeverity.medium,
          ruleId: 'layer_violations',
          file: 'lib/feature/main_flow/domain/use_case_b.dart',
          message: 'layer violation B',
        ),
        Finding(
          severity: FindingSeverity.medium,
          ruleId: 'layer_violations',
          file: 'lib/feature/main_flow/data/repo_d.dart',
          message: 'layer violation D',
        ),
        Finding(
          severity: FindingSeverity.medium,
          ruleId: 'layer_violations',
          file: 'lib/feature/secondary_flow/presentation/page_c.dart',
          message: 'layer violation C',
        ),
      ];
      final moduleIndex = {
        'lib/feature/main_flow/presentation/page_a.dart':
            'lib/feature/main_flow',
        'lib/feature/main_flow/domain/use_case_b.dart': 'lib/feature/main_flow',
        'lib/feature/main_flow/data/repo_d.dart': 'lib/feature/main_flow',
        'lib/feature/secondary_flow/presentation/page_c.dart':
            'lib/feature/secondary_flow',
      };
      final results = [
        RuleResult(
          ruleId: 'layer_violations',
          penalty: 10,
          findings: findings,
        ),
        RuleResult(
          ruleId: 'cross_feature_coupling',
          penalty: 5,
          findings: [],
        ),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        _ruleIdToCategory,
        uniqueFindings: findings,
      );
      final report = ScanReport(
        score: 70,
        riskLevel: RiskLevel.medium,
        ruleResults: results,
        uniqueFindings: findings,
        timestamp: DateTime.now().toUtc(),
        aggregation: aggregation,
        moduleIndex: moduleIndex,
      );
      final lines = _capturePrint(() => ConsoleRenderer.render(report));

      // Most Expensive Risk is layer_violations, hotspot should be main_flow.
      expect(
        lines.any((l) => l.startsWith('Most Expensive Risk:')),
        isTrue,
      );
      expect(
        lines.any(
            (l) => l.startsWith('Hotspot (source): lib/feature/main_flow')),
        isTrue,
      );
      // No target hotspot printed for layer_violations.
      expect(
        lines.any((l) => l.startsWith('Hotspot (target):')),
        isFalse,
      );

      final examplesStart = lines.indexWhere((l) => l == 'Examples:');
      expect(examplesStart, greaterThanOrEqualTo(0));
      final exampleLines = lines
          .skip(examplesStart + 1)
          .take(5)
          .where((l) => l.trimLeft().startsWith('lib/'))
          .toList();
      expect(exampleLines, isNotEmpty);
      for (final line in exampleLines) {
        if (line.contains('(+')) break;
        expect(
          line.contains('lib/feature/main_flow/'),
          isTrue,
          reason: 'All examples should be from main_flow hotspot',
        );
      }
    });
  });

  group('Penalty by Category', () {
    test('default output does not contain Penalty by Category or Debug Details',
        () {
      final results = [
        RuleResult(ruleId: 'cross_feature_coupling', penalty: 10, findings: []),
        RuleResult(ruleId: 'layer_violations', penalty: 1, findings: []),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        _ruleIdToCategory,
      );
      final report = ScanReport(
        score: 89,
        riskLevel: RiskLevel.low,
        ruleResults: results,
        uniqueFindings: [],
        timestamp: DateTime.utc(2025, 1, 1),
        aggregation: aggregation,
      );
      final lines = _capturePrint(() => ConsoleRenderer.render(report));
      expect(lines.any((l) => l == 'Penalty by Category'), isFalse);
      expect(lines.any((l) => l == 'Debug Details'), isFalse);
      expect(lines.any((l) => l == 'Penalty by Rule'), isFalse);
      expect(lines.any((l) => l == 'Cap Hits'), isFalse);
      expect(lines.any((l) => l == 'Hotspot Metrics'), isFalse);
    });

    test(
        'with showDebug prints penalty block under Debug Details with two decimals and deterministic order when totalPenalty > 0',
        () {
      final results = [
        RuleResult(ruleId: 'cross_feature_coupling', penalty: 10, findings: []),
        RuleResult(ruleId: 'layer_violations', penalty: 1, findings: []),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        _ruleIdToCategory,
      );
      final report = ScanReport(
        score: 89,
        riskLevel: RiskLevel.low,
        ruleResults: results,
        uniqueFindings: [],
        timestamp: DateTime.utc(2025, 1, 1),
        aggregation: aggregation,
      );
      final lines = _capturePrint(() =>
          ConsoleRenderer.render(report, showStats: false, showDebug: true));
      expect(lines.any((l) => l == 'Debug Details'), isTrue);
      expect(lines.any((l) => l == 'Penalty by Category'), isTrue);
      expect(lines.any((l) => l == 'Coupling Risk: -10.00'), isTrue);
      expect(lines.any((l) => l == 'Structural Risk: -1.00'), isTrue);
      expect(lines.any((l) => l == 'Maintainability Risk: -0.00'), isTrue);
      expect(
          lines.any((l) => l == 'Configuration / Release Risk: -0.00'), isTrue);
      expect(lines.any((l) => l == 'Total Penalty: -11.00'), isTrue);
      final debugStart = lines.indexWhere((l) => l == 'Debug Details');
      final blockStart = lines.indexWhere((l) => l == 'Penalty by Category');
      expect(blockStart, greaterThan(debugStart),
          reason: 'Penalty by Category must appear after Debug Details');
      final categoryLines = lines
          .skip(blockStart + 1)
          .take(4)
          .where((l) => l.contains(': -'))
          .toList();
      expect(categoryLines.length, 4);
      expect(categoryLines[0], 'Coupling Risk: -10.00');
      expect(categoryLines[1], 'Structural Risk: -1.00');
      expect(categoryLines[2], 'Configuration / Release Risk: -0.00');
      expect(categoryLines[3], 'Maintainability Risk: -0.00');
    });

    test('does not print penalty block when totalPenalty == 0', () {
      final results = [
        RuleResult(ruleId: 'layer_violations', penalty: 0, findings: []),
        RuleResult(ruleId: 'cross_feature_coupling', penalty: 0, findings: []),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        _ruleIdToCategory,
      );
      final report = ScanReport(
        score: 100,
        riskLevel: RiskLevel.low,
        ruleResults: results,
        uniqueFindings: [],
        timestamp: DateTime.utc(2025, 1, 1),
        aggregation: aggregation,
      );
      final lines = _capturePrint(() => ConsoleRenderer.render(report));
      expect(lines.any((l) => l == 'Penalty by Category'), isFalse);
    });
  });

  group('Cap-hit note (default output)', () {
    test('with capHits shows single-line Note after Most Expensive Risk block',
        () {
      final results = [
        RuleResult(ruleId: 'cross_feature_coupling', penalty: 10, findings: []),
        RuleResult(ruleId: 'layer_violations', penalty: 0, findings: []),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        _ruleIdToCategory,
      );
      final report = ScanReport(
        score: 89,
        riskLevel: RiskLevel.low,
        ruleResults: results,
        uniqueFindings: [],
        timestamp: DateTime.utc(2025, 1, 1),
        aggregation: aggregation,
        capHits: ['cross_feature_coupling'],
      );
      final lines = _capturePrint(() => ConsoleRenderer.render(report));
      expect(
        lines.any((l) =>
            l.contains('Note:') &&
            l.contains('cross_feature_coupling') &&
            l.contains('reached its penalty cap') &&
            l.contains('this rule')),
        isTrue,
        reason: 'Must show singular cap-hit note',
      );
      expect(lines.any((l) => l.contains('these rules')), isFalse);
    });

    test(
        'with multiple capHits shows plural Note, rule IDs sorted alphabetically',
        () {
      final results = [
        RuleResult(ruleId: 'layer_violations', penalty: 10, findings: []),
        RuleResult(ruleId: 'cross_feature_coupling', penalty: 10, findings: []),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        _ruleIdToCategory,
      );
      final report = ScanReport(
        score: 80,
        riskLevel: RiskLevel.medium,
        ruleResults: results,
        uniqueFindings: [],
        timestamp: DateTime.utc(2025, 1, 1),
        aggregation: aggregation,
        capHits: ['layer_violations', 'cross_feature_coupling'],
      );
      final lines = _capturePrint(() => ConsoleRenderer.render(report));
      expect(
        lines.any((l) =>
            l.contains('Note:') &&
            l.contains('reached their penalty caps') &&
            l.contains('these rules')),
        isTrue,
      );
      final noteLine = lines.where((l) => l.startsWith('Note:')).single;
      expect(noteLine, contains('cross_feature_coupling'));
      expect(noteLine, contains('layer_violations'));
      expect(noteLine.indexOf('cross_feature_coupling'),
          lessThan(noteLine.indexOf('layer_violations')),
          reason: 'Rule IDs must be alphabetically ordered');
    });

    test('without capHits does not show cap-hit Note', () {
      final results = [
        RuleResult(ruleId: 'cross_feature_coupling', penalty: 5, findings: []),
        RuleResult(ruleId: 'layer_violations', penalty: 0, findings: []),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        _ruleIdToCategory,
      );
      final report = ScanReport(
        score: 95,
        riskLevel: RiskLevel.low,
        ruleResults: results,
        uniqueFindings: [],
        timestamp: DateTime.utc(2025, 1, 1),
        projectPath: 'project',
        aggregation: aggregation,
      );
      final lines = _capturePrint(() => ConsoleRenderer.render(report));
      expect(
        lines.any((l) => l.startsWith('Note:') && l.contains('penalty cap')),
        isFalse,
      );
    });

    test('with showDebug does not show cap-hit Note in default section', () {
      final results = [
        RuleResult(ruleId: 'cross_feature_coupling', penalty: 10, findings: []),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        _ruleIdToCategory,
      );
      final report = ScanReport(
        score: 89,
        riskLevel: RiskLevel.low,
        ruleResults: results,
        uniqueFindings: [],
        timestamp: DateTime.utc(2025, 1, 1),
        aggregation: aggregation,
        capHits: ['cross_feature_coupling'],
      );
      final lines = _capturePrint(() =>
          ConsoleRenderer.render(report, showStats: false, showDebug: true));
      expect(
        lines.any((l) => l.startsWith('Note:') && l.contains('penalty cap')),
        isFalse,
        reason: 'Cap-hit note is default-only, not in --debug',
      );
    });
  });

  group('Console output flags', () {
    test('header shows projectDisplayName and scanPath when set, in order', () {
      final report = ScanReport(
        score: 80,
        riskLevel: RiskLevel.low,
        ruleResults: [],
        uniqueFindings: [],
        timestamp: DateTime.utc(2025, 1, 1),
        projectPath: '/path/to/project',
        projectDisplayName: 'my_project',
        scanPath: '/resolved/abs/path/my_project',
      );
      final lines = _capturePrint(() => ConsoleRenderer.render(report));
      final projectIdx = lines.indexWhere((l) => l.startsWith('Project:'));
      final scanPathIdx = lines.indexWhere((l) => l.startsWith('Scan Path:'));
      expect(projectIdx, greaterThanOrEqualTo(0));
      expect(scanPathIdx, greaterThanOrEqualTo(0));
      expect(scanPathIdx, equals(projectIdx + 1),
          reason: 'Scan Path must follow Project');
      expect(lines[projectIdx], equals('Project: my_project'));
      expect(lines[scanPathIdx],
          equals('Scan Path: /resolved/abs/path/my_project'));
    });

    test(
        'default output snapshot: required sections present in order, no debug blocks',
        () {
      final results = [
        RuleResult(ruleId: 'cross_feature_coupling', penalty: 5, findings: []),
        RuleResult(ruleId: 'layer_violations', penalty: 0, findings: []),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        _ruleIdToCategory,
      );
      final report = ScanReport(
        score: 95,
        riskLevel: RiskLevel.low,
        ruleResults: results,
        uniqueFindings: [],
        timestamp: DateTime.utc(2025, 1, 1),
        projectPath: 'project',
        aggregation: aggregation,
      );
      final lines = _capturePrint(() => ConsoleRenderer.render(report));
      final full = lines.join('\n');
      expect(full, contains('Flutter ScaleGuard'));
      expect(full, contains('Project: project'));
      expect(full, contains('Scan Path: project'));
      expect(full, contains('Architecture Score: 95/100'));
      expect(full, contains('Findings by Category:'));
      expect(full, contains('Tip:'));
      expect(
          full, contains('Use ScaleGuard in CI to prevent architecture drift'));
      expect(full, isNot(contains('Debug Details')));
      expect(full, isNot(contains('Penalty by Category')));
      expect(full, isNot(contains('Scan Stats')));
      expect(full, isNot(contains('reached its penalty cap')),
          reason: 'No cap-hit note when capHits empty/absent');
      // With no findings, Top Fix Priorities and Hotspots are omitted; order: Findings by Category then CI Tip.
      final findingsIdx = lines.indexOf('Findings by Category:');
      final tipIdx = lines.indexOf('Tip:');
      expect(findingsIdx, greaterThanOrEqualTo(0));
      expect(tipIdx, greaterThan(findingsIdx));
      expect(lines.where((l) => l == '---').length, greaterThanOrEqualTo(2),
          reason: 'Section separators must be exactly ---');
    });

    test('--stats only: includes Scan Stats, no Debug Details', () {
      final results = [
        RuleResult(ruleId: 'layer_violations', penalty: 1, findings: []),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        _ruleIdToCategory,
      );
      final report = ScanReport(
        score: 99,
        riskLevel: RiskLevel.low,
        ruleResults: results,
        uniqueFindings: [],
        timestamp: DateTime.utc(2025, 1, 1),
        aggregation: aggregation,
        meta: ScanMeta(
          schemaVersion: '1.0',
          scannedFiles: 10,
          ignoredFiles: 2,
          importsTotal: 50,
          importsResolvedToProject: 40,
          importsExternalPackage: 8,
          importsUnresolved: 2,
        ),
      );
      final lines = _capturePrint(() =>
          ConsoleRenderer.render(report, showStats: true, showDebug: false));
      expect(lines.any((l) => l == 'Scan Stats'), isTrue);
      expect(lines.any((l) => l.startsWith('Files scanned:')), isTrue);
      expect(lines.any((l) => l.contains('Imports:')), isTrue);
      expect(lines.any((l) => l == 'Debug Details'), isFalse);
    });

    test(
        '--debug only: includes Debug Details with Penalty by Rule when present',
        () {
      final results = [
        RuleResult(ruleId: 'cross_feature_coupling', penalty: 10, findings: []),
        RuleResult(ruleId: 'layer_violations', penalty: 1, findings: []),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        _ruleIdToCategory,
      );
      final report = ScanReport(
        score: 89,
        riskLevel: RiskLevel.low,
        ruleResults: results,
        uniqueFindings: [],
        timestamp: DateTime.utc(2025, 1, 1),
        aggregation: aggregation,
        capHits: [],
        hotspotMetrics: const HotspotMetrics(
          totalFindings: 0,
          concentration: 0.0,
          top3Share: 0.0,
        ),
      );
      final lines = _capturePrint(() =>
          ConsoleRenderer.render(report, showStats: false, showDebug: true));
      expect(lines.any((l) => l == 'Debug Details'), isTrue);
      expect(lines.any((l) => l == 'Penalty by Category'), isTrue);
      expect(lines.any((l) => l == 'Penalty by Rule'), isTrue);
    });

    test('--stats --debug: Scan Stats then Debug Details in order', () {
      final results = [
        RuleResult(ruleId: 'layer_violations', penalty: 1, findings: []),
      ];
      final aggregation = CategoryAggregation.fromRuleResults(
        results,
        _ruleIdToCategory,
      );
      final report = ScanReport(
        score: 99,
        riskLevel: RiskLevel.low,
        ruleResults: results,
        uniqueFindings: [],
        timestamp: DateTime.utc(2025, 1, 1),
        aggregation: aggregation,
        meta: ScanMeta(
          schemaVersion: '1.0',
          scannedFiles: 5,
          ignoredFiles: 0,
          importsTotal: 20,
          importsResolvedToProject: 18,
          importsExternalPackage: 1,
          importsUnresolved: 1,
        ),
        hotspotMetrics: const HotspotMetrics(
          totalFindings: 0,
          concentration: 0.0,
          top3Share: 0.0,
        ),
      );
      final lines = _capturePrint(() =>
          ConsoleRenderer.render(report, showStats: true, showDebug: true));
      final scanStatsIdx = lines.indexWhere((l) => l == 'Scan Stats');
      final debugDetailsIdx = lines.indexWhere((l) => l == 'Debug Details');
      expect(scanStatsIdx, greaterThanOrEqualTo(0));
      expect(debugDetailsIdx, greaterThanOrEqualTo(0));
      expect(debugDetailsIdx, greaterThan(scanStatsIdx),
          reason: 'Debug Details must come after Scan Stats');
    });
  });
}
