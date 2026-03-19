import 'severity.dart';

/// Deterministic stable hash for strings (same input => same output across runs).
int stableStringHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = ((h * 31) + c) & 0x7FFFFFFF;
  }
  return h;
}

class Finding {
  const Finding({
    required this.severity,
    required this.ruleId,
    required this.file,
    required this.message,
    this.line,
    this.resolvedImportedPath,
    this.fromLayer,
    this.toLayer,
    this.fromFeature,
    this.toFeature,
    this.sourceFeaturePath,
    this.targetFeaturePath,
  });

  final FindingSeverity severity;
  final String ruleId;
  final String file;
  final String message;
  final int? line;

  /// Set by layer_violations for fingerprint and examples ordering.
  final String? resolvedImportedPath;
  final String? fromLayer;
  final String? toLayer;

  /// Set by cross_feature_coupling for examples (fromFeature -> toFeature).
  final String? fromFeature;
  final String? toFeature;

  /// Set by cross_feature_coupling for correct hotspot (e.g. lib/features/achievements).
  final String? sourceFeaturePath;
  final String? targetFeaturePath;

  /// Normalized message for fingerprint: trim and collapse whitespace.
  String get evidenceNormalized =>
      message.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Deterministic fingerprint for deduplication.
  /// When fromLayer, toLayer, resolvedImportedPath are set: ruleId|file|fromLayer|toLayer|resolvedImportedPath|line (no hash).
  /// Otherwise: ruleId|file|line|hash(evidence).
  String get fingerprint {
    if (fromLayer != null &&
        toLayer != null &&
        resolvedImportedPath != null &&
        ruleId == 'layer_violations') {
      return '$ruleId|$file|$fromLayer|$toLayer|$resolvedImportedPath|${line ?? ''}';
    }
    return '$ruleId|$file|${line ?? ''}|${stableStringHash(evidenceNormalized)}';
  }
}
