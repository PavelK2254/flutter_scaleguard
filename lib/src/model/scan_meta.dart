/// Deterministic scan statistics (no timestamps or absolute paths).
class ScanMeta {
  const ScanMeta({
    required this.schemaVersion,
    required this.scannedFiles,
    required this.ignoredFiles,
    required this.importsTotal,
    required this.importsResolvedToProject,
    required this.importsExternalPackage,
    required this.importsUnresolved,
  });

  static const String defaultSchemaVersion = '1.0';

  final String schemaVersion;
  final int scannedFiles;
  final int ignoredFiles;
  final int importsTotal;
  final int importsResolvedToProject;
  final int importsExternalPackage;
  final int importsUnresolved;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanMeta &&
          schemaVersion == other.schemaVersion &&
          scannedFiles == other.scannedFiles &&
          ignoredFiles == other.ignoredFiles &&
          importsTotal == other.importsTotal &&
          importsResolvedToProject == other.importsResolvedToProject &&
          importsExternalPackage == other.importsExternalPackage &&
          importsUnresolved == other.importsUnresolved;

  @override
  int get hashCode =>
      Object.hash(
          schemaVersion,
          scannedFiles,
          ignoredFiles,
          importsTotal,
          importsResolvedToProject,
          importsExternalPackage,
          importsUnresolved);
}
