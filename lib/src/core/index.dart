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

  /// Normalized path: use forward slashes for consistent comparison.
  static String normalizePath(String path) {
    return path.replaceAll('\\', '/');
  }

  /// Resolve relative import [target] from [fromPath] to a path under lib.
  /// Returns null if target is package: or not under lib.
  static String? resolveImportPath(String fromPath, String target, String? packageName) {
    final from = normalizePath(fromPath);
    if (target.startsWith('package:')) {
      if (packageName == null) return null;
      final rest = target.substring(8).trim();
      final slash = rest.indexOf('/');
      final pkg = slash < 0 ? rest : rest.substring(0, slash);
      if (pkg != packageName) return null;
      final path = slash < 0 ? '' : rest.substring(slash + 1);
      return 'lib/$path';
    }
    if (target.startsWith('dart:')) return null;
    final fromDir = from.contains('/') ? from.substring(0, from.lastIndexOf('/') + 1) : '';
    final combined = fromDir + target;
    final parts = combined.split('/');
    final resolved = <String>[];
    for (final p in parts) {
      if (p == '..') {
        if (resolved.isNotEmpty) resolved.removeLast();
      } else if (p != '.' && p.isNotEmpty) {
        resolved.add(p);
      }
    }
    return resolved.join('/');
  }
}
