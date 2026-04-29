import 'dart:io';

import 'package:scale_guard/src/baseline/baseline_model.dart';
import 'package:scale_guard/src/baseline/baseline_store.dart';
import 'package:scale_guard/src/model/risk_level.dart';
import 'package:test/test.dart';

void main() {
  test('save then load baseline round-trip', () async {
    final dir = await Directory.systemTemp.createTemp('sg_baseline_store_');
    addTearDown(() => dir.delete(recursive: true));
    final baselinePath = BaselineStore.baselinePathForProject(dir.path);
    final baseline = ScaleGuardBaseline(
      baselineVersion: 1,
      createdAt: DateTime.utc(2026, 1, 1),
      toolVersion: '0.7.0',
      projectRelativePath: '.',
      configSnapshot: const BaselineConfigSnapshot(
        enabledRuleIds: ['cross_feature_coupling'],
        ignoreCount: 2,
        featureRoots: ['lib/features'],
      ),
      summary: const BaselineSummary(
        score: 80,
        riskLevel: RiskLevel.medium,
        categoryPenalties: {'Coupling Risk': 2.0},
        findingsTotal: 3,
        findingsBySeverity: {'high': 1, 'medium': 2, 'low': 0},
        topHotspots: [BaselineHotspot(path: 'lib/features/a', risk: 2)],
      ),
    );

    await BaselineStore.save(baselinePath, baseline);
    final loaded = await BaselineStore.load(baselinePath);

    expect(loaded.warning, isNull);
    expect(loaded.baseline, isNotNull);
    expect(loaded.baseline!.summary.score, 80);
    expect(loaded.baseline!.summary.riskLevel, RiskLevel.medium);
    expect(loaded.baseline!.configSnapshot!.ignoreCount, 2);
  });

  test('load warns on missing baseline', () async {
    final result = await BaselineStore.load('missing/path/baseline.json');
    expect(result.baseline, isNull);
    expect(result.warning, contains('Baseline not found'));
  });

  test('load warns on invalid JSON', () async {
    final dir = await Directory.systemTemp.createTemp('sg_baseline_invalid_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/baseline.json');
    await file.writeAsString('{invalid');

    final result = await BaselineStore.load(file.path);
    expect(result.baseline, isNull);
    expect(result.warning, contains('Invalid baseline JSON'));
  });

  test('load warns on unsupported version', () async {
    final dir = await Directory.systemTemp.createTemp('sg_baseline_ver_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/baseline.json');
    await file.writeAsString('''
{
  "baselineVersion": 99,
  "createdAt": "2026-01-01T00:00:00.000Z",
  "summary": {
    "score": 80,
    "riskLevel": "Medium",
    "categoryPenalties": {},
    "findings": {"total": 0, "bySeverity": {"high": 0, "medium": 0, "low": 0}}
  }
}
''');

    final result = await BaselineStore.load(file.path);
    expect(result.baseline, isNull);
    expect(result.warning, contains('Unsupported baselineVersion'));
  });
}
