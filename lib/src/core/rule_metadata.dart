/// Risk categories for grouping architecture rules.
const String categoryStructuralRisk = 'Structural Risk';
const String categoryCouplingRisk = 'Coupling Risk';
const String categoryMaintainabilityRisk = 'Maintainability Risk';
const String categoryConfigReleaseRisk = 'Configuration / Release Risk';

/// All category names in deterministic order (for display).
const List<String> allCategories = [
  categoryConfigReleaseRisk,
  categoryCouplingRisk,
  categoryMaintainabilityRisk,
  categoryStructuralRisk,
];

/// Maps each rule id to exactly one risk category.
final Map<String, String> ruleIdToCategory = {
  'cross_feature_coupling': categoryCouplingRisk,
  'layer_violations': categoryStructuralRisk,
  'shared_boundary_leakage': categoryStructuralRisk,
  'god_files': categoryMaintainabilityRisk,
  'service_locator_abuse': categoryCouplingRisk,
  'hardcoded_scale_risks': categoryConfigReleaseRisk,
  'navigation_coupling': categoryCouplingRisk,
};

/// Maps each rule id to its weight (for JSON cap-hit reporting only).
final Map<String, double> ruleIdToWeight = {
  'cross_feature_coupling': 0.2,
  'layer_violations': 0.25,
  'shared_boundary_leakage': 0.1,
  'god_files': 0.15,
  'service_locator_abuse': 0.18,
  'hardcoded_scale_risks': 0.1,
  'navigation_coupling': 0.05,
};

/// Maps each rule id to its cap (for JSON cap-hit reporting only).
final Map<String, double> ruleIdToCap = {
  'cross_feature_coupling': 15,
  'layer_violations': 20,
  'shared_boundary_leakage': 10,
  'god_files': 12,
  'service_locator_abuse': 14,
  'hardcoded_scale_risks': 10,
  'navigation_coupling': 5,
};

/// Display labels for CLI output (business-relevant, impact-aware).
final Map<String, String> ruleIdToDisplayLabel = {
  'cross_feature_coupling':
      'Feature Module Imports Another Feature (reduces isolation and scaling flexibility)',
  'layer_violations':
      'Layer Boundary Crossed (may increase coupling and future refactor cost)',
  'shared_boundary_leakage':
      'Shared Boundary Leakage (blurs module boundaries and increases coupling)',
  'god_files':
      'Oversized File (increases change surface and review complexity)',
  'service_locator_abuse':
      'Global Dependency Access Across Boundaries (reduces architectural clarity)',
  'hardcoded_scale_risks':
      'Runtime Configuration Embedded in Code (increases release and environment risk)',
  'navigation_coupling':
      'Navigation Logic Bypasses Routing Layer (tightens screen coupling)',
};

/// Deterministic summary sentence per dominant category (standard intensity).
final Map<String, String> categoryToSummary = {
  categoryCouplingRisk:
      'This codebase shows early-stage coupling patterns that may reduce feature isolation as the team scales.',
  categoryStructuralRisk:
      'Structural boundary violations are present and may increase future refactor complexity.',
  categoryMaintainabilityRisk:
      'File size and responsibility distribution suggest maintainability pressure as feature surface grows.',
  categoryConfigReleaseRisk:
      'Runtime configuration values are embedded in code, increasing release and environment risk.',
};

/// Softer summary sentence per dominant category (when score >= 90 or totalPenalty <= 8).
final Map<String, String> categoryToSummarySoft = {
  categoryCouplingRisk:
      'Minor coupling signals are present; consider watching feature boundaries as the codebase grows.',
  categoryStructuralRisk:
      'Some structural boundaries could be clarified to reduce future refactor cost.',
  categoryMaintainabilityRisk:
      'A few files are on the larger side; splitting them may help as features grow.',
  categoryConfigReleaseRisk:
      'Some configuration is in code; externalizing it can ease releases and testing.',
};

/// Why-this-matters explanation per dominant category (standard intensity).
final Map<String, String> categoryToWhyStandard = {
  categoryCouplingRisk:
      'Coupling and global access patterns reduce isolation, increasing coordination cost as the codebase grows.',
  categoryStructuralRisk:
      'Layer and boundary violations accumulate technical debt and make large refactors riskier. Clarifying boundaries now reduces future refactor complexity.',
  categoryMaintainabilityRisk:
      'Oversized files and unclear responsibility distribution increase review time and merge conflicts. Breaking them down early keeps feature delivery predictable.',
  categoryConfigReleaseRisk:
      'Hardcoded configuration ties the app to specific environments and makes releases and testing brittle. Externalizing config reduces release and environment risk.',
};

/// Softer why-this-matters explanation (when score >= 90 or totalPenalty <= 8).
final Map<String, String> categoryToWhySoft = {
  categoryCouplingRisk:
      'Minor coupling and global access patterns can reduce isolation over time; watching feature boundaries helps keep coordination cost manageable as the codebase grows.',
  categoryStructuralRisk:
      'Minor boundary erosion reduces isolation over time; keeping layers clean helps prevent refactor complexity as the project grows.',
  categoryMaintainabilityRisk:
      'A few larger files can increase review time and merge risk; splitting them early helps keep feature delivery predictable.',
  categoryConfigReleaseRisk:
      'Some configuration in code can tie the app to environments and make testing harder; externalizing it eases releases and reduces environment risk.',
};
