import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_rows.dart';
import 'package:kanaru/core/database/playlist_rows.dart';
import 'package:kanaru/features/playlists/playlist_entries_view.dart';
import 'package:kanaru/features/playlists/playlist_entry_tile.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

/// An entry whose file is a library track titled `T<id>`.
PlaylistEntryRow available(int id) => PlaylistEntryRow(
  entryId: id,
  path: '/music/t$id.flac',
  track: TrackListItem(
    id: id,
    path: '/music/t$id.flac',
    title: 'T$id',
    artist: 'Artist $id',
    album: 'Album $id',
    durationMs: 61000 + id * 1000,
  ),
);

/// An entry whose file is not in the library.
PlaylistEntryRow missing(int id) =>
    PlaylistEntryRow(entryId: id, path: '/gone/lost$id.mp3');

/// The header data of a playlist holding [entries], as the database would
/// give it.
PlaylistPageHead headOf(
  List<PlaylistEntryRow> entries, {
  String name = 'Mix',
  bool favorites = false,
}) => PlaylistPageHead(
  playlist: PlaylistSummary(
    id: 7,
    name: name,
    createdAt: 1,
    entryCount: entries.length,
    isFavorites: favorites,
  ),
  coverKeys: const [],
  hasPlayable: entries.any((e) => e.track != null),
);

/// A [PlaylistEntriesView] in an app shell over an in-memory "database"
/// ([store]) that records every callback. A move or removal that completes
/// with true is applied to [store], as the real write would be; the view
/// shows the stored state again only when [reloadHead] hands it a new head,
/// as the screen does after `onSettled`.
class EntriesViewHarness {
  /// What the "database" holds, in order.
  var store = <PlaylistEntryRow>[];

  /// Every row read: start and count.
  var loads = <(int, int)>[];
  var moves = <(int, int)>[];
  var removed = <int>[];
  var renamed = 0;
  var deleted = 0;
  var settled = 0;

  /// Every play: the entry id (null for the first playable) and the index
  /// hint.
  var played = <(int?, int)>[];
  var moveResult = Completer<bool>();
  var removeResult = Completer<bool>();

  /// When set, a move throws this instead of waiting for [moveResult].
  Object? moveError;

  /// Highest `seq` handed to the view so far; a head read later gets more.
  var seqCounter = 0;

  /// What `onSettled` last returned: heads below it are ignored.
  var minSeq = 0;

  bool _readOnly = false;
  void Function(QueueAction)? _onQueueAction;
  void Function(PlaylistEntryRow, QueueAction)? _onEntryQueueAction;

  /// Clears what was recorded; call from `setUp`.
  void reset() {
    store = [];
    loads = [];
    moves = [];
    removed = [];
    renamed = deleted = settled = seqCounter = minSeq = 0;
    played = [];
    moveResult = Completer<bool>();
    removeResult = Completer<bool>();
    moveError = null;
  }

  Future<List<PlaylistPositionedEntry>> _loadRows(int start, int count) async {
    loads.add((start, count));
    return [
      for (var i = start; i < start + count && i < store.length; i++)
        PlaylistPositionedEntry(i, store[i]),
    ];
  }

  Widget _app(PlaylistPageHead head, int seq) => ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PlaylistEntriesView(
          head: head,
          headSeq: seq,
          loadRows: _loadRows,
          onMove: _readOnly
              ? null
              : (id, to) {
                  moves.add((id, to));
                  final error = moveError;
                  if (error != null) return Future.error(error);
                  return moveResult.future.then((ok) {
                    if (ok) {
                      final from = store.indexWhere((e) => e.entryId == id);
                      store.insert(to, store.removeAt(from));
                    }
                    return ok;
                  });
                },
          onRemove: _readOnly
              ? null
              : (id) {
                  removed.add(id);
                  return removeResult.future.then((ok) {
                    if (ok) store.removeWhere((e) => e.entryId == id);
                    return ok;
                  });
                },
          onSettled: _readOnly
              ? null
              : () {
                  settled++;
                  return minSeq = seqCounter + 1;
                },
          onPlayFrom: (id, hint) async => played.add((id, hint)),
          onQueueAction: _onQueueAction,
          onEntryQueueAction: _onEntryQueueAction,
          onRename: () => renamed++,
          onDelete: () => deleted++,
        ),
      ),
    ),
  );

  /// Shows a playlist holding [entries] (also the "database" content).
  Future<void> pump(
    WidgetTester tester,
    List<PlaylistEntryRow> entries, {
    double width = 1280,
    bool readOnly = false,
    bool favorites = false,
    String name = 'Mix',
    void Function(QueueAction)? onQueueAction,
    void Function(PlaylistEntryRow, QueueAction)? onEntryQueueAction,
  }) async {
    store = [...entries];
    _readOnly = readOnly;
    _onQueueAction = onQueueAction;
    _onEntryQueueAction = onEntryQueueAction;
    tester.view
      ..physicalSize = Size(width, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(headOf(entries, favorites: favorites, name: name), ++seqCounter),
    );
    await tester.pumpAndSettle();
  }

  /// Gives the view [head] read with order number [seq] (a later read than
  /// any so far when null).
  Future<void> showHead(
    WidgetTester tester,
    PlaylistPageHead head, {
    int? seq,
  }) async {
    await tester.pumpWidget(_app(head, seq ?? ++seqCounter));
    await tester.pumpAndSettle();
  }

  /// A new head read from [store] after the writes ended.
  Future<void> reloadHead(WidgetTester tester) =>
      showHead(tester, headOf(store));

  /// Completes the pending move and lets the view react.
  Future<void> finishMove(WidgetTester tester, {required bool ok}) async {
    // Pointer handlers run outside the fake zone, so the continuation
    // after the move needs the real event loop to run.
    await tester.runAsync(() async => moveResult.complete(ok));
    await tester.pumpAndSettle();
  }

  /// Completes the pending removal and lets the view react.
  Future<void> finishRemove(WidgetTester tester, {required bool ok}) async {
    await tester.runAsync(() async => removeResult.complete(ok));
    await tester.pumpAndSettle();
  }

  /// Entry ids top to bottom, as laid out.
  List<int> shownIds(WidgetTester tester) {
    final tiles = tester.widgetList<PlaylistEntryTile>(
      find.byType(PlaylistEntryTile),
    );
    final byY = {
      for (final tile in tiles)
        tester.getTopLeft(find.byWidget(tile)).dy: tile.entry.entryId,
    };
    return [for (final y in byY.keys.toList()..sort()) byY[y]!];
  }

  Finder handle(int row) => find.descendant(
    of: find.byType(PlaylistEntryTile).at(row),
    matching: find.byIcon(Icons.drag_handle_rounded),
  );

  /// Drags a handle by [dy] in small steps so the list sees every row.
  Future<void> dragHandle(WidgetTester tester, Finder handle, double dy) async {
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    final step = dy.sign * 8;
    for (var moved = 0.0; moved.abs() < dy.abs(); moved += step) {
      await gesture.moveBy(Offset(0, step));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }
}
