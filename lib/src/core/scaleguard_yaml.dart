import 'package:yaml/yaml.dart';

import 'ignore_matcher.dart';
import 'rule_metadata.dart' show ruleIdToWeight;

const _knownTopLevel = {
  'feature_roots',
  'ignore',
  'rules',
  'thresholds',
  'score',
};

const _knownThresholdKeys = {
  'god_file_medium_loc',
  'god_file_high_loc',
};

const _knownScoreKeys = {'fail_under'};

/// Parsed `scaleguard.yaml` content (optional sections).
class ScaleguardParsed {
  const ScaleguardParsed({
    this.featureRoots,
    this.ignoreEntries = const [],
    this.ruleEnabled = const {},
    this.godFileMediumLoc,
    this.godFileHighLoc,
    this.failUnder,
  });

  final List<String>? featureRoots;
  final List<String> ignoreEntries;
  final Map<String, bool> ruleEnabled;
  final int? godFileMediumLoc;
  final int? godFileHighLoc;
  final int? failUnder;
}

/// Fills [warnings] for recoverable issues; never throws for content problems.
ScaleguardParsed parseScaleguardYaml(YamlMap yaml, List<String> warnings) {
  for (final key in yaml.keys) {
    final k = key.toString();
    if (!_knownTopLevel.contains(k)) {
      warnings.add('Unknown config key "$k" (ignored).');
    }
  }

  List<String>? featureRoots;
  final fr = yaml['feature_roots'];
  if (fr != null) {
    if (fr is YamlList) {
      featureRoots = fr.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      if (featureRoots.isEmpty) {
        warnings.add('feature_roots is empty; using default (lib/features).');
        featureRoots = null;
      }
    } else {
      warnings.add('feature_roots must be a list (ignored).');
    }
  }

  final ignoreEntries = <String>[];
  final ign = yaml['ignore'];
  if (ign != null) {
    if (ign is YamlList) {
      for (final e in ign) {
        final s = e.toString().trim();
        final err = validateIgnorePattern(s);
        if (err != null) {
          warnings.add('Invalid ignore pattern "$s": $err (skipped).');
          continue;
        }
        ignoreEntries.add(s);
      }
    } else {
      warnings.add('ignore must be a list (ignored).');
    }
  }

  final ruleEnabled = <String, bool>{};
  final rules = yaml['rules'];
  if (rules != null) {
    if (rules is YamlMap) {
      final known = ruleIdToWeight.keys.toSet();
      for (final e in rules.entries) {
        final id = e.key.toString();
        final v = e.value;
        if (!known.contains(id)) {
          warnings.add('Unknown rule id "$id" in rules (ignored).');
          continue;
        }
        if (v is! bool) {
          warnings.add('rules.$id must be a boolean (ignored).');
          continue;
        }
        ruleEnabled[id] = v;
      }
    } else {
      warnings.add('rules must be a map (ignored).');
    }
  }

  int? godMedium;
  int? godHigh;
  final th = yaml['thresholds'];
  if (th != null) {
    if (th is YamlMap) {
      for (final key in th.keys) {
        final k = key.toString();
        if (!_knownThresholdKeys.contains(k)) {
          warnings.add('Unknown thresholds key "$k" (ignored).');
        }
      }
      godMedium = _readOptionalInt(th['god_file_medium_loc'], 'thresholds.god_file_medium_loc', warnings);
      godHigh = _readOptionalInt(th['god_file_high_loc'], 'thresholds.god_file_high_loc', warnings);
    } else {
      warnings.add('thresholds must be a map (ignored).');
    }
  }

  int? failUnder;
  final score = yaml['score'];
  if (score != null) {
    if (score is YamlMap) {
      for (final key in score.keys) {
        final k = key.toString();
        if (!_knownScoreKeys.contains(k)) {
          warnings.add('Unknown score key "$k" (ignored).');
        }
      }
      final fu = _readOptionalInt(score['fail_under'], 'score.fail_under', warnings);
      if (fu != null) {
        if (fu < 0 || fu > 100) {
          warnings.add('score.fail_under must be between 0 and 100 (ignored).');
        } else {
          failUnder = fu;
        }
      }
    } else {
      warnings.add('score must be a map (ignored).');
    }
  }

  return ScaleguardParsed(
    featureRoots: featureRoots,
    ignoreEntries: ignoreEntries,
    ruleEnabled: ruleEnabled,
    godFileMediumLoc: godMedium,
    godFileHighLoc: godHigh,
    failUnder: failUnder,
  );
}

int? _readOptionalInt(dynamic v, String label, List<String> warnings) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  warnings.add('$label must be an integer (ignored).');
  return null;
}
