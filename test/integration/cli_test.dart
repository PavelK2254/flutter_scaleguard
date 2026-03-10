import 'dart:io';

import 'package:scale_guard/scale_guard.dart';
import 'package:test/test.dart';

/// Returns process stdout as a String. Handles both String and List<int> (when encoding is set).
String _stdoutString(dynamic stdout) {
  if (stdout is String) return stdout;
  if (stdout is List<int>) return String.fromCharCodes(stdout);
  return '$stdout';
}

/// Returns process stderr as a String.
String _stderrString(dynamic stderr) {
  if (stderr is String) return stderr;
  if (stderr is List<int>) return String.fromCharCodes(stderr);
  return '$stderr';
}

void main() {
  group('CLI integration', () {
    test('runScan on empty or minimal project returns report', () async {
      final dir = Directory.current;
      final report = await runScan(dir.path);
      expect(report.score, inInclusiveRange(0, 100));
      expect(report.riskLevel, isNotNull);
      expect(report.ruleResults, isNotEmpty);
      expect(report.timestamp, isNotNull);
    });

    test('runScan returns report with meta (schema and counts)', () async {
      final dir = Directory.current;
      final report = await runScan(dir.path);
      expect(report.meta, isNotNull);
      expect(report.meta!.schemaVersion, '1.0');
      expect(report.meta!.scannedFiles, greaterThanOrEqualTo(0));
      expect(report.meta!.ignoredFiles, greaterThanOrEqualTo(0));
      expect(report.meta!.importsTotal, greaterThanOrEqualTo(0));
      expect(report.meta!.importsResolvedToProject, greaterThanOrEqualTo(0));
      expect(report.meta!.importsExternalPackage, greaterThanOrEqualTo(0));
      expect(report.meta!.importsUnresolved, greaterThanOrEqualTo(0));
    });

    test('meta is stable across two runs', () async {
      final dir = Directory.current;
      final report1 = await runScan(dir.path);
      final report2 = await runScan(dir.path);
      expect(report1.meta, isNotNull);
      expect(report2.meta, isNotNull);
      expect(report1.meta, equals(report2.meta));
    });

    test('JSON output includes meta when report has meta', () async {
      final report = await runScan(Directory.current.path);
      expect(report.meta, isNotNull);
      final json = JsonRenderer.render(report);
      expect(json, contains('"meta"'));
      expect(json, contains('"scannedFiles"'));
      expect(json, contains('"ignoredFiles"'));
      expect(json, contains('"imports"'));
      expect(json, contains('"resolvedToProject"'));
    });

    test('CLI invalid project path returns 64 and writes error to stderr', () async {
      const badPath = '/nonexistent/path/12345';
      final result = await runCli(['scan', badPath]);
      expect(result, 64);
      final processResult = await Process.run(
        'dart',
        ['run', 'bin/scale_guard.dart', 'scan', badPath],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );
      expect(processResult.exitCode, 64);
      expect(_stderrString(processResult.stderr), contains('project path not found'));
    });

    test('CLI --help prints usage and exit codes, exits 0', () async {
      final result = await runCli(['scan', Directory.current.path, '--help']);
      expect(result, 0);
      final processResult = await Process.run(
        'dart',
        ['run', 'bin/scale_guard.dart', 'scan', '--help'],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );
      expect(processResult.exitCode, 0);
      final helpOut = _stdoutString(processResult.stdout);
      expect(helpOut, contains('Usage:'));
      expect(helpOut, contains('Exit codes:'));
      expect(helpOut, contains('0  Scan succeeded'));
      expect(helpOut, contains('2  Scan succeeded but'));
      expect(helpOut, contains('64 Invalid usage'));
    });

    test('CLI with --stats prints Scan Stats section', () async {
      final dir = Directory.current.path;
      final result = await Process.run(
        'dart',
        ['run', 'bin/scale_guard.dart', 'scan', dir, '--stats'],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );
      final out = _stdoutString(result.stdout);
      expect(out, contains('Scan Stats'));
      expect(out, contains('Files scanned:'));
      expect(out, contains('Imports:'));
    });

    test('CLI with --debug prints Debug Details section', () async {
      final dir = Directory.current.path;
      final result = await Process.run(
        'dart',
        ['run', 'bin/scale_guard.dart', 'scan', dir, '--debug'],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );
      expect(_stdoutString(result.stdout), contains('Debug Details'));
    });

    test('CLI with --stats --debug prints Scan Stats then Debug Details in order', () async {
      final dir = Directory.current.path;
      final result = await Process.run(
        'dart',
        ['run', 'bin/scale_guard.dart', 'scan', dir, '--stats', '--debug'],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );
      final out = _stdoutString(result.stdout);
      expect(out, contains('Scan Stats'));
      expect(out, contains('Debug Details'));
      final scanStatsPos = out.indexOf('Scan Stats');
      final debugDetailsPos = out.indexOf('Debug Details');
      expect(scanStatsPos, greaterThanOrEqualTo(0));
      expect(debugDetailsPos, greaterThan(scanStatsPos),
          reason: 'Debug Details must appear after Scan Stats');
    });

    test('--fail-under not set: exit 0 when risk is low/medium', () async {
      final result = await runCli(['scan', Directory.current.path]);
      expect(result, isIn([0, 1]), reason: 'Without --fail-under, exit 0 or 1');
    });

    test('--fail-under set and score below threshold: exit 2, separator then Exit line (console)', () async {
      final report = await runScan(Directory.current.path);
      final threshold = report.score + 1;
      if (threshold > 100) return;
      final result = await runCli([
        'scan',
        Directory.current.path,
        '--fail-under',
        '$threshold',
      ]);
      expect(result, 2);
      final resultWithOutput = await Process.run(
        'dart',
        ['run', 'bin/scale_guard.dart', 'scan', Directory.current.path, '--fail-under', '$threshold'],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );
      expect(resultWithOutput.exitCode, 2);
      final stdout = _stdoutString(resultWithOutput.stdout);
      expect(stdout, contains('---'));
      expect(stdout, contains('Exit: score ${report.score} is below fail-under threshold $threshold.'));
      final exitLineIdx = stdout.indexOf('Exit: score');
      final sepIdx = stdout.lastIndexOf('---', exitLineIdx);
      expect(sepIdx, greaterThanOrEqualTo(0), reason: 'Separator --- must appear before Exit line');
      final between = stdout.substring(sepIdx, exitLineIdx);
      expect(between, contains('\n\n'), reason: 'Blank line after separator before Exit line');
    });

    test('--fail-under set and score meets threshold: exit 0 or 1 (not 2)', () async {
      final report = await runScan(Directory.current.path);
      final result = await runCli([
        'scan',
        Directory.current.path,
        '--fail-under',
        '${report.score}',
      ]);
      expect(result, isIn([0, 1]));
      expect(result, isNot(2));
    });

    test('--fail-under invalid: missing value exits 64', () async {
      final result = await runCli(['scan', Directory.current.path, '--fail-under']);
      expect(result, 64);
      final processResult = await Process.run(
        'dart',
        ['run', 'bin/scale_guard.dart', 'scan', Directory.current.path, '--fail-under'],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );
      expect(processResult.exitCode, 64);
      expect(_stderrString(processResult.stderr), contains('--fail-under requires an integer value'));
    });

    test('--fail-under invalid: out of range exits 64', () async {
      final result = await runCli(['scan', Directory.current.path, '--fail-under', '101']);
      expect(result, 64);
      final result2 = await runCli(['scan', Directory.current.path, '--fail-under', '-1']);
      expect(result2, 64);
      final processResult = await Process.run(
        'dart',
        ['run', 'bin/scale_guard.dart', 'scan', Directory.current.path, '--fail-under', '101'],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );
      expect(processResult.exitCode, 64);
      expect(_stderrString(processResult.stderr), contains('between 0 and 100'));
    });

    test('--fail-under with --json when triggered: stdout valid JSON only, stderr has message, exit 2', () async {
      final report = await runScan(Directory.current.path);
      final threshold = report.score + 1;
      if (threshold > 100) return;
      final processResult = await Process.run(
        'dart',
        ['run', 'bin/scale_guard.dart', 'scan', Directory.current.path, '--json', '--fail-under', '$threshold'],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );
      expect(processResult.exitCode, 2);
      expect(_stderrString(processResult.stderr), contains('Exit: score ${report.score} is below fail-under threshold $threshold.'));
      final out = _stdoutString(processResult.stdout);
      expect(out, startsWith('{'));
      expect(out, contains('"score"'));
      expect(out, isNot(contains('Exit: score')), reason: 'Exit message must not appear on stdout in JSON mode');
    });

    test('--fail-under with --json when not triggered: stdout JSON only, exit 0', () async {
      await runScan(Directory.current.path);
      final processResult = await Process.run(
        'dart',
        ['run', 'bin/scale_guard.dart', 'scan', Directory.current.path, '--json', '--fail-under', '0'],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );
      expect(processResult.exitCode, isIn([0, 1]));
      final out = _stdoutString(processResult.stdout);
      expect(out, startsWith('{'));
      expect(out, contains('"score"'));
    });

    test('ScanReport findings are sorted by severity then file then line', () {
      final high = Finding(
          severity: FindingSeverity.high,
          ruleId: 'r',
          file: 'a.dart',
          message: 'm');
      final medium = Finding(
          severity: FindingSeverity.medium,
          ruleId: 'r',
          file: 'b.dart',
          message: 'm');
      final report = ScanReport(
        score: 80,
        riskLevel: RiskLevel.low,
        ruleResults: [
          RuleResult(ruleId: 'r', penalty: 0, findings: [medium, high]),
        ],
        uniqueFindings: [high, medium],
        timestamp: DateTime.now().toUtc(),
      );
      final list = report.findings;
      expect(list.length, 2);
      expect(list.first.severity, FindingSeverity.high);
      expect(list.last.severity, FindingSeverity.medium);
    });

    test('scan . shows folder name as Project and absolute path as Scan Path', () async {
      final projectRoot = Directory.current.path;
      final result = await Process.run(
        'dart',
        ['run', 'bin/scale_guard.dart', 'scan', '.'],
        runInShell: true,
        workingDirectory: projectRoot,
      );
      expect(result.exitCode, isIn([0, 1]));
      final out = _stdoutString(result.stdout);
      final parts = projectRoot.replaceAll(r'\', '/').split('/');
      final nonEmpty = parts.where((String s) => s.isNotEmpty).toList();
      final expectedBasename = nonEmpty.isEmpty ? 'project' : nonEmpty.last;
      expect(out, contains('Project: $expectedBasename'));
      expect(out, isNot(contains('Project: .')));
      final scanPathLines = out.split('\n').where((String l) => l.startsWith('Scan Path:'));
      expect(scanPathLines, isNotEmpty);
      final expectedPath = projectRoot.replaceAll(r'\', '/');
      expect(scanPathLines.first, contains(expectedPath));
    });

    test('scan with explicit path shows path as Project and Scan Path as resolved absolute', () async {
      final result = await Process.run(
        'dart',
        ['run', 'bin/scale_guard.dart', 'scan', Directory.current.path],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );
      expect(result.exitCode, isIn([0, 1]));
      final out = _stdoutString(result.stdout);
      expect(out, contains('Scan Path:'));
      final expectedPath = Directory.current.path.replaceAll(r'\', '/');
      expect(out, contains(expectedPath));
    });

    test('Scan Path line is normalized and contains no . or .. segments', () async {
      final projectRoot = Directory.current.path;
      final result = await Process.run(
        'dart',
        ['run', 'bin/scale_guard.dart', 'scan', 'test/..'],
        runInShell: true,
        workingDirectory: projectRoot,
      );
      expect(result.exitCode, isIn([0, 1]));
      final out = _stdoutString(result.stdout);
      final scanPathLines = out.split('\n').where((String l) => l.startsWith('Scan Path:'));
      expect(scanPathLines, isNotEmpty);
      final scanPathLine = scanPathLines.first;
      final scanPathValue = scanPathLine.substring(scanPathLine.indexOf('Scan Path:') + 'Scan Path:'.length).trim();
      expect(scanPathValue, isNot(contains('..')), reason: 'Scan Path must not contain ..');
      expect(scanPathValue, isNot(contains('/./')), reason: 'Scan Path must not contain /.');
      expect(scanPathValue, contains(projectRoot.replaceAll(r'\', '/')),
          reason: 'Scan Path should be absolute path to project root');
    });
  });
}
