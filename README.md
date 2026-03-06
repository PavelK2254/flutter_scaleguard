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

Console report (default) shows the CLI version (from `pubspec.yaml`), score, risk level, summary, dominant risk category, most expensive rule with hotspots and examples, findings by category, top hotspots, and a “Why This Matters” note. Example:

```
Flutter ScaleGuard v0.3.0
Project: /path/to/your/flutter_project

Architecture Score: 57/100
Risk Level: Medium

Summary:
This codebase shows early-stage coupling patterns that may reduce feature isolation as the team scales.

Dominant Risk Category: Coupling Risk (62% of total penalty)
Most Expensive Risk: Feature Module Imports Another Feature (reduces isolation and scaling flexibility) (-18) [Coupling Risk] [rule: cross_feature_coupling]
Hotspot (source): lib/features/auth (5 findings)
Hotspot (target): lib/features/profile (4 findings)
Examples:
  lib/features/auth/login/login_screen.dart:12 auth -> profile lib/features/profile/profile_repository.dart
  lib/features/auth/signup/signup_bloc.dart:8 auth -> profile lib/features/profile/models/user.dart
  (+3 more)

---

Findings by Category

Coupling Risk
  - Feature Module Imports Another Feature (reduces isolation and scaling flexibility) (12 across 4 files)
  - Layer Boundary Crossed (may increase coupling and future refactor cost) (5 across 3 files)

---

Top Hotspots

lib/features/auth (8 findings)
lib/features/profile (6 findings)

---

Why This Matters
Coupling and global access patterns reduce isolation, increasing coordination cost as the codebase grows.
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

When using `--json` with `--fail-under`, the fail-under message is printed to stderr so stdout remains valid JSON. On Windows PowerShell, stderr may be displayed as a command error even though the JSON written to stdout (e.g. `out.json`) is valid.
- **Risk Level**: Low (80–100), Medium (55–79), High (0–54).
- **Findings**: Categorized as High or Medium, with file, line (if applicable), and message.
- **Suggested next actions**: Rule IDs that produced findings.

Output order is deterministic (findings sorted by severity, then file path, then line).

## Exit codes

- **0** — Scan succeeded (and passed `--fail-under` if provided).
- **2** — Scan succeeded but `--fail-under` threshold not met.
- **64** — Invalid usage / invalid project path (e.g., path missing or not a directory).
- **1** — High risk (scan succeeded but risk level is High).

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

## Development

- **Version display**  
  The banner shows the package version (e.g. `Flutter ScaleGuard v0.3.0`). At runtime the version is read from `pubspec.yaml` when possible; a fallback in `lib/src/version.dart` is used for AOT or when the package root cannot be resolved. Keep that fallback in sync with `pubspec.yaml` so the displayed version is always correct.

- **Syncing the version after a release bump**  
  After bumping `version` in `pubspec.yaml`, update the fallback constant in code:

  ```bash
  dart run tool/update_version.dart
  ```

  This script reads the version from `pubspec.yaml` and rewrites `fallbackPackageVersion` in `lib/src/version.dart`.

## License

Apache License 2.0. See [LICENSE](LICENSE) for the full text.
