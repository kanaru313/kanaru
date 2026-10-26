import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_rows.dart';
import '../../core/database/search_playlist_queries.dart';
import '../../l10n/l10n.dart';
import '../../shared/in_page_filter.dart';
import '../../shared/widgets/in_page_no_match.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import 'playlist_entry_tile.dart';

final _log = Logger('playlists');

/// The entries of a playlist whose song matches the filter, best match first,
/// as a sliver. They are read from the database (the page only holds a window
/// of the playlist), again when the terms or [refresh] change. Rows have no
/// drag handle or remove button: positions in a filtered list are not
/// positions in the playlist.
class PlaylistFilterResults extends StatefulWidget {
  const PlaylistFilterResults({
    super.key,
    required this.terms,
    required this.query,
    required this.refresh,
    required this.load,
    required this.onPlay,
    this.onEntryQueueAction,
    this.favorites = false,
  });

  /// The playlist is Favorites: missing entries show a heart.
  final bool favorites;

  final List<String> terms;

  /// What was typed, for the message when nothing matches.
  final String query;

  /// Changes (by identity) when the playlist was read again: the matches are
  /// read again too.
  final Object refresh;

  final Future<PlaylistMatches> Function(List<String> terms) load;

  /// A tap on row [index] of [rows], the entries as shown.
  final void Function(List<PlaylistEntryRow> rows, int index) onPlay;

  final void Function(PlaylistEntryRow entry, QueueAction action)?
  onEntryQueueAction;

  @override
  State<PlaylistFilterResults> createState() => _PlaylistFilterResultsState();
}

class _PlaylistFilterResultsState extends State<PlaylistFilterResults> {
  final _view = InPageFilterView<PlaylistEntryRow>(
    (e) => (
      title: e.track?.title ?? '',
      artist: e.track?.artist,
      album: e.track?.album,
    ),
  );

  /// The last answer, in playlist order.
  List<PlaylistEntryRow> _rows = const [];
  var _truncated = false;
  var _loading = true;

  /// The terms [_rows] answers.
  List<String>? _rowsTerms;

  /// Order of the reads; a stale answer is dropped.
  var _request = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  @override
  void didUpdateWidget(PlaylistFilterResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.refresh, widget.refresh) ||
        !listEquals(oldWidget.terms, widget.terms)) {
      unawaited(_read());
    }
  }

  Future<void> _read() async {
    final request = ++_request;
    final terms = widget.terms;
    _loading = true;
    try {
      final matches = await widget.load(terms);
      if (!mounted || request != _request) return;
      setState(() {
        _rows = [for (final m in matches.entries) m.entry];
        _rowsTerms = terms;
        _truncated = matches.truncated;
        _loading = false;
      });
    } catch (error, stack) {
      _log.warning('Filtering the playlist failed', error, stack);
      if (!mounted || request != _request) return;
      setState(() {
        _rows = const [];
        _rowsTerms = terms;
        _truncated = false;
        _loading = false;
      });
    }
  }

  /// The rows that match the current terms, best first. Once the answer is
  /// for these terms, rows the database matched on a hidden name follow.
  List<PlaylistEntryRow> _rank() {
    final ranked = _view.rank(_rows, widget.terms);
    if (!listEquals(_rowsTerms, widget.terms)) {
      return [for (final i in ranked) _rows[i]];
    }
    final seen = ranked.toSet();
    return [
      for (final i in ranked) _rows[i],
      for (var i = 0; i < _rows.length; i++)
        if (!seen.contains(i)) _rows[i],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final shown = _rank();
    if (shown.isEmpty) {
      return SliverToBoxAdapter(
        child: _loading
            ? const SizedBox.shrink()
            : InPageNoMatch(query: widget.query),
      );
    }
    final onEntryAction = widget.onEntryQueueAction;
    return SliverMainAxisGroup(
      slivers: [
        SliverPrototypeExtentList.builder(
          prototypeItem: PlaylistEntryTile(
            entry: prototypePlaylistEntry,
            index: 0,
            reorderable: false,
          ),
          itemCount: shown.length,
          itemBuilder: (context, i) {
            final entry = shown[i];
            return PlaylistEntryTile(
              key: ValueKey(entry.entryId),
              entry: entry,
              index: i,
              reorderable: false,
              favorites: widget.favorites,
              onTap: () => widget.onPlay(shown, i),
              onQueueAction: onEntryAction == null
                  ? null
                  : (action) => onEntryAction(entry, action),
            );
          },
        ),
        if (_truncated)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 12, 32, 4),
              child: Text(
                context.l10n.inPageSearchTooMany(_rows.length),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
