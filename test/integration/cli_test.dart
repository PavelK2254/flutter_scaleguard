import 'dart:io';

import 'package:scale_guard/scale_guard.dart';
import 'package:test/test.dart';

void main() {
  group('CLI integration', () {
    test('runScan on empty or minimal project returns report', () async {
      final dir = Directory.current;
      final report = await runScan(dir.path);
      expect(report.score, inInclusiveRange(0, 100));
      expect(report.riskLevel, isNotNull);
      expect(report.ruleResults, isNotEmpty);
      expect(report.timestamp, isNotNull);
    });

    test('runScan returns report with meta (schema and counts)', () async {
      final dir = Directory.current;
      final report = await runScan(dir.path);
      expect(report.meta, isNotNull);
      expect(report.meta!.schemaVersion, '1.0');
      expect(report.meta!.scannedFiles, greaterThanOrEqualTo(0));
      expect(report.meta!.ignoredFiles, greaterThanOrEqualTo(0));
      expect(report.meta!.importsTotal, greaterThanOrEqualTo(0));
      expect(report.meta!.importsResolvedToProject, greaterThanOrEqualTo(0));
      expect(report.meta!.importsExternalPackage, greaterThanOrEqualTo(0));
      expect(report.meta!.importsUnresolved, greaterThanOrEqualTo(0));
    });

    test('meta is stable across two runs', () async {
      final dir = Directory.current;
      final report1 = await runScan(dir.path);
      final report2 = await runScan(dir.path);
      expect(report1.meta, isNotNull);
      expect(report2.meta, isNotNull);
      expect(report1.meta, equals(report2.meta));
    });

    test('JSON output includes meta when report has meta', () async {
      final report = await runScan(Directory.current.path);
      expect(report.meta, isNotNull);
      final json = JsonRenderer.render(report);
      expect(json, contains('"meta"'));
      expect(json, contains('"scannedFiles"'));
      expect(json, contains('"ignoredFiles"'));
      expect(json, contains('"imports"'));
      expect(json, contains('"resolvedToProject"'));
    });

    test('CLI with --stats prints Scan Stats section', () async {
      final dir = Directory.current.path;
      final result = await Process.run(
        'dart',
        ['run', 'bin/scale_guard.dart', 'scan', dir, '--stats'],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );
      expect(result.stderr, isEmpty);
      expect(result.stdout, contains('Scan Stats'));
      expect(result.stdout, contains('Files scanned:'));
      expect(result.stdout, contains('Imports:'));
    });

    test('ScanReport findings are sorted by severity then file then line', () {
      final high = Finding(
          severity: FindingSeverity.high,
          ruleId: 'r',
          file: 'a.dart',
          message: 'm');
      final medium = Finding(
          severity: FindingSeverity.medium,
          ruleId: 'r',
          file: 'b.dart',
          message: 'm');
      final report = ScanReport(
        score: 80,
        riskLevel: RiskLevel.low,
        ruleResults: [
          RuleResult(ruleId: 'r', penalty: 0, findings: [medium, high]),
        ],
        uniqueFindings: [high, medium],
        timestamp: DateTime.now().toUtc(),
      );
      final list = report.findings;
      expect(list.length, 2);
      expect(list.first.severity, FindingSeverity.high);
      expect(list.last.severity, FindingSeverity.medium);
    });
  });
}
