# ScaleGuard Example

Install:

```bash
dart pub global activate scale_guard
```

Run inside a Flutter project:

```bash
scale_guard scan .
```

Run with JSON output:

```bash
scale_guard scan . --json
```

Run with a minimum score threshold:

```bash
scale_guard scan . --fail-under 70
```

