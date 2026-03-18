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
final Map<String, String> ruleIdToCategory = Map.unmodifiable({
  'cross_feature_coupling': categoryCouplingRisk,
  'layer_violations': categoryStructuralRisk,
  'shared_boundary_leakage': categoryStructuralRisk,
  'god_files': categoryMaintainabilityRisk,
  'service_locator_abuse': categoryCouplingRisk,
  'hardcoded_scale_risks': categoryConfigReleaseRisk,
  'navigation_coupling': categoryCouplingRisk,
});

/// Maps each rule id to its weight. Single source of truth for scoring and JSON cap-hit reporting.
final Map<String, double> ruleIdToWeight = Map.unmodifiable({
  'cross_feature_coupling': 0.2,
  'layer_violations': 0.25,
  'shared_boundary_leakage': 0.1,
  'god_files': 0.15,
  'service_locator_abuse': 0.18,
  'hardcoded_scale_risks': 0.1,
  'navigation_coupling': 0.05,
});

/// Maps each rule id to its cap. Single source of truth for scoring and JSON cap-hit reporting.
final Map<String, double> ruleIdToCap = Map.unmodifiable({
  'cross_feature_coupling': 15.0,
  'layer_violations': 20.0,
  'shared_boundary_leakage': 10.0,
  'god_files': 12.0,
  'service_locator_abuse': 14.0,
  'hardcoded_scale_risks': 10.0,
  'navigation_coupling': 5.0,
});

/// Display labels for CLI output (business-relevant, impact-aware).
final Map<String, String> ruleIdToDisplayLabel = Map.unmodifiable({
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
});

/// One to two lines explaining the problem. Used for Findings by Category and Top Fix Priorities.
final Map<String, String> ruleIdToDescription = Map.unmodifiable({
  'cross_feature_coupling':
      'Features importing each other directly increases coupling and reduces scalability.',
  'service_locator_abuse':
      'Global dependency access hides dependencies and reduces architectural clarity.',
  'layer_violations':
      'Crossing layer boundaries increases coupling and makes refactoring harder.',
  'god_files':
      'Large files increase change surface and reduce maintainability.',
  'hardcoded_scale_risks':
      'Hardcoded configuration reduces flexibility across environments.',
  'shared_boundary_leakage':
      'Shared or common code importing feature modules blurs boundaries and increases coupling.',
  'navigation_coupling':
      'Direct route usage bypasses the routing layer and tightens screen coupling.',
});

/// One to three lines explaining how to fix. Empty string means skip suggestion line in output.
final Map<String, String> ruleIdToSuggestion = Map.unmodifiable({
  'cross_feature_coupling':
      'Avoid direct feature-to-feature imports. Move shared contracts into a shared domain layer or introduce an abstraction.',
  'service_locator_abuse':
      'Limit service locator usage to composition roots. Inject dependencies explicitly into classes.',
  'layer_violations':
      'Ensure domain does not depend on data or presentation. Move implementations behind interfaces.',
  'god_files':
      'Split large files into smaller focused components. Separate responsibilities by layer or feature.',
  'hardcoded_scale_risks':
      'Move configuration to environment-based or external config files. Avoid embedding runtime values in code.',
  'shared_boundary_leakage':
      'Keep shared modules independent of features. Depend on abstractions or invert dependencies.',
  'navigation_coupling':
      'Use a central router or navigation service. Avoid pushing named routes directly from feature code.',
});

/// Deterministic summary sentence per dominant category (standard intensity).
final Map<String, String> categoryToSummary = Map.unmodifiable({
  categoryCouplingRisk:
      'This codebase shows early-stage coupling patterns that may reduce feature isolation as the team scales.',
  categoryStructuralRisk:
      'Structural boundary violations are present and may increase future refactor complexity.',
  categoryMaintainabilityRisk:
      'File size and responsibility distribution suggest maintainability pressure as feature surface grows.',
  categoryConfigReleaseRisk:
      'Runtime configuration values are embedded in code, increasing release and environment risk.',
});

/// Softer summary sentence per dominant category (when score >= 90 or totalPenalty <= 8).
final Map<String, String> categoryToSummarySoft = Map.unmodifiable({
  categoryCouplingRisk:
      'Minor coupling signals are present; consider watching feature boundaries as the codebase grows.',
  categoryStructuralRisk:
      'Some structural boundaries could be clarified to reduce future refactor cost.',
  categoryMaintainabilityRisk:
      'A few files are on the larger side; splitting them may help as features grow.',
  categoryConfigReleaseRisk:
      'Some configuration is in code; externalizing it can ease releases and testing.',
});

/// Why-this-matters explanation per dominant category (standard intensity).
final Map<String, String> categoryToWhyStandard = Map.unmodifiable({
  categoryCouplingRisk:
      'Coupling and global access patterns reduce isolation, increasing coordination cost as the codebase grows.',
  categoryStructuralRisk:
      'Layer and boundary violations accumulate technical debt and make large refactors riskier. Clarifying boundaries now reduces future refactor complexity.',
  categoryMaintainabilityRisk:
      'Oversized files and unclear responsibility distribution increase review time and merge conflicts. Breaking them down early keeps feature delivery predictable.',
  categoryConfigReleaseRisk:
      'Hardcoded configuration ties the app to specific environments and makes releases and testing brittle. Externalizing config reduces release and environment risk.',
});

/// Softer why-this-matters explanation (when score >= 90 or totalPenalty <= 8).
final Map<String, String> categoryToWhySoft = Map.unmodifiable({
  categoryCouplingRisk:
      'Minor coupling and global access patterns can reduce isolation over time; watching feature boundaries helps keep coordination cost manageable as the codebase grows.',
  categoryStructuralRisk:
      'Minor boundary erosion reduces isolation over time; keeping layers clean helps prevent refactor complexity as the project grows.',
  categoryMaintainabilityRisk:
      'A few larger files can increase review time and merge risk; splitting them early helps keep feature delivery predictable.',
  categoryConfigReleaseRisk:
      'Some configuration in code can tie the app to environments and make testing harder; externalizing it eases releases and reduces environment risk.',
});
