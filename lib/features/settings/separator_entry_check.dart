import '../../core/settings/library_scan_prefs.dart';

/// Why a typed entry cannot join a separator list.
enum SeparatorEntryProblem { empty, full, tooLong, duplicate }

/// The outcome of [checkSeparatorEntry]: the [entry] to add (trimmed), or the
/// [problem] that stops it. Exactly one of the two is set.
class SeparatorEntryCheck {
  const SeparatorEntryCheck.accepted(String this.entry) : problem = null;
  const SeparatorEntryCheck.rejected(SeparatorEntryProblem this.problem)
    : entry = null;

  final String? entry;
  final SeparatorEntryProblem? problem;
}

/// Checks [input] against the list it would join, with the limits the
/// settings file applies on load ([maxSplitEntries], [maxSplitEntryLength]),
/// so what is accepted here survives a restart. Whitespace around the input
/// is dropped; a repeat is spotted in any case, as the file does.
SeparatorEntryCheck checkSeparatorEntry(String input, List<String> existing) {
  final entry = input.trim();
  if (entry.isEmpty) {
    return const SeparatorEntryCheck.rejected(SeparatorEntryProblem.empty);
  }
  if (existing.length >= maxSplitEntries) {
    return const SeparatorEntryCheck.rejected(SeparatorEntryProblem.full);
  }
  if (entry.runes.length > maxSplitEntryLength) {
    return const SeparatorEntryCheck.rejected(SeparatorEntryProblem.tooLong);
  }
  final key = entry.toLowerCase();
  if (existing.any((e) => e.toLowerCase() == key)) {
    return const SeparatorEntryCheck.rejected(SeparatorEntryProblem.duplicate);
  }
  return SeparatorEntryCheck.accepted(entry);
}
