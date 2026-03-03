import 'path_utils.dart' as path_utils;

/// Deterministic module root key for a project-relative path under [lib/].
///
/// [projectRelativePath] must be normalized (forward slashes) before calling;
/// use [path_utils.normalizePath] if needed.
///
/// Rules (first match wins):
/// 1. lib/features/<name>/... → lib/features/<name>
/// 2. lib/feature/<name>/...  → lib/feature/<name>
/// 3. lib/modules/<name>/...  → lib/modules/<name>
/// 4. lib/src/<name>/...      → lib/src/<name>
/// 5. Else: depth-3 → lib/<a>/<b>; depth-2 → lib/<a>; lib only → lib; else → other
String moduleRootKey(String projectRelativePath) {
  final norm = path_utils.normalizePath(projectRelativePath);
  final segments = norm.split('/');

  // 1. lib/features/<name>/...
  const p1 = 'lib/features/';
  if (norm.startsWith(p1)) {
    final after = norm.substring(p1.length);
    final name = after.contains('/') ? after.substring(0, after.indexOf('/')) : after;
    if (name.isNotEmpty) return 'lib/features/$name';
  }

  // 2. lib/feature/<name>/...
  const p2 = 'lib/feature/';
  if (norm.startsWith(p2)) {
    final after = norm.substring(p2.length);
    final name = after.contains('/') ? after.substring(0, after.indexOf('/')) : after;
    if (name.isNotEmpty) return 'lib/feature/$name';
  }

  // 3. lib/modules/<name>/...
  const p3 = 'lib/modules/';
  if (norm.startsWith(p3)) {
    final after = norm.substring(p3.length);
    final name = after.contains('/') ? after.substring(0, after.indexOf('/')) : after;
    if (name.isNotEmpty) return 'lib/modules/$name';
  }

  // 4. lib/src/<name>/...
  const p4 = 'lib/src/';
  if (norm.startsWith(p4)) {
    final after = norm.substring(p4.length);
    final name = after.contains('/') ? after.substring(0, after.indexOf('/')) : after;
    if (name.isNotEmpty) return 'lib/src/$name';
  }

  // 5. Fallback: depth-3 → lib/<a>/<b>; depth-2 → lib/<a>; lib only → lib; else other
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
