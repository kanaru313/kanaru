import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/song_row.dart';
import '../../core/lyrics/online/lyrics_target.dart';

/// What Find lyrics online searches for; null (no row) for a song that is
/// not a local file, without the library row [song], or without a library,
/// where a pick could not be kept. A song without tags still gets a target:
/// the dialog starts with an empty query and the user types one.
LyricsTarget? menuLyricsTarget(WidgetRef ref, SongRow? song) {
  if (song == null || ref.read(libraryDatabaseProvider) == null) return null;
  final target = LyricsTarget.fromSongRow(song);
  return target.path == null ? null : target;
}
