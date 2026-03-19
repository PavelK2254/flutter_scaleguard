[![pub package](https://img.shields.io/pub/v/scale_guard.svg)](https://pub.dev/packages/scale_guard)
[![pub points](https://img.shields.io/pub/points/scale_guard)](https://pub.dev/packages/scale_guard/score)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

<img src="./assets/logo.png" width="200" alt="Flutter ScaleGuard">

# Flutter ScaleGuard

Architecture health check for Flutter apps.

**Flutter ScaleGuard** is a deterministic CLI tool that detects architectural risks in Flutter projects before they become expensive to fix.

Instead of focusing on style or formatting, ScaleGuard analyzes **structural architecture patterns** such as:

- cross-feature coupling
- layer boundary violations
- service locator abuse
- module hotspots
- configuration risks

It helps teams detect **architecture erosion early**, before it slows development.

---

# Quick Start

Install the CLI:

```bash
dart pub global activate scale_guard
```

Run a scan in your Flutter project:

```bash
scale_guard scan .
```

---

# Example Output

```text
Flutter ScaleGuard v0.5.0
Project: ./my_flutter_app
Scan Path: ./my_flutter_app

Architecture Score: 69/100
Risk Level: Medium

Summary:
This codebase shows early-stage coupling patterns that may reduce feature isolation as the team scales.

Dominant Risk Category: Coupling Risk (69% of total penalty)
Most Expensive Risk: Feature Module Imports Another Feature (reduces isolation and scaling flexibility) (-15.0) [Coupling Risk] [rule: cross_feature_coupling]
Hotspot (source): lib/features/user_profile (42 findings)
Examples:
  lib/features/user_profile/domain/usecase.dart lib/features/dashboard/repo.dart
  (+39 more)

---

Top Fix Priorities:

1. lib/features/user_profile
   - 42 findings
   - dominant: cross_feature_coupling
   - Avoid direct feature-to-feature imports.

2. lib/features/dashboard
   - 28 findings
   - dominant: cross_feature_coupling
   - Avoid direct feature-to-feature imports.


Hotspots:

lib/features/user_profile (42 findings)
  - cross_feature_coupling: 38
  - service_locator_abuse: 4

lib/features/dashboard (28 findings)
  - cross_feature_coupling: 22
  - hardcoded_scale_risks: 6

---

Findings by Category:

Coupling Risk
  - Feature Module Imports Another Feature (91 across 31 files)
  Features importing each other directly increases coupling and reduces scalability.
  Suggestion: Avoid direct feature-to-feature imports. Move shared contracts into a shared domain layer or introduce an abstraction.

  - Global Dependency Access Across Boundaries (34 across 15 files)
  Global dependency access hides dependencies and reduces architectural clarity.
  Suggestion: Limit service locator usage to composition roots. Inject dependencies explicitly into classes.

---

Tip:
Use ScaleGuard in CI to prevent architecture drift:
scale_guard scan . --fail-under 70
```

---

# CI / Guardrail Usage

ScaleGuard can be used to prevent architectural regressions in CI pipelines.

Example:

```bash
scale_guard scan . --fail-under 70
```

If the architecture score drops below the threshold, the command exits with a failure code.

This allows teams to enforce **architecture quality gates** automatically.

---

# Installation

Global install via Dart:

```bash
dart pub global activate scale_guard
```

Or run directly from the repository:

```bash
dart run bin/scale_guard.dart scan .
```

---

# Usage

Basic scan:

```bash
scale_guard scan .
```

JSON output:

```bash
scale_guard scan . --json
```

Fail if architecture score is too low:

```bash
scale_guard scan . --fail-under 70
```

---

# Output

ScaleGuard produces a structured report in this order:

### Architecture Score

Numeric score from **0–100**. Higher score means lower architectural risk.

### Risk Level

Risk classification based on score:

| Score | Risk Level |
|------|-------------|
| 80–100 | Low |
| 55–79 | Medium |
| 0–54 | High |

### Summary

A short summary of the dominant risk category and its impact.

### Dominant Risk Category

The architecture problem contributing most to the score penalty.

### Most Expensive Risk

The single rule responsible for the largest score reduction, with optional hotspot (source/target) and example findings.

### Top Fix Priorities

The top 3 modules (by finding count) with the most issues. For each, the report shows the path, total findings, the dominant rule, and a short actionable hint so you know **where to start fixing**.

### Hotspots

Modules grouped by path, with total findings and a **per-rule breakdown**. Shows where violations concentrate so you can focus refactoring effort.

### Findings by Category

Findings grouped by risk category. For each rule, the report includes:

- Count and file spread
- A **description** of the problem
- A **suggestion** on how to fix it

### CI Tip

A short tip at the end of the report on using ScaleGuard in CI to prevent architecture drift.

---

# Exit Codes

| Code | Meaning |
|-----|--------|
| 0 | Scan succeeded (and passed `--fail-under` if provided) |
| 1 | High risk (scan succeeded but risk level is High) |
| 2 | Scan succeeded but `--fail-under` threshold not met |
| 64 | Invalid usage / invalid project path (e.g., not a directory) |

---

# Configuration (optional)

ScaleGuard can be configured via a `risk_scanner.yaml` file in the project root.

Example configuration options:

| Key | Description | Default |
|----|-------------|--------|
| feature_roots | Paths where feature modules are located | `lib/features` |
| layer_mappings | Mapping of folders to architecture layers | presentation / domain / data |
| ignored_patterns | File patterns to exclude from analysis | generated files |
| god_file_medium_loc | LOC threshold for medium file size risk | 500 |
| god_file_high_loc | LOC threshold for high file size risk | 900 |

---

# Rules

ScaleGuard detects the following architecture risks. In the report, each rule includes a **description** (what’s wrong) and a **suggestion** (how to fix it).

### Cross Feature Coupling
Feature modules importing other feature modules. *Suggestion: move shared contracts into a shared domain layer or introduce an abstraction.*

### Layer Violations
Invalid dependencies between architecture layers (e.g. presentation → data). *Suggestion: ensure domain does not depend on data or presentation; move implementations behind interfaces.*

### God Files
Files exceeding defined size thresholds. *Suggestion: split into smaller focused components and separate responsibilities by layer or feature.*

### Hardcoded Scale Risks
Configuration values embedded directly in code. *Suggestion: move configuration to environment-based or external config files.*

### Service Locator Abuse
Global dependency access patterns. *Suggestion: limit usage to composition roots and inject dependencies explicitly.*

### Shared Boundary Leakage
Shared modules importing feature modules. *Suggestion: keep shared modules independent of features; depend on abstractions.*

### Navigation Coupling
Direct route usage instead of centralized navigation. *Suggestion: use a central router or navigation service.*

---

# Design Principles

ScaleGuard is intentionally designed to be:

**Deterministic**  
Same code always produces the same result.

**Fast**  
Scans large Flutter projects in seconds.

**Opinionated**  
Focused specifically on architectural scale risks.

**CLI-first**  
Simple tooling that integrates easily into CI pipelines.

---

# When to Use ScaleGuard

ScaleGuard is useful when:

- preparing a Flutter app for scale
- auditing an existing codebase
- reviewing architecture health during development
- preventing architecture decay in CI
- identifying refactoring hotspots

---

# Author

**Pavel Koifman**

Mobile Strategy & Architecture for Founders

Creator of **ScaleGuard** – Flutter architecture health check.

- GitHub: https://github.com/PavelK2254
- LinkedIn: https://www.linkedin.com/in/pavel-koifman/

---

# License

Apache License 2.0.

See the [LICENSE](LICENSE) file for details.
