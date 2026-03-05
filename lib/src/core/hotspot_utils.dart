import 'module_root.dart';
import 'path_utils.dart' as path_utils;
import '../model/finding.dart';
import '../model/scan_report.dart';

/// Shared hotspot key and ordered entries for console and JSON reporting.
/// Deterministic: same grouping and sort (count desc, then path asc) as console Top Hotspots.
class HotspotUtils {
  HotspotUtils._();

  static String _normPath(String p) => path_utils.normalizePath(p);

  /// Source hotspot key from [Finding.file]. Uses [report.moduleIndex] when present,
  /// otherwise [moduleRootKey] on normalized path. Deterministic across platforms.
  static String getSourceHotspotKey(Finding f, ScanReport report) {
    final norm = _normPath(f.file);
    return report.moduleIndex?[norm] ?? moduleRootKey(norm);
  }

  /// Ordered hotspot entries: (path, count), sorted by count desc then path asc.
  /// Uses [report.uniqueFindings] and [getSourceHotspotKey].
  static List<(String path, int count)> getOrderedHotspotEntries(ScanReport report) {
    final findings = report.uniqueFindings;
    if (findings.isEmpty) return [];
    final countByKey = <String, int>{};
    for (final f in findings) {
      final key = getSourceHotspotKey(f, report);
      countByKey[key] = (countByKey[key] ?? 0) + 1;
    }
    final entries = countByKey.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    return entries.map((e) => (e.key, e.value)).toList();
  }
}
