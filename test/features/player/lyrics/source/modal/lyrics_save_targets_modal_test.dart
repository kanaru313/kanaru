import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lrc_sidecar_writer.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/features/player/lyrics/source/modal/lyrics_save_targets_modal.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/selection_row.dart';
import 'package:material_ui/material_ui.dart';

import 'lyrics_source_modal_test_harness.dart';

Future<void> _pumpModal(WidgetTester tester, LyricsFound found) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => LyricsSaveTargetsModal(
              parentContext: context,
              source: fakeResolution(found),
              messenger: null,
            ),
          ),
        ),
      ),
    );

SelectionRow _row(WidgetTester tester, String title) =>
    tester.widget<SelectionRow>(find.widgetWithText(SelectionRow, title));

void main() {
  final online = LyricsFound(modalUri, modalLyrics(), origin: modalOrigin());

  testWidgets('lists the file and the tags, the file chosen', (tester) async {
    await _pumpModal(tester, online);

    expect(find.text('Save lyrics to'), findsOneWidget);
    expect(find.text('song.lrc'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.text('Save (1)'), findsOneWidget);
    expect(_row(tester, '.lrc file next to the song').selected, isTrue);
    final tag = _row(tester, 'Tag in the music file');
    expect(tag.onTap, isNull);
    expect(tag.selected, isFalse);
  });

  testWidgets('clearing the file disables Save (0)', (tester) async {
    await _pumpModal(tester, online);

    await tester.tap(find.text('.lrc file next to the song'));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(find.text('Save (0)'), findsOneWidget);
    expect(button.onPressed, isNull);
  });

  testWidgets('the file row is disabled when the lyrics come from it', (
    tester,
  ) async {
    await _pumpModal(tester, LyricsFound(modalUri, modalLyrics()));

    expect(_row(tester, '.lrc file next to the song').onTap, isNull);
    expect(find.text('Save (0)'), findsOneWidget);
  });

  testWidgets('a pinned online version that was saved can be saved again', (
    tester,
  ) async {
    await pumpSourceModal(
      tester,
      fakeResolution(online),
      records: [modalRecord('plugin-a', 'Alpha')],
      saveResult: LrcWriteResult.identical,
    );
    await tester.tap(find.text('Save lyrics…'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(_row(tester, '.lrc file next to the song').onTap, isNotNull);

    await tester.tap(find.text('Save (1)'));
    await tester.pump();
    // The flow reads the folder between frames: wait for it in real time.
    final end = DateTime.now().add(const Duration(seconds: 5));
    while (find.text('Already saved as song.lrc').evaluate().isEmpty &&
        DateTime.now().isBefore(end)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Already saved as song.lrc'), findsOneWidget);
  });

  testWidgets('a double tap on Save saves once', (tester) async {
    final h = await pumpSourceModal(
      tester,
      fakeResolution(online),
      records: [modalRecord('plugin-a', 'Alpha')],
    );
    await tester.tap(find.text('Save lyrics…'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final save = find.text('Save (1)');
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(h.log, ['save 1']);
    expect(find.text('No lyrics to save'), findsNothing);
  });

  testWidgets('the stack is closed before the snackbar shows', (tester) async {
    await pumpSourceModal(
      tester,
      fakeResolution(online),
      records: [modalRecord('plugin-a', 'Alpha')],
    );
    await tester.tap(find.text('Save lyrics…'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Save (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Save lyrics to'), findsNothing);
    expect(find.text('Lyrics for this song'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(openerScaffold),
        matching: find.text('Lyrics saved as a .lrc file'),
      ),
      findsOneWidget,
    );
  });
}
