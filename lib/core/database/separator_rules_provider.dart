import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_provider.dart';
import 'separator_rules.dart';

/// How artist tags are split now, from the settings. Changes only when the
/// rules behave differently (reordering entries is not a change).
final artistSplitRulesProvider = Provider<SplitRules>((ref) {
  final split = ref.watch(
    settingsProvider.select((s) => s.libraryScan.artistSplit),
  );
  return _rulesOf(split);
});

/// How stored genre strings are split now, from the settings.
final genreSplitRulesProvider = Provider<SplitRules>((ref) {
  final split = ref.watch(
    settingsProvider.select((s) => s.libraryScan.genreSplit),
  );
  return _rulesOf(split);
});

/// Rules from [split] after the same clean-up the stored settings get, so the
/// rules of this session equal the ones after a restart.
SplitRules _rulesOf(SplitPrefs split) => SplitRules(
  separators: cleanSplitEntries(split.separators),
  keepWhole: cleanSplitEntries(split.keepWhole),
);
