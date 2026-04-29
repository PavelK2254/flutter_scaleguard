import '../model/risk_level.dart';

class BaselineSummary {
  const BaselineSummary({
    required this.score,
    required this.riskLevel,
    required this.categoryPenalties,
    required this.findingsTotal,
    required this.findingsBySeverity,
    required this.topHotspots,
  });

  final int score;
  final RiskLevel riskLevel;
  final Map<String, double> categoryPenalties;
  final int findingsTotal;
  final Map<String, int> findingsBySeverity;
  final List<BaselineHotspot> topHotspots;
}

class BaselineHotspot {
  const BaselineHotspot({
    required this.path,
    required this.risk,
    this.loc,
  });

  final String path;
  final int risk;
  final int? loc;
}

class BaselineConfigSnapshot {
  const BaselineConfigSnapshot({
    required this.enabledRuleIds,
    required this.ignoreCount,
    required this.featureRoots,
  });

  final List<String> enabledRuleIds;
  final int ignoreCount;
  final List<String> featureRoots;
}

class ScaleGuardBaseline {
  const ScaleGuardBaseline({
    required this.baselineVersion,
    required this.createdAt,
    required this.summary,
    this.toolVersion,
    this.projectRelativePath,
    this.configSnapshot,
  });

  final int baselineVersion;
  final DateTime createdAt;
  final String? toolVersion;
  final String? projectRelativePath;
  final BaselineConfigSnapshot? configSnapshot;
  final BaselineSummary summary;
}

enum BaselineRiskDirection { up, down, same }

class CategoryDelta {
  const CategoryDelta({required this.category, required this.delta});

  final String category;
  final double delta;
}

enum HotspotChangeType { entered, exited, changed, unchanged }

class HotspotDelta {
  const HotspotDelta({
    required this.path,
    required this.changeType,
    required this.currentRisk,
    required this.baselineRisk,
  });

  final String path;
  final HotspotChangeType changeType;
  final int? currentRisk;
  final int? baselineRisk;
}

class FindingsDelta {
  const FindingsDelta({
    required this.totalDelta,
    required this.highDelta,
    required this.mediumDelta,
    required this.lowDelta,
  });

  final int totalDelta;
  final int highDelta;
  final int mediumDelta;
  final int lowDelta;
}

class BaselineComparison {
  const BaselineComparison({
    required this.scoreDelta,
    required this.riskDirection,
    required this.meaningful,
    required this.categoryDeltas,
    required this.hotspotDeltas,
    required this.findingsDelta,
    required this.hasConfigMismatch,
  });

  final int scoreDelta;
  final BaselineRiskDirection riskDirection;
  final bool meaningful;
  final List<CategoryDelta> categoryDeltas;
  final List<HotspotDelta> hotspotDeltas;
  final FindingsDelta findingsDelta;
  final bool hasConfigMismatch;
}
