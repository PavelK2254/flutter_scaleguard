import 'package:flutter_arch_risk/flutter_arch_risk.dart';
import 'package:test/test.dart';

void main() {
  group('ScoringEngine', () {
    test('no penalties gives score 100, low risk', () {
      final results = [
        RuleResult(ruleId: 'a', penalty: 0, findings: []),
        RuleResult(ruleId: 'b', penalty: 0, findings: []),
      ];
      final r = ScoringEngine.run(results);
      expect(r.score, 100);
      expect(r.riskLevel, RiskLevel.low);
    });

    test('small penalty gives high score, low risk', () {
      final results = [
        RuleResult(ruleId: 'a', penalty: 5, findings: []),
        RuleResult(ruleId: 'b', penalty: 10, findings: []),
      ];
      final r = ScoringEngine.run(results);
      expect(r.score, 85);
      expect(r.riskLevel, RiskLevel.low);
    });

    test('score 80 is low risk', () {
      final results = [RuleResult(ruleId: 'a', penalty: 20, findings: [])];
      final r = ScoringEngine.run(results);
      expect(r.score, 80);
      expect(r.riskLevel, RiskLevel.low);
    });

    test('score 79 is medium risk', () {
      final results = [RuleResult(ruleId: 'a', penalty: 21, findings: [])];
      final r = ScoringEngine.run(results);
      expect(r.score, 79);
      expect(r.riskLevel, RiskLevel.medium);
    });

    test('score 55 is medium risk', () {
      final results = [RuleResult(ruleId: 'a', penalty: 45, findings: [])];
      final r = ScoringEngine.run(results);
      expect(r.score, 55);
      expect(r.riskLevel, RiskLevel.medium);
    });

    test('score 54 is high risk', () {
      final results = [RuleResult(ruleId: 'a', penalty: 46, findings: [])];
      final r = ScoringEngine.run(results);
      expect(r.score, 54);
      expect(r.riskLevel, RiskLevel.high);
    });

    test('score clamped at 0', () {
      final results = [
        RuleResult(ruleId: 'a', penalty: 50, findings: []),
        RuleResult(ruleId: 'b', penalty: 60, findings: []),
      ];
      final r = ScoringEngine.run(results);
      expect(r.score, 0);
      expect(r.riskLevel, RiskLevel.high);
    });
  });
}
