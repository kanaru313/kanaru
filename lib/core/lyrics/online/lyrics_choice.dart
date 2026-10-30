/// Which lyrics a song shows, as the user chose it. No stored row means
/// [auto].
enum LyricsChoice {
  /// Local lyrics, then the online cache, then an automatic lookup.
  auto,

  /// The song's own tags or `.lrc`; automatic when it has none.
  local,

  /// The stored online pick; automatic when the pick is unusable.
  online,

  /// No lyrics at all for the song.
  off,
}

/// Reads the stored mode string; `null` and unknown values read as [auto],
/// so a row written by a newer build never breaks an older one.
LyricsChoice parseLyricsChoice(String? mode) => switch (mode) {
  'local' => LyricsChoice.local,
  'online' => LyricsChoice.online,
  'off' => LyricsChoice.off,
  _ => LyricsChoice.auto,
};

/// The string stored for [choice]; [LyricsChoice.auto] has no row.
String? lyricsChoiceMode(LyricsChoice choice) => switch (choice) {
  LyricsChoice.auto => null,
  LyricsChoice.local => 'local',
  LyricsChoice.online => 'online',
  LyricsChoice.off => 'off',
};
