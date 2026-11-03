import 'package:flutter/widgets.dart' show VoidCallback;
import 'package:intl/intl.dart';

import '../../../core/database/history_rows.dart';
import '../../../core/m3u/m3u_write.dart' show M3uExportEntry;
import '../../../core/player/track.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/format_duration.dart' show formatDuration;
import '../../../shared/widgets/context_modal/context_modal_nav.dart';
import '../../../shared/widgets/library_row.dart' show rowLength;
import '../history_days.dart';
import '../history_day_queue.dart';

/// What the Day modal knows about its day: the plays the page showed for it
/// when the modal opened (a snapshot, never read again) and the library songs
/// among them, last played first. Every count and every action uses these two
/// lists, so what a row says is what it does.
class HistoryDayModalData {
  HistoryDayModalData({
    required this.day,
    required this.rows,
    required String? covers,
  }) : tracks = historyDayTracks(rows, covers);

  /// The local day, midnight.
  final DateTime day;

  /// The plays of the day as the page showed them, newest first.
  final List<HistoryPlayRow> rows;

  /// Library songs of [rows], each once at its latest play.
  final List<Track> tracks;

  /// Plays in the snapshot, songs missing from the library included.
  int get plays => rows.length;

  /// Library songs in the snapshot: the list the actions use.
  int get songs => tracks.length;

  /// Distinct songs of all the plays, those gone from the library included:
  /// the count the day bar shows.
  int get distinctSongs => {for (final r in rows) r.path}.length;

  /// Whether any play of the snapshot has a song to queue, play or export.
  bool get canQueue => tracks.isNotEmpty;

  /// Whether the snapshot holds a play to remove.
  bool get canRemove => rows.isNotEmpty;

  /// The play ids Remove deletes: exactly the snapshot.
  List<int> get playIds => [for (final r in rows) r.id];

  /// Time listened over the plays that know it; null when none does.
  int? get listenedMs {
    int? total;
    for (final r in rows) {
      final ms = r.listenedMs;
      if (ms != null) total = (total ?? 0) + ms;
    }
    return total != null && total > 0 ? total : null;
  }

  /// The M3U entries: [tracks] in order, as the queue takes them.
  List<M3uExportEntry> get exportEntries => [
    for (final t in tracks)
      M3uExportEntry(
        path: t.uri,
        title: t.title,
        artist: t.artist,
        durationMs: t.duration?.inMilliseconds,
      ),
  ];

  /// "Today", "Yesterday" or the weekday of [day], judged against [now].
  String title(AppLocalizations l10n, DateTime now) {
    final today = localDay(now);
    final d = localDay(day);
    if (d == today) return l10n.historyRangeToday;
    if (d == addDays(today, -1)) return l10n.historyDayYesterday;
    return DateFormat.EEEE(l10n.localeName).format(day);
  }

  /// "N listens • M songs • listened T"; the last part only when known.
  String statsLine(AppLocalizations l10n) {
    final ms = listenedMs;
    return [
      l10n.historyListenCount(plays),
      l10n.albumsSongCount(distinctSongs),
      if (ms != null) l10n.historyListened(_length(l10n, ms)),
    ].join(' • ');
  }

  static String _length(AppLocalizations l10n, int ms) => ms < 60000
      ? formatDuration(Duration(milliseconds: ms))
      : rowLength(l10n, ms);
}

/// What the Day modal's rows do. Each runs after the modal has closed except
/// [remove] (confirms above the modal first, then closes it).
class HistoryDayModalHandlers {
  const HistoryDayModalHandlers({
    required this.playAll,
    required this.shuffle,
    required this.addToPlaylist,
    required this.openInMostPlayed,
    required this.exportAbsolute,
    required this.exportRelative,
    required this.remove,
  });

  final VoidCallback playAll;
  final VoidCallback shuffle;
  final VoidCallback addToPlaylist;
  final VoidCallback openInMostPlayed;
  final VoidCallback exportAbsolute;
  final VoidCallback exportRelative;
  final void Function(ContextModalNav nav) remove;
}
