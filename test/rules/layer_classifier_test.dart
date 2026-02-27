import 'package:scale_guard/scale_guard.dart';
import 'package:test/test.dart';

void main() {
  group('classifyPath', () {
    const config = ScannerConfig();

    test('classifies presentation paths', () {
      expect(
        classifyPath('lib/features/auth/presentation/page.dart', config),
        Layer.presentation,
      );
      expect(classifyPath('lib/ui/widgets/screen.dart', config),
          Layer.presentation);
      expect(classifyPath('lib/features/auth/bloc/auth_bloc.dart', config),
          Layer.presentation);
      expect(classifyPath('lib/features/auth/cubit/auth_cubit.dart', config),
          Layer.presentation);
    });

    test('classifies domain paths', () {
      expect(
        classifyPath('lib/features/auth/domain/entity.dart', config),
        Layer.domain,
      );
      expect(
        classifyPath('lib/features/auth/usecases/login.dart', config),
        Layer.domain,
      );
    });

    test('classifies data paths', () {
      expect(
        classifyPath('lib/features/auth/data/repository_impl.dart', config),
        Layer.data,
      );
      expect(
        classifyPath('lib/features/auth/datasource/remote.dart', config),
        Layer.data,
      );
      expect(
        classifyPath('lib/features/auth/repositories/repo.dart', config),
        Layer.data,
      );
    });

    test('priority: presentation wins over domain when both match', () {
      final path = 'lib/features/auth/presentation/domain_overlap.dart';
      expect(classifyPath(path, config), Layer.presentation);
    });

    test('domain importing domain does not produce violation', () {
      final rule = LayerViolationsRule();
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
  });
}
