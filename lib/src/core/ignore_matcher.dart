import 'path_utils.dart' as path_utils;

/// Validates an ignore entry before it is stored; returns null if usable.
String? validateIgnorePattern(String raw) {
  final p = raw.trim();
  if (p.isEmpty) return 'pattern is empty';
  if (isGlobPattern(p)) return validateGlobPattern(p);
  return null;
}

/// Returns true if [pattern] uses glob mode (`*` or `**` as path segments / wildcards).
///
/// `**` must appear only as a whole path segment (between `/`). A segment like `foo**bar`
/// is invalid for glob mode and should be rejected by [validateGlobPattern].
bool isGlobPattern(String pattern) {
  final p = pattern.trim();
  if (p.isEmpty) return false;
  return p.contains('*');
}

/// If [pattern] is invalid for glob matching, returns a short reason; otherwise null.
String? validateGlobPattern(String pattern) {
  final norm = path_utils.normalizePath(pattern.trim());
  if (norm.isEmpty) return 'pattern is empty';
  final segments = norm.split('/');
  for (final seg in segments) {
    if (seg.isEmpty) continue;
    if (seg.contains('**') && seg != '**') {
      return '`**` must be its own path segment';
    }
  }
  return null;
}

/// True when [normalizedPath] should be ignored given [patterns] (after normalization).
///
/// Each pattern is either **literal** (no `*`) or **glob** ([isGlobPattern]).
/// Literal: path contains pattern as substring OR path ends with pattern.
/// Glob: only segment-based glob matching ([globPathMatch]); no substring fallback.
bool shouldIgnoreNormalizedPath(String normalizedPath, List<String> patterns) {
  final path = path_utils.normalizePath(normalizedPath);
  if (path.isEmpty) return false;
  for (final raw in patterns) {
    final p = raw.trim();
    if (p.isEmpty) continue;
    if (isGlobPattern(p)) {
      if (validateGlobPattern(p) != null) continue;
      final patNorm = path_utils.normalizePath(p);
      if (globPathMatch(path, patNorm)) return true;
    } else {
      if (path.contains(p) || path.endsWith(p)) return true;
    }
  }
  return false;
}

/// Glob match for normalized paths; [pattern] must be normalized.
bool globPathMatch(String normalizedPath, String pattern) {
  final pathParts =
      normalizedPath.split('/').where((s) => s.isNotEmpty).toList();
  final patParts = pattern.split('/').where((s) => s.isNotEmpty).toList();
  return _globParts(pathParts, patParts, 0, 0);
}

bool _globParts(
    List<String> path, List<String> pat, int pi, int pj) {
  if (pj == pat.length) return pi == path.length;
  if (pat[pj] == '**') {
    for (var k = pi; k <= path.length; k++) {
      if (_globParts(path, pat, k, pj + 1)) return true;
    }
    return false;
  }
  if (pi == path.length) return false;
  if (!_segmentGlobMatch(path[pi], pat[pj])) return false;
  return _globParts(path, pat, pi + 1, pj + 1);
}

/// `*` matches zero or more characters within one segment (no `/`).
bool _segmentGlobMatch(String segment, String pattern) {
  if (!pattern.contains('*')) return segment == pattern;
  return _segmentGlob(segment, pattern, 0, 0);
}

bool _segmentGlob(String s, String p, int i, int j) {
  if (j == p.length) return i == s.length;
  if (p[j] == '*') {
    for (var k = i; k <= s.length; k++) {
      if (_segmentGlob(s, p, k, j + 1)) return true;
    }
    return false;
  }
  if (i == s.length) return false;
  if (s.codeUnitAt(i) != p.codeUnitAt(j)) return false;
  return _segmentGlob(s, p, i + 1, j + 1);
}
