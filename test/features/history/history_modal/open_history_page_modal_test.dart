import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/history/history_side_pane.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/m3u/m3u_save_picker.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_header.dart';
import 'package:kanaru/shared/widgets/playlist_cover.dart';
import 'package:material_ui/material_ui.dart';

import '../../../support/settle_modal.dart';
import '../../playlists/add_to_playlist_test_support.dart';
import '../history_test_harness.dart';

DateTime _at(int day, int hour) => DateTime(2026, 10, day, hour);

Finder _row(String id) => find.byKey(ValueKey('context-modal-action-$id'));

Finder get _more => find.descendant(
  of: find.byType(HistorySidePane),
  matching: find.byIcon(AppIcons.more),
);

List<String> _queue(LibraryHarness h) => [
  for (final t in h.container.read(playerServiceProvider).queue.original) t.uri,
];

bool _focusIn(Finder within) {
  final focus = FocusManager.instance.primaryFocus;
  if (focus is FocusScopeNode) return false;
  final ctx = focus?.context;
  if (ctx == null) return false;
  return find
      .descendant(
        of: within,
        matching: find.byElementPredicate((e) => e == ctx),
      )
      .evaluate()
      .isNotEmpty;
}

void main() {
  late Directory tmp;
  late LibraryHarness h;
  var pickerCalls = 0;
  var savePath = '';

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kanaru-history-modal');
    pickerCalls = 0;
    savePath = '${tmp.path}/history.m3u8';
    h = historyHarness(
      overrides: [
        m3uSavePickerProvider.overrideWithValue((name) async {
          pickerCalls++;
          return savePath;
        }),
      ],
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    tmp.deleteSync(recursive: true);
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  /// B (23rd, latest), A (22nd), Z (21st), and one song gone from the library.
  Future<void> open(WidgetTester tester, {List<(String, DateTime)>? plays}) =>
      openHistory(
        tester,
        h,
        tracks: [song('A'), song('B'), song('Z')],
        plays:
            plays ??
            [
              ('gone', _at(20, 9)),
              ('Z', _at(21, 9)),
              ('A', _at(22, 9)),
              ('B', _at(23, 9)),
            ],
      );

  Future<void> openModal(WidgetTester tester) async {
    await tester.tap(_more);
    await settleModal(tester);
  }

  historyTestWidgets('the ⋮ opens a modal with header, rows and footer', (
    tester,
  ) async {
    await open(tester);
    await openModal(tester);

    for (final label in [
      'Add to playlist…',
      'Advanced',
      'Play next',
      'Add to queue',
      'Songs you play the most',
      'New playlist suggests “History”',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(
      find.descendant(
        of: _row('most-played'),
        matching: find.text('Most played'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ContextModalHeader),
        matching: find.byType(PlaylistCover),
      ),
      findsOneWidget,
    );
    final cover = tester.widget<PlaylistCover>(
      find.descendant(
        of: find.byType(ContextModalHeader),
        matching: find.byType(PlaylistCover),
      ),
    );
    expect(cover.seed, historyCollageSeed);
    expect(cover.icon, AppIcons.history);
    // The page behind the modal draws the same collage.
    final page = tester.widget<PlaylistCover>(find.byType(PlaylistCover).first);
    expect(cover.coverKeys, page.coverKeys);
    expect(
      find.descendant(
        of: find.byType(ContextModalHeader),
        matching: find.text('4 listens • 4 songs • since Oct 20, 2026'),
      ),
      findsOneWidget,
    );
  });

  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
    historyTestWidgets('${key.keyLabel} on the ⋮ focuses the first row', (
      tester,
    ) async {
      await open(tester);
      Focus.of(tester.element(_more)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(key);
      await settleModal(tester);

      expect(_row('add-to-playlist'), findsOneWidget);
      expect(_focusIn(_row('add-to-playlist')), isTrue);
    });
  }

  historyTestWidgets(
    'Play next and Add to queue take the played library songs',
    (tester) async {
      await open(tester);
      await openModal(tester);
      await tester.tap(find.text('Add to queue'));
      await settleHistory(tester);

      expect(_queue(h), ['/m/B.flac', '/m/A.flac', '/m/Z.flac']);
    },
  );

  historyTestWidgets('Most played goes to the ranking', (tester) async {
    await open(tester);
    await openModal(tester);
    await tester.tap(_row('most-played'));
    await settleHistory(tester);

    expect(location(h), '/most-played');
  });

  historyTestWidgets('Add to playlist suggests History, last played first', (
    tester,
  ) async {
    await open(tester);
    await openModal(tester);
    await tester.tap(_row('add-to-playlist'));
    await settleModal(tester);

    await tester.tap(inPicker('New playlist…'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(nameField).controller!.text, 'History');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    await tester.tap(pickerAdd);
    await settleHistory(tester);

    final entries = await tester.runAsync(
      () => (h.db.select(
        h.db.playlistEntries,
      )..orderBy([(e) => OrderingTerm.asc(e.position)])).get(),
    );
    expect(
      [for (final e in entries!) e.path],
      ['/m/B.flac', '/m/A.flac', '/m/Z.flac'],
    );
  });

  Future<String> export(WidgetTester tester, String row) async {
    await openModal(tester);
    await tester.tap(_row('advanced'));
    await settleModal(tester);
    await tester.tap(_row(row));
    for (
      var i = 0;
      i < 40 && find.textContaining('Saved').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    return File(savePath).readAsStringSync();
  }

  historyTestWidgets('both exports list the songs last played first', (
    tester,
  ) async {
    await open(tester);
    final absolute = await export(tester, 'export-absolute');
    expect(pickerCalls, 1);
    expect(absolute.split('\n').where((l) => l.startsWith('/m/')), [
      '/m/B.flac',
      '/m/A.flac',
      '/m/Z.flac',
    ]);
    expect(find.textContaining('Saved 3 songs'), findsOneWidget);
  });

  historyTestWidgets('relative paths do not start at the root', (tester) async {
    await open(tester);
    final relative = await export(tester, 'export-relative');
    final lines = relative.split('\n').where((l) => l.contains('.flac'));
    expect(lines, hasLength(3));
    expect(lines.any((l) => l.startsWith('/')), isFalse);
  });

  historyTestWidgets('plays of songs gone from the library open no picker', (
    tester,
  ) async {
    await open(tester, plays: [('gone', _at(20, 9))]);
    await openModal(tester);
    expect(find.text('1 listen • 1 song • since Oct 20, 2026'), findsOneWidget);
    await tester.tap(_row('add-to-playlist'));
    await settleModal(tester);

    expect(
      find.text('None of the songs you played are in your library'),
      findsOneWidget,
    );
    expect(pickerAdd, findsNothing);

    await tester.pumpAndSettle(const Duration(seconds: 6));
    await openModal(tester);
    await tester.tap(_row('advanced'));
    await settleModal(tester);
    await tester.tap(_row('export-absolute'));
    await settleModal(tester);
    expect(pickerCalls, 0);
    expect(File(savePath).existsSync(), isFalse);
    expect(
      find.text('None of the songs you played are in your library'),
      findsOneWidget,
    );
  });
}
