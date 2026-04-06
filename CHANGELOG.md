# Changelog

All notable changes to Flutter ScaleGuard are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.0]

### Added

- **scaleguard.yaml** — Primary optional config file: `feature_roots`, `ignore` (merged with defaults), `rules` toggles, `thresholds` (e.g. god file LOC), `score.fail_under` (0–100).
- **ScannerConfig.loadWithDiagnostics** — Returns config plus parse warnings; **ScannerConfig.load** unchanged and discards warnings.
- **Ignore semantics** — Literal patterns (substring / suffix match) vs path glob (`*`, `**` as path segments). See README.
- **Import graph** — Resolved project imports pointing at ignored files are omitted from rule-facing import lists (same ignore rules as file indexing).
- **CLI** — Prints config warnings to stderr (`Config: …`). Effective fail-under is `--fail-under` when passed, otherwise `score.fail_under` from file.

### Changed

- **Config precedence** — If both `scaleguard.yaml` and `risk_scanner.yaml` exist, only `scaleguard.yaml` is loaded; a warning notes that `risk_scanner.yaml` was ignored.
- **risk_scanner.yaml** — Still supported when it is the only config file; `ignored_patterns` continues to replace the default ignore list (not merged).

### JSON / reporting

- Disabled rules are **not** run and are **omitted** from `ruleResults` (no new JSON fields).

## [0.5.0]

Improve output usability and developer guidance:

- Add rule descriptions and suggestions
- Add Top Fix Priorities section
- Improve hotspot grouping and readability
- Enhance findings with actionable guidance
- Add CI usage tip

## [0.4.1]

### Added

- **Scan path in output header** — The console report now shows a "Scan Path:" line with the resolved absolute path used for the scan.

### Fixed

- **Project name display when scanning current directory** — When the resolved path is a root path (e.g. `/` on Unix or a drive root on Windows), the "Project:" line now shows a sensible fallback (`project`) instead of a blank name.
- **Apache license placeholders** — Placeholder text in license headers has been corrected.

### Documentation

- **README** — Improved with badges and clearer structure.

---

## [0.4.0]

### Documentation

- **README** — Restructured with Quick Start (global install and basic scan), Example Output (sample report with score and risk level), CI/Guardrail usage with `--fail-under`, Installation (global and from repo), Usage (basic scan, JSON, fail-under), Output section (Architecture Score, Risk Level table, Dominant Risk Category, Most Expensive Risk, Hotspots), Exit codes table (0, 1, 64), Configuration (risk_scanner.yaml options table), Rules overview (Cross Feature Coupling, Layer Violations, God Files, Hardcoded Scale Risks, Service Locator Abuse, Shared Boundary Leakage, Navigation Coupling), Design Principles, and When to Use ScaleGuard.

### Changed

- **pubspec.yaml** — Added `homepage`, `repository`, and `issue_tracker` URLs; added `topics` (flutter, architecture, cli, static-analysis, code-quality); description set to "Deterministic CLI for detecting architectural scale risks in Flutter projects."

---

## [0.4.0] - 2025-03-06

### Added

- **`--debug` flag** — Appends a "Debug Details" section to the console report with Penalty by Category, Penalty by Rule, Cap Hits, and Hotspot Metrics. Use with or without `--stats`. Output order: default report → Scan Stats (if `--stats`) → Debug Details (if `--debug`).
- **`--fail-under <0-100>`** — Exit code policy: if the architecture score is below the given threshold, the CLI prints a deterministic message and exits with code `2`. Invalid or missing value exits with `64`. Works with `--json`, `--stats`, and `--debug`. With `--json`, the fail-under message is written to stderr so stdout remains valid JSON.
- **Cap-hit note (default console)** — When any rule has reached its penalty cap, a single note line is printed after the Most Expensive Risk block (e.g. `Note: cross_feature_coupling reached its penalty cap (score may understate severity for this rule).`). Rule IDs are listed alphabetically; singular/plural wording is deterministic.
- **`--help` / `-h`** — Prints usage and exit codes (0, 2, 64, 1) and exits successfully.
- **JSON schema versioning** — The JSON report now includes top-level `toolVersion` (ScaleGuard version) and `schemaVersion: "1.0"` for stable schema identification. Keys are ordered with these first.

### Changed

- **Default console output** — Calibration and debug details are no longer shown by default. Penalty by Category, Penalty by Rule, capHits, and hotspotMetrics appear only when `--debug` is set. Default output is concise and audit-ready.
- **`--stats`** — Continues to show only scan meta (files scanned/ignored, imports resolved/total/external/unresolved). No penalties or model internals.
- **Console headings** — "Findings by Category", "Top Hotspots", and "Why This Matters" now use a trailing colon for consistency.
- **Fail-under in console mode** — When the fail-under threshold is not met, a separator (`---`) and a blank line are printed before the exit message for clearer readability.
- **Exit code documentation** — CLI `--help` and README document: `0` = scan succeeded (and passed `--fail-under` if provided); `2` = scan succeeded but `--fail-under` threshold not met; `64` = invalid usage / invalid project path; `1` = internal error.

### Documentation

- **README** — Exit codes section updated to the four codes above. Added a note under Output: when using `--json` with `--fail-under`, the message is on stderr so stdout stays valid JSON; on Windows PowerShell, stderr may appear as a command error even though the JSON (e.g. `out.json`) is valid.

### Internal

- Report model extended with optional `capHits`, `hotspotMetrics`, and `CategoryAggregation.penaltyByRule`; populated during scan for debug output and JSON. No scoring or rule-detection logic changed.
- Shared `ReportDebug` helper for computing capHits and hotspot metrics; used by scanner and JsonRenderer.
- Golden/snapshot and integration tests for default vs `--stats` vs `--debug` output, cap-hit note, fail-under behavior, JSON schema fields, and `--help`.

---

[0.5.0]: https://github.com/PavelK2254/flutter_scaleguard/releases/tag/v0.5.0
[0.4.1]: https://github.com/PavelK2254/flutter_scaleguard/releases/tag/v0.4.1
[0.4.0]: https://github.com/PavelK2254/flutter_scaleguard/releases/tag/v0.4.0
