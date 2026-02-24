import 'package:flutter_arch_risk/flutter_arch_risk.dart';
import 'package:test/test.dart';

void main() {
  group('LayerViolationsRule', () {
    late LayerViolationsRule rule;
    late ScannerConfig config;

    setUp(() {
      rule = LayerViolationsRule();
      config = const ScannerConfig();
    });

    test('no findings when presentation imports only domain', () {
      final index = ProjectIndex(
        files: [
          IndexedFile(
            path: 'lib/features/auth/presentation/page.dart',
            lineCount: 10,
            imports: ['lib/features/auth/domain/user.dart'],
            lines: [],
          ),
        ],
      );
      final result = rule.run(index, config);
      expect(result.findings, isEmpty);
    });

    test('finding when presentation imports data', () {
      final index = ProjectIndex(
        files: [
          IndexedFile(
            path: 'lib/features/auth/presentation/page.dart',
            lineCount: 10,
            imports: ['lib/features/auth/data/repository.dart'],
            lines: [],
          ),
        ],
      );
      final result = rule.run(index, config);
      expect(result.findings.length, 1);
      expect(result.findings.first.ruleId, 'layer_violations');
      expect(result.findings.first.message, contains('data'));
      expect(result.penalty, greaterThan(0));
    });

    test('no finding when data imports domain', () {
      final index = ProjectIndex(
        files: [
          IndexedFile(
            path: 'lib/features/auth/data/repository.dart',
            lineCount: 10,
            imports: ['lib/features/auth/domain/user.dart'],
            lines: [],
          ),
        ],
      );
      final result = rule.run(index, config);
      expect(result.findings, isEmpty);
    });
  });
}
