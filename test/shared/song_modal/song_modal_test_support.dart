import 'package:flutter/foundation.dart' show ValueKey;
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/song_modal/song_modal_header.dart';

import '../../support/settle_modal.dart';
export '../../support/settle_modal.dart' show settleModal;

/// Opens the song modal of the row [finder] with a right click and waits for
/// its links and favorite to load.
Future<void> openSongModal(WidgetTester tester, Finder finder) async {
  await tester.tap(finder, buttons: kSecondaryButton);
  await settleModal(tester);
}

/// Taps the row of the open modal labelled [label] and waits for what it
/// starts.
Future<void> tapModalAction(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await settleModal(tester);
}

/// The row of the open modal with action [id].
Finder modalAction(String id) =>
    find.byKey(ValueKey('context-modal-action-$id'));

/// Opens Song info from the open modal by tapping its header.
Future<void> openSongInfoPage(WidgetTester tester) async {
  await tester.tap(find.byType(SongModalHeader));
  await settleModal(tester);
}
