import '../model/risk_level.dart';
import '../model/rule_result.dart';

/// Low: 80-100, Medium: 55-79, High: 0-54.
const int _thresholdLow = 80;
const int _thresholdMedium = 55;

/// Computes final score and risk level from rule results.
/// penalty = min(cap, weight * riskValue) per rule; score = clamp(100 - sum(penalties), 0, 100).
class ScoringEngine {
  ScoringEngine._();

  static ({int score, RiskLevel riskLevel}) run(List<RuleResult> results) {
    double sum = 0;
    for (final r in results) {
      sum += r.penalty;
    }
    final score = (100 - sum).clamp(0, 100).round();
    final riskLevel = score >= _thresholdLow
        ? RiskLevel.low
        : score >= _thresholdMedium
            ? RiskLevel.medium
            : RiskLevel.high;
    return (score: score, riskLevel: riskLevel);
  }
}
