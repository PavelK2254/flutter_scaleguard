import 'severity.dart';

class Finding {
  const Finding({
    required this.severity,
    required this.ruleId,
    required this.file,
    required this.message,
    this.line,
  });

  final FindingSeverity severity;
  final String ruleId;
  final String file;
  final String message;
  final int? line;
}
