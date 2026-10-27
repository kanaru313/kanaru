/// What happens at the end of a track: stop after the last one, wrap around
/// the whole queue (also in a fresh random order for every pass), or play the
/// same track again.
enum RepeatMode {
  off,
  all,
  one,
  allShuffled;

  /// Playing on past the last track goes back to the first.
  bool get wrapsQueue => this == all || this == allShuffled;
}

/// Most extra plays of the current track a counted repeat can ask for.
const maxRepeatTimes = 99;
