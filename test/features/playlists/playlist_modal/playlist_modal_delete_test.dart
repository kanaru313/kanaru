import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:material_ui/material_ui.dart';

import '../../library/browse_test_data.dart';
import '../../library/library_test_harness.dart';
import '../playlist_test_data.dart';
import 'playlist_modal_test_support.dart';

final _confirm = find.widgetWithText(AlertDialog, 'Delete “Mix”?');

void main() {
  late LibraryHarness h;
  late int id;
  late ModalHost host;

  setUp(() => h = LibraryHarness());

  Future<void> open(WidgetTester tester) async {
    await insertTracks(tester, h, const [TestTrack('a'), TestTrack('b')]);
    id = await seedPlaylist(tester, h, 'Mix', ['a', 'b']);
    host = await pumpModalHost(tester, h, id: id);
    await openPlaylistModalOf(tester);
    await tapModalAction(tester, 'delete');
  }

  Future<bool> stillStored(WidgetTester tester) async {
    final rows = await tester.runAsync(
      () => h.db.watchPlaylistSummaries().first,
    );
    return rows!.any((p) => p.id == id);
  }

  testWidgets('the confirm opens above the modal, which stays', (tester) async {
    await open(tester);
    expect(_confirm, findsOneWidget);
    expect(modalAction('delete'), findsOneWidget);
    expect(host.location, '/');
    expect(await stillStored(tester), isTrue);
  });

  testWidgets('Cancel goes back to the modal', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await settleModal(tester);

    expect(_confirm, findsNothing);
    expect(modalAction('delete'), findsOneWidget);
    expect(await stillStored(tester), isTrue);
  });

  testWidgets('Esc and a tap outside also only dismiss the confirm', (
    tester,
  ) async {
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleModal(tester);
    expect(_confirm, findsNothing);
    expect(modalAction('delete'), findsOneWidget);

    await tapModalAction(tester, 'delete');
    await tester.tapAt(const Offset(4, 4));
    await settleModal(tester);
    expect(_confirm, findsNothing);
    expect(modalAction('delete'), findsOneWidget);
    expect(await stillStored(tester), isTrue);
  });

  testWidgets('Delete closes the modal, leaves for the list and deletes', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settleModal(tester);

    expect(_confirm, findsNothing);
    expect(modalAction('delete'), findsNothing);
    expect(host.location, '/playlists');
    expect(await stillStored(tester), isFalse);
  });

  testWidgets('Favorites has no Delete row', (tester) async {
    await insertTracks(tester, h, const [TestTrack('a')]);
    final favorites = await tester.runAsync(
      () => h.db.ensureFavoritesPlaylist(now: 1),
    );
    await pumpModalHost(tester, h, id: favorites!);
    await openPlaylistModalOf(tester);
    expect(modalAction('delete'), findsNothing);
    expect(modalAction('edit'), findsNothing);
    expect(find.byTooltip('Edit'), findsNothing);
  });
}
