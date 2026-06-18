import '../model/category_aggregation.dart';

/// Non-zero category penalties for Score Breakdown display.
/// Order matches [CategoryAggregation.penaltyByCategory]: penalty desc, name asc.
List<MapEntry<String, int>> scoreBreakdownEntries(CategoryAggregation agg) {
  if (agg.totalPenalty <= 0) return const [];
  final entries = <MapEntry<String, int>>[];
  for (final e in agg.penaltyByCategory.entries) {
    if (e.value <= 0) continue;
    final rounded = e.value.round();
    if (rounded > 0) {
      entries.add(MapEntry(e.key, rounded));
    }
  }
  return entries;
}
