# ScaleGuard

Flutter projects rarely fail because of missing features.  
They fail because early architectural shortcuts quietly compound into structural risk.

**Flutter ScaleGuard** is an opinionated, deterministic architecture risk scanner for Flutter teams preparing to scale.

It does not lint style.  
It does not measure cosmetic complexity.  
It evaluates structural decisions that increase long-term refactor cost, coupling, and growth friction.

ScaleGuard helps you understand:

- Is your architecture still scalable?
- Are feature boundaries leaking?
- Are layers crossing in ways that will hurt velocity later?
- Are you accumulating hidden structural debt?

Before your team grows.  
Before the codebase doubles.  
Before refactors become expensive.

## Example Output
```
Flutter ScaleGuard v0.1

Architecture Score: 57/100
Risk Level: Medium

Primary Structural Risks:

Cross Feature Coupling (12 findings)

Layer Violations (5 findings)

Most Expensive Risk:
Cross Feature Coupling (-18 points)

Suggested Direction:
Isolate feature boundaries and enforce layer abstractions.
```

## Install

```bash
dart pub global activate scale_guard
# or from this repo:
cd scale_guard && dart pub get
```

## Usage

```bash
# Scan a project (default: console report)
scale_guard scan /path/to/flutter_project

# JSON report
scale_guard scan /path/to/flutter_project --json
```

Or run directly:

```bash
dart run bin/scale_guard.dart scan .
dart run bin/scale_guard.dart scan . --json
```

## Output

- **Architecture Score**: 0–100 (100 = no penalties).
- **Risk Level**: Low (80–100), Medium (55–79), High (0–54).
- **Findings**: Categorized as High or Medium, with file, line (if applicable), and message.
- **Suggested next actions**: Rule IDs that produced findings.

Output order is deterministic (findings sorted by severity, then file path, then line).

## Exit codes

- `0`: Low or Medium risk.
- `1`: High risk.
- `64`: Invalid usage (e.g. missing `scan` or path).

## Configuration (optional)

Place `risk_scanner.yaml` in the project root to override defaults.

| Key | Description | Default |
|-----|-------------|---------|
| `feature_roots` | Paths under which feature folders live | `['lib/features']` |
| `layer_mappings` | Path segment → layer name (presentation/domain/data) | `presentation`, `domain`, `data` |
| `ignored_patterns` | Path substrings or suffixes to skip | `.g.dart`, `.freezed.dart`, `.gen.dart`, `/build/` |
| `god_file_medium_loc` | LOC threshold for medium “god file” finding | `500` |
| `god_file_high_loc` | LOC threshold for high “god file” finding | `900` |
| `shared_path_segments` | Path segments that denote shared/common (must not import features) | `['shared', 'common']` |
| `allowed_layer_dependencies` | From-layer → list of layers it may import | presentation→domain, data→domain |
| `service_locator_patterns` | Strings that indicate service locator / global access | GetIt, Provider.of, etc. |
| `route_constant_prefixes` | Prefixes that exempt route usage from “navigation coupling” | `Routes.`, `AppRoutes.` |
| `hardcoded_url_patterns` | Strings that indicate hardcoded URLs in non-data layers | `http://`, `https://`, `www.` |

All thresholds and rule weights/caps are defined in code: see `lib/src/core/config.dart` and `lib/src/scoring/scoring_engine.dart`.

## Rules (MVP)

1. **Cross Feature Coupling** – Feature folders importing other feature folders.
2. **Layer Violations** – Invalid imports between presentation, domain, data (e.g. presentation → data).
3. **God Files** – Files over LOC thresholds (medium/high).
4. **Hardcoded Scale Risks** – URLs/endpoints in presentation or domain.
5. **Service Locator / Global State** – GetIt, Provider.of, etc. in restricted layers.
6. **Shared Boundary Leakage** – shared/common importing feature code.
7. **Navigation Coupling** – Direct route strings instead of centralized navigation.

Scoring: start at 100; each rule contributes a penalty `min(cap, weight * risk_value)`; final score is clamped 0–100. Risk level from score bands above.

## License

Apache License 2.0. See [LICENSE](LICENSE) for the full text.
