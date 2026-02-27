import 'path_utils.dart' as path_utils;

/// A single file entry in the project index.
class IndexedFile {
  const IndexedFile({
    required this.path,
    required this.lineCount,
    required this.imports,
    this.lines = const [],
  });

  /// Relative path from project root (e.g. lib/features/auth/presentation/page.dart).
  final String path;

  /// Number of lines in the file.
  final int lineCount;

  /// Resolved import targets: package URIs or paths relative to lib (normalized).
  final List<String> imports;

  /// Full line content for rules that need to scan source (e.g. hardcoded URLs).
  /// Empty if not requested when building the index.
  final List<String> lines;
}

/// Parsed project metadata: all indexed files and optional package name.
class ProjectIndex {
  const ProjectIndex({
    required this.files,
    this.packageName,
  });

  final List<IndexedFile> files;
  final String? packageName;

  /// Normalized path: use forward slashes, collapse slashes, resolve . and ..
  static String normalizePath(String path) {
    return path_utils.normalizePath(path);
  }

  /// Resolve import [target] from [fromPath] to a project-relative path under lib.
  /// Returns null for dart:, flutter:, external package, or if relative resolves outside lib.
  static String? resolveImportPath(
      String fromPath, String target, String? packageName) {
    final from = normalizePath(fromPath);
    if (target.startsWith('dart:')) return null;
    if (target.startsWith('flutter:')) return null;
    if (target.startsWith('package:')) {
      if (packageName == null) return null;
      final rest = target.substring(8).trim();
      final slash = rest.indexOf('/');
      final pkg = slash < 0 ? rest : rest.substring(0, slash);
      if (pkg != packageName) return null;
      final path = slash < 0 ? '' : rest.substring(slash + 1);
      final resolved = path_utils.normalizePath('lib/$path');
      return resolved.startsWith('lib/') ? resolved : null;
    }
    final fromDir =
        from.contains('/') ? from.substring(0, from.lastIndexOf('/') + 1) : '';
    final combined = fromDir + target;
    final resolved = path_utils.normalizePath(combined);
    if (!resolved.startsWith('lib/')) return null;
    return resolved;
  }
}
