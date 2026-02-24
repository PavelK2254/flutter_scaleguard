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

/// Deterministic summary sentence per dominant category.
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

/// Why-this-matters explanation per dominant category.
final Map<String, String> categoryToWhyItMatters = {
  categoryCouplingRisk:
      'Coupling between features and global access patterns make it harder to change one area without affecting others. Addressing these early improves feature velocity and reduces refactor cost.',
  categoryStructuralRisk:
      'Layer and boundary violations accumulate technical debt and make large refactors riskier. Clarifying boundaries now reduces future refactor complexity.',
  categoryMaintainabilityRisk:
      'Oversized files and unclear responsibility distribution increase review time and merge conflicts. Breaking them down early keeps feature delivery predictable.',
  categoryConfigReleaseRisk:
      'Hardcoded configuration ties the app to specific environments and makes releases and testing brittle. Externalizing config reduces release and environment risk.',
};
