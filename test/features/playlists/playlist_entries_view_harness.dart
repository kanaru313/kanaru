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

PlaylistPage pageOf(List<PlaylistEntryRow> entries, {String name = 'Mix'}) =>
    PlaylistPage(
      playlist: PlaylistSummary(
        id: 7,
        name: name,
        createdAt: 1,
        entryCount: entries.length,
      ),
      entries: entries,
    );

/// A [PlaylistEntriesView] in an app shell that records every callback.
class EntriesViewHarness {
  var moves = <(int, int)>[];
  var removed = <int>[];
  var renamed = 0;
  var deleted = 0;
  List<PlaylistEntryRow>? playedRows;
  int? playedIndex;
  var moveResult = Completer<bool>();

  /// When set, a move throws this instead of waiting for [moveResult].
  Object? moveError;

  /// Clears what was recorded; call from `setUp`.
  void reset() {
    moves = [];
    removed = [];
    renamed = deleted = 0;
    playedRows = playedIndex = null;
    moveResult = Completer<bool>();
    moveError = null;
  }

  Future<void> pump(
    WidgetTester tester,
    PlaylistPage page, {
    double width = 1280,
    ValueChanged<QueueAction>? onQueueAction,
    void Function(PlaylistEntryRow, QueueAction)? onEntryQueueAction,
  }) {
    tester.view
      ..physicalSize = Size(width, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PlaylistEntriesView(
              page: page,
              onMove: (id, to) {
                moves.add((id, to));
                final error = moveError;
                if (error != null) return Future.error(error);
                return moveResult.future;
              },
              onRemove: removed.add,
              onPlayFrom: (shown, index) {
                playedRows = shown;
                playedIndex = index;
              },
              onQueueAction: onQueueAction,
              onEntryQueueAction: onEntryQueueAction,
              onRename: () => renamed++,
              onDelete: () => deleted++,
            ),
          ),
        ),
      ),
    );
  }

  /// Completes the pending move and lets the view react.
  Future<void> finishMove(WidgetTester tester, {required bool ok}) async {
    // Pointer handlers run outside the fake zone, so the continuation
    // after the move needs the real event loop to run.
    await tester.runAsync(() async => moveResult.complete(ok));
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
