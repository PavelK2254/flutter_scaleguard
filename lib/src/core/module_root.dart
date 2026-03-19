import 'path_utils.dart' as path_utils;

/// Deterministic module root key for a project-relative path under [lib/].
///
/// [projectRelativePath] must be normalized (forward slashes) before calling;
/// use [path_utils.normalizePath] if needed.
String moduleRootKey(String projectRelativePath) {
  final norm = path_utils.normalizePath(projectRelativePath);
  final segments = norm.split('/');

  const p1 = 'lib/features/';
  if (norm.startsWith(p1)) {
    final after = norm.substring(p1.length);
    final name =
        after.contains('/') ? after.substring(0, after.indexOf('/')) : after;
    if (name.isNotEmpty) return 'lib/features/$name';
  }

  const p2 = 'lib/feature/';
  if (norm.startsWith(p2)) {
    final after = norm.substring(p2.length);
    final name =
        after.contains('/') ? after.substring(0, after.indexOf('/')) : after;
    if (name.isNotEmpty) return 'lib/feature/$name';
  }

  const p3 = 'lib/modules/';
  if (norm.startsWith(p3)) {
    final after = norm.substring(p3.length);
    final name =
        after.contains('/') ? after.substring(0, after.indexOf('/')) : after;
    if (name.isNotEmpty) return 'lib/modules/$name';
  }

  const p4 = 'lib/src/';
  if (norm.startsWith(p4)) {
    final after = norm.substring(p4.length);
    final name =
        after.contains('/') ? after.substring(0, after.indexOf('/')) : after;
    if (name.isNotEmpty) return 'lib/src/$name';
  }

  if (segments.length >= 4 && segments[0] == 'lib') {
    return 'lib/${segments[1]}/${segments[2]}';
  }
  if (segments.length >= 3 && segments[0] == 'lib') {
    return 'lib/${segments[1]}';
  }
  if (segments.length == 2 && segments[0] == 'lib') {
    return 'lib';
  }
  if (segments.length == 1 && segments[0] == 'lib') {
    return 'lib';
  }
  return 'other';
}
