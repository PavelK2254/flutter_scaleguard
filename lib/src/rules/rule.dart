import '../core/config.dart';
import '../core/index.dart';
import '../model/rule_result.dart';

abstract interface class Rule {
  String get id;
  double get weight;
  double get cap;
  String get description;
  String get suggestion;
  RuleResult run(ProjectIndex index, ScannerConfig config);
}
