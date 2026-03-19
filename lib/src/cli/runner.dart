import 'dart:io';

import '../core/path_utils.dart' as path_utils;
import '../core/scanner.dart';
import '../model/risk_level.dart';
import '../render/console_renderer.dart';
import '../render/json_renderer.dart';
import '../version.dart';

/// Runs the CLI with [arguments]. Returns exit code: 0 for success (and score meets fail-under if set),
/// 1 for High risk, 2 when score is below --fail-under threshold, 64 for usage error.
Future<int> runCli(List<String> arguments) async {
  if (arguments.contains('--help') || arguments.contains('-h')) {
    _printHelp();
    return 0;
  }

  final json = arguments.contains('--json');
  final stats = arguments.contains('--stats');
  final debug = arguments.contains('--debug');

  int? failUnder;
  final failUnderIdx = arguments.indexOf('--fail-under');
  if (failUnderIdx >= 0) {
    final valueIdx = failUnderIdx + 1;
    if (valueIdx >= arguments.length) {
      stderr.writeln('Error: --fail-under requires an integer value (0-100).');
      return 64;
    }
    final value = int.tryParse(arguments[valueIdx]);
    if (value == null || value < 0 || value > 100) {
      stderr
          .writeln('Error: --fail-under must be an integer between 0 and 100.');
      return 64;
    }
    failUnder = value;
  }

  final args = <String>[];
  for (var i = 0; i < arguments.length; i++) {
    final a = arguments[i];
    if (a == '--json' ||
        a == '--stats' ||
        a == '--debug' ||
        a == '--help' ||
        a == '-h') continue;
    if (a == '--fail-under') {
      i++;
      continue;
    }
    args.add(a);
  }
  if (args.length < 2 || args[0] != 'scan') {
    print(
        'Usage: scale_guard scan <project_path> [--json] [--stats] [--debug] [--fail-under <0-100>]');
    print('Use --help for exit codes and options.');
    return 64;
  }
  final rawPath = args[1];
  return _runScan(rawPath,
      jsonOutput: json,
      showStats: stats,
      showDebug: debug,
      failUnder: failUnder);
}

/// True when [rawPath] is current-directory form (e.g. ".", "./").
/// normalizePath consumes "." segments, so "." becomes ""; only isEmpty is needed.
bool _isCurrentDirPath(String rawPath) {
  final norm = path_utils.normalizePath(rawPath);
  return norm.isEmpty;
}

/// Resolved path for scanning, display name for "Project:", and scan path for "Scan Path:".
(String resolvedPath, String displayName, String scanPath) _resolvePath(
    String rawPath) {
  final dir = Directory(rawPath);
  final resolvedPath =
      _isCurrentDirPath(rawPath) ? Directory.current.path : dir.absolute.path;
  final displayName = _isCurrentDirPath(rawPath)
      ? (path_utils
          .normalizePath(resolvedPath)
          .split('/')
          .lastWhere((s) => s.isNotEmpty, orElse: () => 'project'))
      : rawPath;
  return (resolvedPath, displayName, path_utils.normalizePath(resolvedPath));
}

Future<int> _runScan(String rawPath,
    {required bool jsonOutput,
    bool showStats = false,
    bool showDebug = false,
    int? failUnder}) async {
  final dir = Directory(rawPath);
  if (!await dir.exists() ||
      !await dir.stat().then((s) => s.type == FileSystemEntityType.directory)) {
    stderr
        .writeln('Error: project path not found or not a directory: $rawPath');
    return 64;
  }
  final (resolvedPath, displayName, scanPath) = _resolvePath(rawPath);
  final report = await runScan(resolvedPath,
      projectDisplayName: displayName, scanPath: scanPath);
  if (jsonOutput) {
    final version = await getPackageVersion();
    print(JsonRenderer.render(report, version: version));
  } else {
    final version = await getPackageVersion();
    ConsoleRenderer.render(report,
        version: version, showStats: showStats, showDebug: showDebug);
  }

  if (failUnder != null && report.score < failUnder) {
    final message =
        'Exit: score ${report.score} is below fail-under threshold $failUnder.';
    if (jsonOutput) {
      stderr.writeln(message);
    } else {
      print('');
      print('---');
      print('');
      print(message);
    }
    return 2;
  }
  return report.riskLevel == RiskLevel.high ? 1 : 0;
}

void _printHelp() {
  print(
      'Usage: scale_guard scan <project_path> [--json] [--stats] [--debug] [--fail-under <0-100>]');
  print('');
  print('Exit codes:');
  print('  0  Scan succeeded (and passed --fail-under if provided)');
  print('  2  Scan succeeded but --fail-under threshold not met');
  print('  64 Invalid usage / invalid project path (e.g., not a directory)');
  print('  1  High risk (scan succeeded but risk level is High)');
}
