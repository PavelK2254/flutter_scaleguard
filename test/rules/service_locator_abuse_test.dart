import 'package:scale_guard/scale_guard.dart';
import 'package:test/test.dart';

void main() {
  group('ServiceLocatorAbuseRule', () {
    late ServiceLocatorAbuseRule rule;
    late ScannerConfig config;

    setUp(() {
      rule = ServiceLocatorAbuseRule();
      config = const ScannerConfig();
    });

    test('import-only line does not report', () {
      final index = ProjectIndex(
        files: [
          IndexedFile(
            path: 'lib/features/auth/presentation/page.dart',
            lineCount: 5,
            imports: [],
            lines: [
              "import 'package:get_it/get_it.dart';",
              "void main() { }",
            ],
          ),
        ],
      );
      final result = rule.run(index, config);
      expect(result.findings, isEmpty);
    });

    test('usage line with GetIt.I reports', () {
      final index = ProjectIndex(
        files: [
          IndexedFile(
            path: 'lib/features/auth/presentation/page.dart',
            lineCount: 5,
            imports: [],
            lines: [
              "  final repo = GetIt.I.get<AuthRepo>();",
            ],
          ),
        ],
      );
      final result = rule.run(index, config);
      expect(result.findings.length, 1);
      expect(result.findings.first.ruleId, 'service_locator_abuse');
    });

    test('file under lib/di/ is skipped', () {
      final index = ProjectIndex(
        files: [
          IndexedFile(
            path: 'lib/di/injection.dart',
            lineCount: 5,
            imports: [],
            lines: [
              "  getIt.registerSingleton<AuthRepo>(AuthRepoImpl());",
            ],
          ),
        ],
      );
      final result = rule.run(index, config);
      expect(result.findings, isEmpty);
    });
  });
}
