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

    test('ScanReport findings are sorted by severity then file then line', () {
      final high = Finding(severity: FindingSeverity.high, ruleId: 'r', file: 'a.dart', message: 'm');
      final medium = Finding(severity: FindingSeverity.medium, ruleId: 'r', file: 'b.dart', message: 'm');
      final report = ScanReport(
        score: 80,
        riskLevel: RiskLevel.low,
        ruleResults: [
          RuleResult(ruleId: 'r', penalty: 0, findings: [medium, high]),
        ],
        timestamp: DateTime.now().toUtc(),
      );
      final list = report.findings;
      expect(list.length, 2);
      expect(list.first.severity, FindingSeverity.high);
      expect(list.last.severity, FindingSeverity.medium);
    });
  });
}
