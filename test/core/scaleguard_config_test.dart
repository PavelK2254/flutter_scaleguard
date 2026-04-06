import 'dart:io';

import 'package:scale_guard/scale_guard.dart';
import 'package:test/test.dart';

void main() {
  group('ScannerConfig.loadWithDiagnostics', () {
    test('both yaml files: only scaleguard applied; warning emitted', () async {
      final dir = await Directory.systemTemp.createTemp('sg_cfg_');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}/scaleguard.yaml').writeAsString('''
thresholds:
  god_file_medium_loc: 400
  god_file_high_loc: 800
''');
      await File('${dir.path}/risk_scanner.yaml').writeAsString('''
god_file_medium_loc: 111
god_file_high_loc: 222
''');

      final r = await ScannerConfig.loadWithDiagnostics(dir.path);
      expect(r.config.godFileMediumLoc, 400);
      expect(r.config.godFileHighLoc, 800);
      expect(
        r.warnings.any((w) =>
            w.contains('risk_scanner.yaml') && w.contains('ignored')),
        isTrue,
      );
    });

    test('unknown top-level key yields warning', () async {
      final dir = await Directory.systemTemp.createTemp('sg_cfg_');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}/scaleguard.yaml')
          .writeAsString('unknown_key: true\n');

      final r = await ScannerConfig.loadWithDiagnostics(dir.path);
      expect(
          r.warnings.any((w) => w.contains('unknown_key')), isTrue);
      expect(r.config.featureRoots, const ScannerConfig().featureRoots);
      expect(r.config.ruleEnabled, isEmpty);
    });

    test('unknown rule id yields warning', () async {
      final dir = await Directory.systemTemp.createTemp('sg_cfg_');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}/scaleguard.yaml').writeAsString('''
rules:
  not_a_rule: false
''');

      final r = await ScannerConfig.loadWithDiagnostics(dir.path);
      expect(r.warnings.any((w) => w.contains('not_a_rule')), isTrue);
    });

    test('load discards warnings but matches config', () async {
      final dir = await Directory.systemTemp.createTemp('sg_cfg_');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}/scaleguard.yaml').writeAsString('''
thresholds:
  god_file_medium_loc: 400
  god_file_high_loc: 800
''');

      final a = await ScannerConfig.load(dir.path);
      final b = await ScannerConfig.loadWithDiagnostics(dir.path);
      expect(a.godFileMediumLoc, b.config.godFileMediumLoc);
      expect(a.godFileHighLoc, b.config.godFileHighLoc);
    });
  });

  group('scaleguard rules and failUnder', () {
    test('disabled rule omitted from runScan ruleResults', () async {
      final dir = await Directory.systemTemp.createTemp('sg_scan_');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}/pubspec.yaml').writeAsString('name: sg_tmp\n');
      await Directory('${dir.path}/lib').create(recursive: true);
      await File('${dir.path}/lib/x.dart').writeAsString('// x\n');

      await File('${dir.path}/scaleguard.yaml').writeAsString('''
rules:
  god_files: false
''');

      final report = await runScan(dir.path);
      expect(
        report.ruleResults.map((e) => e.ruleId).contains('god_files'),
        isFalse,
      );
    });

    test('failUnder set from scaleguard.yaml', () async {
      final dir = await Directory.systemTemp.createTemp('sg_fu_');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}/scaleguard.yaml').writeAsString('''
score:
  fail_under: 88
''');

      final r = await ScannerConfig.loadWithDiagnostics(dir.path);
      expect(r.config.failUnder, 88);
    });

    test('fail_under above 100 is ignored with warning', () async {
      final dir = await Directory.systemTemp.createTemp('sg_fu2_');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}/scaleguard.yaml').writeAsString('''
score:
  fail_under: 101
''');

      final r = await ScannerConfig.loadWithDiagnostics(dir.path);
      expect(r.config.failUnder, isNull);
      expect(
          r.warnings.any((w) => w.contains('score.fail_under')), isTrue);
    });
  });
}
