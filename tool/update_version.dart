// ignore_for_file: avoid_print
//
// Syncs the version from pubspec.yaml into lib/src/version.dart (fallback constant).
// Run from package root: dart run tool/update_version.dart
//
// Run this after bumping version in pubspec.yaml so the CLI banner stays in sync.

import 'dart:io';

import 'package:yaml/yaml.dart';

void main() {
  final script = File(Platform.script.toFilePath());
  final packageRoot = script.parent.parent.path;
  final sep = Platform.pathSeparator;
  final pubspecFile = File('$packageRoot${sep}pubspec.yaml');
  final versionFile = File('$packageRoot${sep}lib${sep}src${sep}version.dart');

  if (!pubspecFile.existsSync()) {
    print('Error: pubspec.yaml not found at ${pubspecFile.path}');
    exit(1);
  }
  if (!versionFile.existsSync()) {
    print('Error: lib/src/version.dart not found at ${versionFile.path}');
    exit(1);
  }

  final yaml = loadYaml(pubspecFile.readAsStringSync());
  final version = (yaml is YamlMap) ? yaml['version'] : null;
  if (version is! String || version.isEmpty) {
    print('Error: could not read version from pubspec.yaml');
    exit(1);
  }

  var content = versionFile.readAsStringSync();
  final pattern = RegExp(r"const String fallbackPackageVersion = '([^']+)';");
  if (!pattern.hasMatch(content)) {
    print('Error: fallbackPackageVersion line not found in version.dart');
    exit(1);
  }
  final newLine = "const String fallbackPackageVersion = '$version';";
  content = content.replaceFirst(pattern, newLine);
  versionFile.writeAsStringSync(content);
  print('Updated fallbackPackageVersion to $version in lib/src/version.dart');
}
