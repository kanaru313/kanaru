import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/history/history_routes.dart';
import 'package:kanaru/features/history/most_played_side_pane.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/m3u/m3u_save_picker.dart';
import 'package:kanaru/shared/widgets/context_menu_more_button.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_header.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/stats/gated_query_interceptor.dart';
import '../../../support/settle_modal.dart';
import '../../playlists/add_to_playlist_test_support.dart';
import '../history_test_harness.dart';

DateTime _at(int month, int day, [int hour = 9]) =>
    DateTime(2026, month, day, hour);

/// In the last 30 days: A and B 3 plays each (B's last one earlier), C one,
/// the Ghost (not in the library) two. Ranking: B, A, Ghost, C.
final _plays = <SeedPlay>[
  for (final d in [20, 21, 22]) ('A', _at(10, d)),
  for (final d in [10, 11, 12]) ('B', _at(10, d)),
  ('C', _at(10, 22, 10)),
  ('Ghost', _at(10, 15)),
  ('Ghost', _at(10, 15, 10)),
];

Finder _row(String id) => find.byKey(ValueKey('context-modal-action-$id'));

Finder get _more => find.descendant(
  of: find.byType(MostPlayedSidePane),
  matching: find.byType(ContextMenuMoreButton),
);

bool _moreEnabled(WidgetTester tester) =>
    tester
        .widget<IconButton>(
          find.descendant(of: _more, matching: find.byType(IconButton)),
        )
        .onPressed !=
    null;

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

  LibraryHarness harness([GatedQueryInterceptor? gate]) => historyHarness(
    interceptor: gate,
    overrides: [
      m3uSavePickerProvider.overrideWithValue((name) async {
        pickerCalls++;
        return savePath;
      }),
    ],
  );

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kanaru-most-played-modal');
    pickerCalls = 0;
    savePath = '${tmp.path}/most-played.m3u8';
    h = harness();
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    tmp.deleteSync(recursive: true);
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  Future<void> open(
    WidgetTester tester, {
    List<SeedPlay>? plays,
    GatedQueryInterceptor? gate,
  }) => openHistory(
    tester,
    h,
    tracks: [song('A'), song('B'), song('C')],
    plays: plays ?? _plays,
    gate: gate,
    page: mostPlayedPath,
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
      'Add all to Favorites',
      'Play next',
      'Add to queue',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // The four actions only: the page's Play and Shuffle are not rows.
    expect(
      find.byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey<String> &&
            key.value.startsWith('context-modal-action-');
      }),
      findsNWidgets(4),
    );
    final header = find.byType(ContextModalHeader);
    expect(
      find.descendant(of: header, matching: find.text('Most played')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: find.byIcon(AppIcons.mostPlayed)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: find.text('4 songs • 9 listens')),
      findsOneWidget,
    );
    expect(find.text('3 songs'), findsOneWidget);
    expect(find.textContaining('3 songs, in rank order'), findsNWidgets(2));
  });

  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
    historyTestWidgets('${key.keyLabel} on the ⋮ focuses the first row', (
      tester,
    ) async {
      await open(tester);
      Focus.of(
        tester.element(
          find.descendant(of: _more, matching: find.byIcon(AppIcons.more)),
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(key);
      await settleModal(tester);

      expect(_row('add-to-playlist'), findsOneWidget);
      expect(_focusIn(_row('add-to-playlist')), isTrue);
    });
  }

  historyTestWidgets('the ⋮ is off while a new range is read', (tester) async {
    final gate = GatedQueryInterceptor();
    h = harness(gate);
    await open(tester, gate: gate);
    expect(_moreEnabled(tester), isTrue);

    final release = gate.holdNext('ORDER BY a.n DESC');
    final chip = find.widgetWithText(ChoiceChip, '7 days');
    await tester.ensureVisible(chip);
    await tester.pump();
    await tester.tap(chip);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump();
    expect(_moreEnabled(tester), isFalse);

    release();
    await settleHistory(tester);
    expect(_moreEnabled(tester), isTrue);
  });

  historyTestWidgets('the ⋮ stays off when the new range failed to read', (
    tester,
  ) async {
    final gate = GatedQueryInterceptor();
    h = harness(gate);
    await open(tester, gate: gate);
    expect(_moreEnabled(tester), isTrue);

    gate.failNext('ORDER BY a.n DESC');
    final chip = find.widgetWithText(ChoiceChip, '7 days');
    await tester.ensureVisible(chip);
    await tester.pump();
    await tester.tap(chip);
    await settleHistory(tester);

    expect(find.text('No listens in this range'), findsNothing);
    expect(_moreEnabled(tester), isFalse);
  });

  historyTestWidgets('the ⋮ is off when no listed song is in the library', (
    tester,
  ) async {
    await open(tester, plays: [('Ghost', _at(10, 15))]);

    expect(_moreEnabled(tester), isFalse);
  });

  historyTestWidgets('Add to queue takes the library songs in rank order', (
    tester,
  ) async {
    await open(tester);
    await openModal(tester);
    await tester.tap(find.text('Add to queue'));
    await settleHistory(tester);

    expect(_queue(h), ['/m/B.flac', '/m/A.flac', '/m/C.flac']);
  });

  historyTestWidgets('Add to playlist suggests the range, in rank order', (
    tester,
  ) async {
    await open(tester);
    await openModal(tester);
    await tester.tap(_row('add-to-playlist'));
    await settleModal(tester);

    await tester.tap(inPicker('New playlist…'));
    await tester.pumpAndSettle();
    final name = tester.widget<TextField>(nameField).controller!.text;
    expect(name, startsWith('Most played · '));
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
      ['/m/B.flac', '/m/A.flac', '/m/C.flac'],
    );
  });

  historyTestWidgets('Add all to Favorites adds the library songs', (
    tester,
  ) async {
    await open(tester);
    await openModal(tester);
    await tester.tap(_row('add-all-to-favorites'));
    await settleHistory(tester);

    final entries = await tester.runAsync(
      () => h.db.select(h.db.playlistEntries).get(),
    );
    expect(
      {for (final e in entries!) e.path},
      {'/m/B.flac', '/m/A.flac', '/m/C.flac'},
    );
  });

  Future<String> export(WidgetTester tester, String row) async {
    await openModal(tester);
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

  historyTestWidgets('the absolute export lists the songs in rank order', (
    tester,
  ) async {
    await open(tester);
    final text = await export(tester, 'export-absolute');

    expect(pickerCalls, 1);
    expect(text.split('\n').where((l) => l.startsWith('/m/')), [
      '/m/B.flac',
      '/m/A.flac',
      '/m/C.flac',
    ]);
    expect('#EXTINF'.allMatches(text), hasLength(3));
    expect(find.textContaining('Saved 3 songs'), findsOneWidget);
  });

  historyTestWidgets('the relative export has no path from the root', (
    tester,
  ) async {
    await open(tester);
    final text = await export(tester, 'export-relative');

    final lines = text.split('\n').where((l) => l.contains('.flac'));
    expect(lines, hasLength(3));
    expect(lines.any((l) => l.startsWith('/')), isFalse);
  });
}
