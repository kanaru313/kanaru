/// Which lyrics a song shows, as the user chose it. No choice (`null`, no
/// stored mode) means the fixed order: the stored pick, then the song's own
/// lyrics, then an automatic online lookup.
enum LyricsChoice {
  /// The song's own tags or `.lrc`; the order applies when it has none.
  local,

  /// The stored online pick; the order applies when the pick is unusable.
  online,

  /// No lyrics at all for the song.
  off,
}

/// Reads the stored mode string; `null` and unknown values read as no choice,
/// so a row written by a newer build never breaks an older one. `'off'` and
/// `'off:...'` (off, remembering the choice it replaced) read as [off].
LyricsChoice? parseLyricsChoice(String? mode) => switch (mode) {
  'local' => LyricsChoice.local,
  'online' => LyricsChoice.online,
  'off' => LyricsChoice.off,
  final m? when m.startsWith('off:') => LyricsChoice.off,
  _ => null,
};

/// The string stored for [choice].
String lyricsChoiceMode(LyricsChoice choice) => switch (choice) {
  LyricsChoice.local => 'local',
  LyricsChoice.online => 'online',
  LyricsChoice.off => 'off',
};

/// Stored when lyrics are turned off while the choice was [LyricsChoice.local],
/// so turning them back on restores it.
const offFromLocalMode = 'off:local';
