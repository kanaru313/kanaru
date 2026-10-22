import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../library/library_test_harness.dart';
import 'playlist_test_data.dart';

/// The picker dialog.
Finder get picker => find.byType(AlertDialog);

/// [text] inside the picker (the sidebar lists the same names).
Finder inPicker(String text) =>
    find.descendant(of: picker, matching: find.text(text));

Future<void> openMenuOf(WidgetTester tester, Finder row) async {
  await tester.tap(row, buttons: kSecondaryButton);
  await tester.pumpAndSettle();
}

/// Right clicks [row], chooses "Add to playlist…" and then the playlist
/// named [playlist] in the picker.
Future<void> addVia(
  WidgetTester tester,
  LibraryHarness h,
  Finder row,
  String playlist,
) async {
  await openMenuOf(tester, row);
  await tester.tap(find.text('Add to playlist…'));
  await tester.pumpAndSettle();
  await tester.tap(inPicker(playlist));
  await settleDb(tester);
}

/// Lets the snackbar on screen go, so the next one can show.
Future<void> clearMessage(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 7));
  await tester.pumpAndSettle();
}

/// The text field of the name dialog.
Finder get nameField =>
    find.descendant(of: picker, matching: find.byType(TextField));
