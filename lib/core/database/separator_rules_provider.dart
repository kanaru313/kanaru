import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_provider.dart';
import 'separator_rules.dart';

/// How artist tags are split now, from the settings. Changes only when the
/// rules behave differently (reordering entries is not a change).
final artistSplitRulesProvider = Provider<SplitRules>((ref) {
  final split = ref.watch(
    settingsProvider.select((s) => s.libraryScan.artistSplit),
  );
  return SplitRules(separators: split.separators, keepWhole: split.keepWhole);
});

/// How stored genre strings are split now, from the settings.
final genreSplitRulesProvider = Provider<SplitRules>((ref) {
  final split = ref.watch(
    settingsProvider.select((s) => s.libraryScan.genreSplit),
  );
  return SplitRules(separators: split.separators, keepWhole: split.keepWhole);
});
