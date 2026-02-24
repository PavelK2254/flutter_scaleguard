import '../core/config.dart';
import '../core/index.dart';
import '../model/finding.dart';
import '../model/rule_result.dart';
import '../model/severity.dart';
import 'rule.dart';

/// Detects direct route string usage (bypassing centralized navigation).
class NavigationCouplingRule implements Rule {
  @override
  String get id => 'navigation_coupling';

  @override
  double get weight => 0.05;

  @override
  double get cap => 5;

  static final _pushNamedRegex = RegExp(r'''pushNamed\s*\(\s*[^,]+,\s*['"]([^'"]+)['"]''');

  @override
  RuleResult run(ProjectIndex index, ScannerConfig config) {
    final findings = <Finding>[];
    for (final file in index.files) {
      if (file.lines.isEmpty) continue;
      for (var i = 0; i < file.lines.length; i++) {
        final line = file.lines[i];
        if (line.trim().startsWith('//')) continue;
        final pushMatch = _pushNamedRegex.firstMatch(line);
        if (pushMatch != null) {
          final route = pushMatch.group(1)!;
          if (!_isAllowedConstant(line, route, config)) {
            findings.add(Finding(
              severity: FindingSeverity.medium,
              ruleId: id,
              file: file.path,
              line: i + 1,
              message: 'Direct route string: $route',
            ));
          }
        }
      }
    }
    final riskValue = findings.length.toDouble();
    final penalty = (riskValue * weight).clamp(0.0, cap);
    return RuleResult(ruleId: id, penalty: penalty, findings: findings, riskValue: riskValue);
  }

  bool _isAllowedConstant(String line, String route, ScannerConfig config) {
    for (final prefix in config.routeConstantPrefixes) {
      if (line.contains(prefix)) return true;
    }
    return false;
  }
}
