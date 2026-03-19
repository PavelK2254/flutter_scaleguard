import 'package:scale_guard/scale_guard.dart';
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
      expect(result.findings.first.message, contains('Layer boundary crossed'));
      expect(result.findings.first.message, contains('presentation'));
      expect(result.findings.first.message, contains('imports'));
      expect(result.findings.first.message, contains('data'));
      expect(result.findings.first.message,
          contains("import 'lib/features/auth/data/repository.dart';"));
      expect(result.penalty, greaterThan(0));
    });

    test('no finding when domain imports domain (same layer)', () {
      final index = ProjectIndex(
        files: [
          IndexedFile(
            path: 'lib/features/auth/domain/use_case.dart',
            lineCount: 10,
            imports: ['lib/features/auth/domain/entity.dart'],
            lines: [],
          ),
        ],
      );
      final result = rule.run(index, config);
      expect(result.findings, isEmpty);
    });

    test('finding when domain imports data (disallowed by default)', () {
      final index = ProjectIndex(
        files: [
          IndexedFile(
            path: 'lib/features/auth/domain/use_case.dart',
            lineCount: 10,
            imports: ['lib/features/auth/data/repository_impl.dart'],
            lines: [],
          ),
        ],
      );
      final result = rule.run(index, config);
      expect(result.findings.length, 1);
      expect(result.findings.first.message, contains('domain'));
      expect(result.findings.first.message, contains('data'));
    });

    test('no finding when domain imports data and allowDomainToData is true',
        () {
      final configWithAllow = ScannerConfig(allowDomainToData: true);
      final index = ProjectIndex(
        files: [
          IndexedFile(
            path: 'lib/features/auth/domain/use_case.dart',
            lineCount: 10,
            imports: ['lib/features/auth/data/repository_impl.dart'],
            lines: [],
          ),
        ],
      );
      final result = rule.run(index, configWithAllow);
      expect(result.findings, isEmpty);
    });

    test(
        'two different layer violations in same file yield two findings with distinct fingerprints',
        () {
      final index = ProjectIndex(
        files: [
          IndexedFile(
            path: 'lib/features/auth/presentation/page.dart',
            lineCount: 10,
            imports: [
              'lib/features/auth/data/repo_a.dart',
              'lib/features/auth/data/repo_b.dart',
            ],
            lines: [],
          ),
        ],
      );
      final result = rule.run(index, config);
      expect(result.findings.length, 2);
      final fp1 = result.findings[0].fingerprint;
      final fp2 = result.findings[1].fingerprint;
      expect(fp1, isNot(fp2));
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
