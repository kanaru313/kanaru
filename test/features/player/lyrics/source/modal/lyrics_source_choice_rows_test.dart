import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_choice.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kanaru/shared/lyrics_plugins/plugin_icon.dart';
import 'package:kanaru/shared/widgets/selection_row.dart';

import 'lyrics_source_modal_test_harness.dart';

SelectionRow row(WidgetTester tester, String title) => tester.widget(
  find.ancestor(of: find.text(title), matching: find.byType(SelectionRow)),
);

void main() {
  final alpha = [modalRecord('plugin-a', 'Alpha')];

  testWidgets('the row of the choice in effect is selected', (tester) async {
    await pumpSourceModal(
      tester,
      fakeResolution(
        LyricsFound(modalUri, modalLyrics(), origin: modalOrigin()),
        chosen: LyricsChoice.online,
        effective: LyricsChoice.online,
        hasLocal: true,
        pin: fakePin(providerId: 'plugin-a', lyrics: modalLyrics()),
      ),
      records: alpha,
    );
    expect(row(tester, 'Online version').selected, isTrue);
    expect(row(tester, 'Lyrics in the file').selected, isFalse);
    expect(row(tester, "Don't show lyrics").selected, isFalse);
    expect(find.text('Alpha · Synced'), findsOneWidget);
    expect(find.byType(PluginIcon), findsOneWidget);
  });

  testWidgets('file row is disabled when the file has no lyrics', (
    tester,
  ) async {
    await pumpSourceModal(
      tester,
      fakeResolution(
        LyricsNone(modalUri, LyricsNoneReason.noLyrics),
        effective: LyricsChoice.local,
      ),
      records: alpha,
    );
    expect(row(tester, 'Lyrics in the file').onTap, isNull);
    expect(find.text('This file has no lyrics'), findsOneWidget);
    expect(row(tester, 'Online version').onTap, isNull);
    expect(find.text('Nothing found online yet'), findsOneWidget);
  });

  testWidgets('online row enabled when off with auto lookup possible', (
    tester,
  ) async {
    await pumpSourceModal(
      tester,
      fakeResolution(
        LyricsNone(modalUri, LyricsNoneReason.off),
        chosen: LyricsChoice.off,
        effective: LyricsChoice.off,
      ),
      records: alpha,
    );
    expect(row(tester, 'Online version').onTap, isNotNull);
    expect(row(tester, "Don't show lyrics").selected, isTrue);
  });

  testWidgets('removed plugin: letter icon and (removed) name', (tester) async {
    await pumpSourceModal(
      tester,
      fakeResolution(
        LyricsFound(
          modalUri,
          modalLyrics(),
          origin: modalOrigin(id: 'plugin-gone'),
        ),
        effective: LyricsChoice.online,
        pin: fakePin(providerId: 'plugin-gone', lyrics: modalLyrics()),
      ),
      records: alpha,
    );
    final icon = tester.widget<PluginIcon>(find.byType(PluginIcon));
    expect(icon.letterOf, isNotEmpty);
    expect(icon.record, isNull);
  });

  testWidgets('tap closes the modal, then calls choose', (tester) async {
    final h = await pumpSourceModal(
      tester,
      fakeResolution(
        LyricsFound(modalUri, modalLyrics()),
        effective: LyricsChoice.local,
        hasLocal: true,
      ),
      records: alpha,
    );
    await tester.tap(find.text("Don't show lyrics"));
    await tester.pumpAndSettle();
    expect(find.text('Lyrics for this song'), findsNothing);
    expect(h.log, ['choose off']);
  });

  testWidgets('tapping the selected row only closes', (tester) async {
    final h = await pumpSourceModal(
      tester,
      fakeResolution(
        LyricsFound(modalUri, modalLyrics()),
        effective: LyricsChoice.local,
        hasLocal: true,
      ),
    );
    await tester.tap(find.text('Lyrics in the file'));
    await tester.pumpAndSettle();
    expect(find.text('Lyrics for this song'), findsNothing);
    expect(h.log, isEmpty);
  });

  testWidgets('not a local file: rows disabled, no status or Find', (
    tester,
  ) async {
    await pumpSourceModal(
      tester,
      fakeResolution(
        LyricsNone(modalUri, LyricsNoneReason.noLyrics),
        hasLocal: true,
      ),
      library: false,
      records: alpha,
    );
    expect(row(tester, 'Lyrics in the file').onTap, isNull);
    expect(find.text('Find lyrics online…'), findsNothing);
    expect(find.textContaining('No lyrics on this device'), findsNothing);
  });

  testWidgets('automatic match subtitle says it was found automatically', (
    tester,
  ) async {
    await pumpSourceModal(
      tester,
      fakeResolution(
        LyricsFound(
          modalUri,
          modalLyrics(),
          origin: modalOrigin(pinned: false),
        ),
        effective: LyricsChoice.online,
      ),
      records: alpha,
    );
    expect(find.text('Alpha · Synced · found automatically'), findsOneWidget);
  });

  testWidgets('file row names the file kind while online lyrics show', (
    tester,
  ) async {
    await pumpSourceModal(
      tester,
      fakeResolution(
        LyricsFound(modalUri, modalLyrics(), origin: modalOrigin()),
        effective: LyricsChoice.online,
        hasLocal: true,
      ),
      records: alpha,
      ownLyrics: modalLyrics(synced: false),
    );
    expect(find.text('.lrc file · Plain'), findsOneWidget);
  });

  testWidgets('online row needs a song that can be looked up', (tester) async {
    await pumpSourceModal(
      tester,
      fakeResolution(
        LyricsNone(modalUri, LyricsNoneReason.off),
        chosen: LyricsChoice.off,
        effective: LyricsChoice.off,
      ),
      records: alpha,
      autoSearchable: false,
    );
    expect(row(tester, 'Online version').onTap, isNull);
  });

  testWidgets('an error snackbar shows on the messenger captured at open', (
    tester,
  ) async {
    await pumpSourceModal(
      tester,
      fakeResolution(
        LyricsFound(modalUri, modalLyrics()),
        effective: LyricsChoice.local,
        hasLocal: true,
      ),
      failChoose: true,
    );
    await tester.tap(find.text("Don't show lyrics"));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(openerScaffold),
        matching: find.byType(SnackBar),
      ),
      findsOneWidget,
    );
  });
}
