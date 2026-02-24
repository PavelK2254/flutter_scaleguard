import 'finding.dart';

class RuleResult {
  const RuleResult({
    required this.ruleId,
    required this.penalty,
    required this.findings,
    this.riskValue,
  });

  final String ruleId;
  final double penalty;
  final List<Finding> findings;
  final double? riskValue;
}
