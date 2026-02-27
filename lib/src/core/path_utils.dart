/// Shared path normalization for cross-platform deterministic behavior.
///
/// - Converts \ to /
/// - Collapses duplicate slashes
/// - Resolves . and .. segments
/// - Keeps case as-is (no lowercasing)

/// Normalizes [path]: forward slashes, no duplicate slashes, . and .. resolved.
/// Case is preserved. Leading / or // (UNC) are preserved. Empty or blank input returns ''.
String normalizePath(String path) {
  if (path.isEmpty) return '';
  final withSlashes = path.replaceAll('\\', '/');
  final leadingSlash = withSlashes.startsWith('//') ? '//' : (withSlashes.startsWith('/') ? '/' : '');
  final parts = withSlashes.split('/');
  final resolved = <String>[];
  for (final p in parts) {
    if (p == '..') {
      if (resolved.isNotEmpty) resolved.removeLast();
    } else if (p != '.' && p.isNotEmpty) {
      resolved.add(p);
    }
  }
  final joined = resolved.join('/');
  return leadingSlash.isEmpty ? joined : (joined.isEmpty ? leadingSlash : '$leadingSlash$joined');
}

/// Returns [relativePath] as an absolute path under [projectRoot].
/// Both inputs are normalized; result is normalized.
String toAbsolutePath(String projectRoot, String relativePath) {
  final root = normalizePath(projectRoot);
  final rel = normalizePath(relativePath);
  if (rel.isEmpty) return root;
  if (root.isEmpty) return rel;
  return normalizePath('$root/$rel');
}

/// Returns project-relative path if [absolutePath] is under [projectRoot].
/// Both inputs should be normalized. If [absolutePath] is not under [projectRoot],
/// returns [absolutePath] as-is (normalized).
String toProjectRelativePath(String absolutePath, String projectRoot) {
  final abs = normalizePath(absolutePath);
  final root = normalizePath(projectRoot);
  if (root.isEmpty) return abs;
  if (abs == root) return '';
  final prefix = root.endsWith('/') ? root : '$root/';
  if (abs.startsWith(prefix)) {
    return normalizePath(abs.substring(prefix.length));
  }
  return abs;
}
