import 'dart:io';

import 'package:scale_guard/scale_guard.dart';
import 'package:test/test.dart';

void main() {
  test('resolved imports to ignored paths are omitted from index', () async {
    final dir = await Directory.systemTemp.createTemp('sg_imp_');
    addTearDown(() => dir.delete(recursive: true));
    await File('${dir.path}/pubspec.yaml').writeAsString('name: sg_imp_pkg\n');
    await Directory('${dir.path}/lib/gen').create(recursive: true);
    await File('${dir.path}/lib/gen/x.g.dart').writeAsString('class X {}\n');
    await File('${dir.path}/lib/a.dart').writeAsString(
        "import 'package:sg_imp_pkg/gen/x.g.dart';\n");

    const config = ScannerConfig();
    final r = await buildIndexWithMeta(dir.path, config);
    final a = r.index.files.singleWhere((f) => f.path.endsWith('a.dart'));
    expect(a.imports, isEmpty);
  });
}
