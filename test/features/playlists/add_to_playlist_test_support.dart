import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../library/library_test_harness.dart';
import 'playlist_test_data.dart';

/// The picker dialog (not the dialogs it opens above itself).
Finder get picker => find.byKey(const ValueKey('playlist-picker'));

/// The picker's Add button, whatever its label.
Finder get pickerAdd =>
    find.descendant(of: picker, matching: find.byType(FilledButton));

/// [text] inside the picker (the sidebar lists the same names).
Finder inPicker(String text) =>
    find.descendant(of: picker, matching: find.text(text));

Future<void> openMenuOf(WidgetTester tester, Finder row) async {
  await tester.tap(row, buttons: kSecondaryButton);
  await tester.pumpAndSettle();
}

/// Right clicks [row], chooses "Add to playlist…", ticks the playlist named
/// [playlist] in the picker and presses Add.
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
  await tester.pumpAndSettle();
  await tester.tap(pickerAdd);
  await settleDb(tester);
}

/// In the open picker: "New playlist…", the name [name], Create. The new
/// playlist comes back as a ticked row; nothing is created yet.
Future<void> nameNewInPicker(WidgetTester tester, String name) async {
  await tester.tap(inPicker('New playlist…'));
  await tester.pumpAndSettle();
  await tester.enterText(nameField, name);
  await tester.tap(find.widgetWithText(FilledButton, 'Create'));
  await tester.pumpAndSettle();
}

/// Lets the snackbar on screen go, so the next one can show.
Future<void> clearMessage(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 7));
  await tester.pumpAndSettle();
}

/// The text field of the name dialog, the topmost dialog.
Finder get nameField => find.descendant(
  of: find.byType(AlertDialog).last,
  matching: find.byType(TextField),
);
