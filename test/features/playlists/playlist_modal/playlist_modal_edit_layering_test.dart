import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../library/browse_test_data.dart';
import '../../library/library_test_harness.dart';
import '../playlist_test_data.dart';
import 'playlist_modal_test_support.dart';

final _nameField = find.byKey(const ValueKey('playlist-edit-name'));
final _editDialog = find.text('Edit playlist');
final _save = find.widgetWithText(FilledButton, 'Save');
final _modalRow = modalAction('play-all');

void main() {
  late LibraryHarness h;
  late int id;

  setUp(() => h = LibraryHarness());

  Future<void> open(WidgetTester tester) async {
    await insertTracks(tester, h, const [TestTrack('a'), TestTrack('b')]);
    id = await seedPlaylist(tester, h, 'Mix', ['a', 'b']);
    await pumpModalHost(tester, h, id: id);
    await openPlaylistModalOf(tester);
  }

  Future<void> openEdit(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Edit'));
    await settleModal(tester);
  }

  testWidgets('the Edit button opens the dialog above the open modal', (
    tester,
  ) async {
    await open(tester);
    await openEdit(tester);

    expect(_editDialog, findsOneWidget);
    expect(_modalRow, findsOneWidget, reason: 'the modal is still mounted');
    // The dialog's barrier takes the taps: the modal row below is not hit.
    await tester.tap(_modalRow, warnIfMissed: false);
    await settleModal(tester);
    expect(_editDialog, findsOneWidget);
    expect(queueTitles(h), isEmpty);
  });

  testWidgets('the Edit row opens it too, and the modal stays', (tester) async {
    await open(tester);
    await tapModalAction(tester, 'edit');
    expect(_editDialog, findsOneWidget);
    expect(_modalRow, findsOneWidget);
  });

  for (final (label, dismiss)
      in <(String, Future<void> Function(WidgetTester))>[
        ('Esc', (t) => t.sendKeyEvent(LogicalKeyboardKey.escape)),
        ('a tap outside', (t) => t.tapAt(const Offset(4, 4))),
        ('Cancel', (t) => t.tap(find.widgetWithText(TextButton, 'Cancel'))),
        ('the close button', (t) => t.tap(find.byTooltip('Close'))),
      ]) {
    testWidgets('$label closes only the Edit dialog', (tester) async {
      await open(tester);
      await openEdit(tester);
      await dismiss(tester);
      await settleModal(tester);

      expect(_editDialog, findsNothing);
      expect(_modalRow, findsOneWidget);
      // Focus is back in the modal: Esc now closes it.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleModal(tester);
      expect(_modalRow, findsNothing);
    });
  }

  testWidgets('Save updates the header without reopening', (tester) async {
    await open(tester);
    await openEdit(tester);
    await tester.enterText(_nameField, 'Night drive');
    await tester.tap(_save);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settleModal(tester);

    expect(_editDialog, findsNothing);
    expect(_modalRow, findsOneWidget);
    expect(find.text('Night drive'), findsWidgets);
    expect(find.text('Mix'), findsNothing);
  });

  testWidgets('a second Edit in the same session starts from the new name', (
    tester,
  ) async {
    await open(tester);
    await openEdit(tester);
    await tester.enterText(_nameField, 'Night drive');
    await tester.tap(_save);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settleModal(tester);

    await tapModalAction(tester, 'edit');
    expect(
      tester.widget<TextField>(_nameField).controller!.text,
      'Night drive',
    );
  });

  testWidgets('Duplicate after a rename uses the new name', (tester) async {
    await open(tester);
    await openEdit(tester);
    await tester.enterText(_nameField, 'Night drive');
    await tester.tap(_save);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settleModal(tester);

    await tapModalAction(tester, 'advanced');
    await tapModalAction(tester, 'duplicate');
    final names = await tester.runAsync(
      () => h.db
          .select(h.db.playlists)
          .get()
          .then((rows) => [for (final r in rows) r.name]),
    );
    expect(names, containsAll(['Night drive', 'Night drive (copy)']));
  });
}
