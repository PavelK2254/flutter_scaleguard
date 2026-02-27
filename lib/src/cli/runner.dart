import 'dart:io';

import '../core/scanner.dart';
import '../model/risk_level.dart';
import '../render/console_renderer.dart';
import '../render/json_renderer.dart';
import '../version.dart';

/// Runs the CLI with [arguments]. Returns exit code: 0 for Low/Medium, 1 for High.
Future<int> runCli(List<String> arguments) async {
  final json = arguments.contains('--json');
  final stats = arguments.contains('--stats');
  final args = arguments
      .where((a) => a != '--json' && a != '--stats')
      .toList();
  if (args.length < 2 || args[0] != 'scan') {
    print('Usage: scale_guard scan <project_path> [--json] [--stats]');
    return 64;
  }
  final projectPath = args[1];
  return _runScan(projectPath, jsonOutput: json, showStats: stats);
}

Future<int> _runScan(String projectPath,
    {required bool jsonOutput, bool showStats = false}) async {
  final dir = Directory(projectPath);
  if (!await dir.exists() ||
      !await dir.stat().then((s) => s.type == FileSystemEntityType.directory)) {
    print('Error: project path not found or not a directory: $projectPath');
    return 1;
  }
  final report = await runScan(projectPath);
  if (jsonOutput) {
    print(JsonRenderer.render(report));
  } else {
    final version = await getPackageVersion();
    ConsoleRenderer.render(report, version: version, showStats: showStats);
  }
  return report.riskLevel == RiskLevel.high ? 1 : 0;
}
