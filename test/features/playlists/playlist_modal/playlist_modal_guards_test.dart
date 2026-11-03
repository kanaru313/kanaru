import 'package:drift/drift.dart' show QueryExecutor, QueryInterceptor;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:kanaru/shared/m3u/m3u_save_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../library/browse_test_data.dart';
import '../../library/library_test_harness.dart';
import '../playlist_test_data.dart';
import 'playlist_modal_test_support.dart';

const _failure = "Couldn't save the playlist. See the log for details.";

/// Fails every UPDATE of a playlist while [failing] is set.
class _FailingUpdates extends QueryInterceptor {
  bool failing = false;

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (failing && statement.contains('"playlists"')) {
      throw StateError('write failed');
    }
    return executor.runUpdate(statement, args);
  }
}

void main() {
  late LibraryHarness h;
  late _FailingUpdates updates;
  final saved = <String>[];

  setUp(() {
    updates = _FailingUpdates();
    saved.clear();
    h = LibraryHarness(
      interceptor: updates,
      overrides: [
        m3uSavePickerProvider.overrideWithValue((name) async {
          saved.add(name);
          return null;
        }),
      ],
    );
  });

  Future<int> open(WidgetTester tester) async {
    await insertTracks(tester, h, const [TestTrack('a'), TestTrack('b')]);
    final id = await seedPlaylist(tester, h, 'Mix', ['a', 'b']);
    await pumpModalHost(tester, h, id: id);
    await openPlaylistModalOf(tester);
    return id;
  }

  testWidgets('a failed Edit save shows above the scrim, in the modal', (
    tester,
  ) async {
    await open(tester);
    await tapModalAction(tester, 'edit');
    await tester.enterText(
      find.byKey(const ValueKey('playlist-edit-name')),
      'Night drive',
    );
    updates.failing = true;
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settleModal(tester);

    final text = find.text(_failure);
    expect(text, findsOneWidget);
    final scaffold = tester.widget<Scaffold>(
      find.ancestor(of: text, matching: find.byType(Scaffold)).first,
    );
    expect(scaffold.backgroundColor, Colors.transparent, reason: 'modal route');
    expect(modalAction('edit'), findsOneWidget);
  });

  testWidgets('a second tap on Delete or Edit does not stack dialogs', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(modalAction('delete'));
    await tester.tap(modalAction('delete'), warnIfMissed: false);
    await settleModal(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleModal(tester);

    await tester.tap(modalAction('edit'));
    await tester.tap(modalAction('edit'), warnIfMissed: false);
    await settleModal(tester);
    expect(find.text('Edit playlist'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleModal(tester);

    // Both can be opened again once dismissed.
    await tapModalAction(tester, 'delete');
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('after the playlist is deleted elsewhere, actions are inert', (
    tester,
  ) async {
    final id = await open(tester);
    await tester.runAsync(() => h.db.deletePlaylist(id));
    await settleModal(tester);

    await tester.tap(find.byKey(const ValueKey('playlist-modal-play-next')));
    await tester.tap(modalAction('play-all'));
    await settleModal(tester);
    await tapModalAction(tester, 'advanced');
    await tester.tap(modalAction('duplicate'));
    await settleModal(tester);
    await tester.tap(modalAction('export-absolute'));
    await settleModal(tester);

    expect(queueTitles(h), isEmpty);
    expect(saved, isEmpty);
    final rows = await tester.runAsync(() => h.db.select(h.db.playlists).get());
    expect(rows, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
