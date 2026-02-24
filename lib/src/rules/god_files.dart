import '../core/config.dart';
import '../core/index.dart';
import '../model/finding.dart';
import '../model/rule_result.dart';
import '../model/severity.dart';
import 'rule.dart';

/// Detects large files (LOC > medium = Medium finding, > high = High finding).
class GodFilesRule implements Rule {
  @override
  String get id => 'god_files';

  @override
  double get weight => 0.15;

  @override
  double get cap => 12;

  @override
  RuleResult run(ProjectIndex index, ScannerConfig config) {
    final findings = <Finding>[];
    double riskValue = 0;
    for (final file in index.files) {
      if (file.lineCount >= config.godFileHighLoc) {
        findings.add(Finding(
          severity: FindingSeverity.high,
          ruleId: id,
          file: file.path,
          message: 'God file: ${file.lineCount} LOC (threshold ${config.godFileHighLoc})',
        ));
        riskValue += 2;
      } else if (file.lineCount >= config.godFileMediumLoc) {
        findings.add(Finding(
          severity: FindingSeverity.medium,
          ruleId: id,
          file: file.path,
          message: 'Large file: ${file.lineCount} LOC (threshold ${config.godFileMediumLoc})',
        ));
        riskValue += 1;
      }
    }
    final penalty = (riskValue * weight).clamp(0.0, cap);
    return RuleResult(ruleId: id, penalty: penalty, findings: findings, riskValue: riskValue);
  }
}
