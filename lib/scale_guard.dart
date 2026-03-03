library scale_guard;

// Public API
export 'src/cli/runner.dart';
export 'src/core/scanner.dart';
export 'src/core/config.dart';
export 'src/core/index.dart';
export 'src/core/module_root.dart';
export 'src/model/category_aggregation.dart';
export 'src/model/finding.dart';
export 'src/model/rule_result.dart';
export 'src/model/scan_report.dart';
export 'src/model/scan_meta.dart';
export 'src/model/severity.dart';
export 'src/model/risk_level.dart';
export 'src/rules/rule.dart';
export 'src/rules/cross_feature_coupling.dart';
export 'src/rules/layer_violations.dart';
export 'src/rules/god_files.dart';
export 'src/rules/hardcoded_scale_risks.dart';
export 'src/rules/service_locator_abuse.dart';
export 'src/rules/shared_boundary_leakage.dart';
export 'src/rules/navigation_coupling.dart';
export 'src/scoring/scoring_engine.dart';
export 'src/render/console_renderer.dart';
export 'src/render/json_renderer.dart';
