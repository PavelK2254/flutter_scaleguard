/// A deterministic, rule-based fix priority for console explainability.
class FixPriority {
  const FixPriority({
    required this.actionTitle,
    required this.ruleId,
    required this.area,
    required this.impact,
    required this.estimatedScoreGain,
    required this.why,
    required this.isCapped,
  });

  final String actionTitle;
  final String ruleId;
  final String area;
  final String impact;
  final int estimatedScoreGain;
  final String why;
  final bool isCapped;
}
