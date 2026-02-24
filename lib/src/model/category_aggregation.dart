import 'rule_result.dart';
import 'severity.dart';

/// Per-category penalty and finding counts.
class CategoryScore {
  const CategoryScore({
    required this.category,
    required this.totalPenalty,
    required this.highCount,
    required this.mediumCount,
  });

  final String category;
  final double totalPenalty;
  final int highCount;
  final int mediumCount;
}

/// Aggregated scoring by category and dominant/most-expensive rule.
class CategoryAggregation {
  const CategoryAggregation({
    required this.categoryScores,
    required this.dominantCategory,
    required this.mostExpensiveRuleId,
    required this.mostExpensivePenalty,
    required this.totalPenalty,
  });

  /// Sorted by totalPenalty descending, then category ascending.
  final List<CategoryScore> categoryScores;

  /// Category name with highest total penalty (ties: alphabetical).
  final String dominantCategory;

  /// Rule id with highest single-rule penalty (ties: alphabetical).
  final String mostExpensiveRuleId;

  /// That rule's penalty.
  final double mostExpensivePenalty;

  /// Sum of all rule penalties (for percentage).
  final double totalPenalty;

  /// Builds aggregation from rule results and ruleId→category mapping.
  /// Deterministic: ties resolved alphabetically by category or ruleId.
  static CategoryAggregation fromRuleResults(
    List<RuleResult> results,
    Map<String, String> ruleIdToCategory,
  ) {
    double totalPenalty = 0;
    for (final r in results) {
      totalPenalty += r.penalty;
    }

    final categoryPenalty = <String, double>{};
    final categoryHigh = <String, int>{};
    final categoryMedium = <String, int>{};

    for (final r in results) {
      final cat = ruleIdToCategory[r.ruleId] ?? r.ruleId;
      categoryPenalty[cat] = (categoryPenalty[cat] ?? 0) + r.penalty;
      int high = 0, medium = 0;
      for (final f in r.findings) {
        if (f.severity == FindingSeverity.high) {
          high++;
        } else {
          medium++;
        }
      }
      categoryHigh[cat] = (categoryHigh[cat] ?? 0) + high;
      categoryMedium[cat] = (categoryMedium[cat] ?? 0) + medium;
    }

    final categoryScores = <CategoryScore>[];
    for (final e in categoryPenalty.entries) {
      categoryScores.add(CategoryScore(
        category: e.key,
        totalPenalty: e.value,
        highCount: categoryHigh[e.key] ?? 0,
        mediumCount: categoryMedium[e.key] ?? 0,
      ));
    }
    categoryScores.sort((a, b) {
      final byPenalty = b.totalPenalty.compareTo(a.totalPenalty);
      if (byPenalty != 0) return byPenalty;
      return a.category.compareTo(b.category);
    });

    final dominantCategory =
        categoryScores.isNotEmpty ? categoryScores.first.category : '';

    final sortedByRule = List<RuleResult>.from(results)
      ..sort((a, b) {
        final byPenalty = b.penalty.compareTo(a.penalty);
        if (byPenalty != 0) return byPenalty;
        return a.ruleId.compareTo(b.ruleId);
      });
    final mostExpensiveRuleId =
        sortedByRule.isNotEmpty ? sortedByRule.first.ruleId : '';
    final mostExpensivePenalty =
        sortedByRule.isNotEmpty ? sortedByRule.first.penalty : 0.0;

    return CategoryAggregation(
      categoryScores: categoryScores,
      dominantCategory: dominantCategory,
      mostExpensiveRuleId: mostExpensiveRuleId,
      mostExpensivePenalty: mostExpensivePenalty,
      totalPenalty: totalPenalty,
    );
  }
}
