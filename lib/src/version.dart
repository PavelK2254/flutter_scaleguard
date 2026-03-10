import 'dart:isolate';
import 'dart:io';

import 'package:yaml/yaml.dart';

/// Fallback when package resolution or pubspec read fails (e.g. AOT, tests).
/// Keep in sync with pubspec.yaml: run `dart run tool/update_version.dart` after bumping version.
const String fallbackPackageVersion = '0.4.1';

/// Loads the package version from [pubspec.yaml] so the CLI banner stays in sync.
/// Returns [fallbackPackageVersion] if resolution or parsing fails.
Future<String> getPackageVersion() async {
  final packageRoot = await Isolate.resolvePackageUri(
    Uri.parse('package:scale_guard/'),
  );
  if (packageRoot == null || !packageRoot.isScheme('file')) {
    return fallbackPackageVersion;
  }
  final pubspecUri = packageRoot.resolve('pubspec.yaml');
  final file = File(pubspecUri.toFilePath());
  if (!await file.exists()) {
    return fallbackPackageVersion;
  }
  try {
    final content = await file.readAsString();
    final yaml = loadYaml(content);
    final version = (yaml is YamlMap) ? yaml['version'] : null;
    if (version is String && version.isNotEmpty) {
      return version;
    }
  } catch (_) {
    // ignore
  }
  return fallbackPackageVersion;
}
