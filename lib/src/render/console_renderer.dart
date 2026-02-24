import '../model/finding.dart';
import '../model/risk_level.dart';
import '../model/scan_report.dart';
import '../model/severity.dart';

class ConsoleRenderer {
  ConsoleRenderer._();

  static void render(ScanReport report) {
    print('Architecture Score: ${report.score}/100');
    print('Risk Level: ${_riskLevelLabel(report.riskLevel)}');
    print('');
    final findings = report.findings;
    if (findings.isEmpty) {
      print('No findings.');
    } else {
      final high = findings.where((f) => f.severity == FindingSeverity.high).toList();
      final medium = findings.where((f) => f.severity == FindingSeverity.medium).toList();
      if (high.isNotEmpty) {
        print('--- High ---');
        for (final f in high) {
          _printFinding(f);
        }
        print('');
      }
      if (medium.isNotEmpty) {
        print('--- Medium ---');
        for (final f in medium) {
          _printFinding(f);
        }
        print('');
      }
    }
    _printSuggestedActions(report);
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
    print('  [${f.ruleId}] ${f.file}$loc');
    print('    ${f.message}');
  }

  static void _printSuggestedActions(ScanReport report) {
    print('Suggested next actions:');
    final ruleIds = report.ruleResults.where((r) => r.findings.isNotEmpty).map((r) => r.ruleId).toSet().toList()..sort();
    if (ruleIds.isEmpty) {
      print('  None.');
      return;
    }
    for (final id in ruleIds) {
      print('  - Address $id findings (see above).');
    }
  }
}
