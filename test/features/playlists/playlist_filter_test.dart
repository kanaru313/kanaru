import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:kanaru/core/database/playlist_rows.dart';
import 'package:kanaru/core/database/search_playlist_queries.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/playlists/playlist_entries_view.dart';
import 'package:kanaru/features/playlists/playlist_routes.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/in_page_filter_registry.dart';
import 'package:kanaru/shared/widgets/in_page_search_field.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';
import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';
import 'playlist_test_data.dart';

const _tracks = [
  TestTrack('Hello', artist: 'Lovers', album: 'First'),
  TestTrack('My Love', artist: 'Bob', album: 'Second'),
  TestTrack('Other', artist: 'Bob', album: 'Second'),
  TestTrack('Love Story', artist: 'Ann', album: 'First'),
];

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  Future<int> openMixOf(WidgetTester tester, {List<String>? titles}) async {
    await insertTracks(tester, h, _tracks);
    await h.pump(tester, hasRoots: true);
    final id = await seedPlaylist(
      tester,
      h,
      'Mix',
      titles ?? ['Hello', 'My Love', 'Other', 'Love Story'],
      extraPaths: const ['/gone/Love Lost.mp3'],
    );
    goTo(tester, h, playlistLocation(id));
    await settleDb(tester);
    return id;
  }

  Future<void> filterBy(WidgetTester tester, String text) async {
    if (find.byType(InPageSearchBox).evaluate().isEmpty) {
      await tester.tap(find.byTooltip('Filter in this page'));
      await tester.pumpAndSettle();
    }
    await tester.enterText(
      find.descendant(
        of: find.byType(InPageSearchBox),
        matching: find.byType(TextField),
      ),
      text,
    );
    await tester.pump(const Duration(milliseconds: 150));
    await settleDb(tester);
  }

  List<String> queued() => [
    for (final t in h.container.read(playerServiceProvider).queue.original)
      t.title,
  ];

  testWidgets('shows only matching songs, best match first', (tester) async {
    await openMixOf(tester);
    expect(shownTitles(tester), hasLength(5));

    await filterBy(tester, 'love');

    // Title starts with it, then title has it, then artist has it. The entry
    // whose file is not in the library cannot match.
    expect(shownTitles(tester), ['Love Story', 'My Love', 'Hello']);
  });

  testWidgets('a tap plays the filtered songs from that row', (tester) async {
    await openMixOf(tester);
    await filterBy(tester, 'love');

    await tester.tap(find.text('My Love'));
    await tester.pump();

    expect(queued(), ['Love Story', 'My Love', 'Hello']);
    expect(
      h.container.read(playerServiceProvider).queue.current?.title,
      'My Love',
    );
  });

  testWidgets('no drag handle or Remove from playlist while filtering', (
    tester,
  ) async {
    await openMixOf(tester);
    expect(find.byIcon(AppIcons.dragHandle), findsWidgets);
    await expectRowModalRemove(tester, 0, present: true);

    await filterBy(tester, 'love');

    expect(find.byIcon(AppIcons.dragHandle), findsNothing);
    await expectRowModalRemove(tester, 0, present: false);
  });

  testWidgets('no match says so and Esc brings back the whole list', (
    tester,
  ) async {
    await openMixOf(tester);

    await filterBy(tester, 'zzz');
    expect(find.text('No songs match “zzz”'), findsOneWidget);
    expect(shownTitles(tester), isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await settleDb(tester);

    expect(find.text('No songs match “zzz”'), findsNothing);
    expect(shownTitles(tester), hasLength(5));
    expect(find.byIcon(AppIcons.dragHandle), findsWidgets);
  });

  testWidgets('follows the playlist when it changes while filtering', (
    tester,
  ) async {
    final id = await openMixOf(tester);
    await filterBy(tester, 'love');
    expect(shownTitles(tester), ['Love Story', 'My Love', 'Hello']);

    final page = await tester.runAsync(() => h.db.playlistPage(id));
    final hello = page!.entries.firstWhere((e) => e.track?.title == 'Hello');
    await tester.runAsync(
      () => h.db.removePlaylistEntries(id, {hello.entryId}),
    );
    await settleDb(tester);

    expect(shownTitles(tester), ['Love Story', 'My Love']);
  });

  testWidgets('the filter button is not on an empty playlist', (tester) async {
    await insertTracks(tester, h, _tracks);
    await h.pump(tester, hasRoots: true);
    final id = await seedPlaylist(tester, h, 'Empty', const []);
    goTo(tester, h, playlistLocation(id));
    await settleDb(tester);

    expect(find.byTooltip('Filter in this page'), findsNothing);
    // Ctrl+F then has no box to open here and goes on to the top bar search.
    expect(InPageFilterRegistry.instance.openTop(), isFalse);
  });

  testWidgets('the open filter closes when the last entry goes away', (
    tester,
  ) async {
    final id = await openMixOf(tester, titles: ['Hello']);
    await filterBy(tester, 'hello');
    expect(find.byType(InPageSearchBox), findsOneWidget);

    final page = await tester.runAsync(() => h.db.playlistPage(id));
    await tester.runAsync(
      () => h.db.removePlaylistEntries(id, {
        for (final e in page!.entries) e.entryId,
      }),
    );
    await settleDb(tester);
    await tester.pumpAndSettle();

    expect(find.byType(InPageSearchBox), findsNothing);
    expect(InPageFilterRegistry.instance.openTop(), isFalse);
  });

  group('answers that arrive late', () {
    late Map<String, PlaylistMatches> answers;
    late PlaylistPage page;

    Future<void> pumpView(
      WidgetTester tester,
      Future<PlaylistMatches> Function(List<String> terms) loadMatches,
    ) async {
      await insertTracks(tester, h, _tracks);
      await h.pump(tester, hasRoots: true);
      final id = await seedPlaylist(tester, h, 'Mix', [
        'Hello',
        'My Love',
        'Other',
        'Love Story',
      ]);
      page = (await tester.runAsync(
        () async => (await h.db.playlistPage(id))!,
      ))!;
      answers = {
        for (final term in ['hel', 'love'])
          term: (await tester.runAsync(
            () => h.db.playlistEntriesMatching(id, [term]),
          ))!,
      };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioBackendProvider.overrideWithValue(FakeAudioBackend()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PlaylistEntriesView(
                head: PlaylistPageHead(
                  playlist: PlaylistSummary(
                    id: id,
                    name: 'Mix',
                    createdAt: 1,
                    entryCount: page.entries.length,
                  ),
                  coverKeys: const [],
                  hasPlayable: true,
                ),
                loadRows: (start, count) async => [
                  for (
                    var i = start;
                    i < start + count && i < page.entries.length;
                    i++
                  )
                    PlaylistPositionedEntry(i, page.entries[i]),
                ],
                onPlayFrom: (_, _) async {},
                loadMatches: loadMatches,
                onPlayRows: (_, _) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> type(WidgetTester tester, String text) async {
      if (find.byType(InPageSearchBox).evaluate().isEmpty) {
        await tester.tap(find.byTooltip('Filter in this page'));
        await tester.pumpAndSettle();
      }
      await tester.enterText(
        find.descendant(
          of: find.byType(InPageSearchBox),
          matching: find.byType(TextField),
        ),
        text,
      );
      await tester.pump(const Duration(milliseconds: 150));
    }

    testWidgets('a slow old read does not replace the newer one', (
      tester,
    ) async {
      final reads = <String, Completer<PlaylistMatches>>{};
      await pumpView(tester, (terms) {
        return (reads[terms.single] = Completer<PlaylistMatches>()).future;
      });

      await type(tester, 'hel');
      await type(tester, 'love');
      reads['love']!.complete(answers['love']);
      await tester.pump();
      reads['hel']!.complete(answers['hel']);
      await tester.pump();

      expect(shownTitles(tester), ['Love Story', 'My Love', 'Hello']);
    });

    testWidgets('says when the list was cut', (tester) async {
      await pumpView(
        tester,
        (terms) async =>
            PlaylistMatches(answers['love']!.entries, truncated: true),
      );

      await type(tester, 'love');
      await tester.pump();

      expect(
        find.text('Showing the first 3 songs. Type more to narrow it down.'),
        findsOneWidget,
      );
    });
  });

  group('while a write is running', () {
    PlaylistEntryRow entry(int id) =>
        PlaylistEntryRow(entryId: id, path: '/m/$id', track: null);

    testWidgets('the filter reads only after the write ended', (tester) async {
      final removal = Completer<bool>();
      final reads = <List<String>>[];
      final rows = [entry(1), entry(2)];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioBackendProvider.overrideWithValue(FakeAudioBackend()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PlaylistEntriesView(
                head: PlaylistPageHead(
                  playlist: PlaylistSummary(
                    id: 1,
                    name: 'Mix',
                    createdAt: 1,
                    entryCount: rows.length,
                  ),
                  coverKeys: const [],
                  hasPlayable: false,
                ),
                loadRows: (start, count) async => [
                  for (var i = start; i < start + count && i < rows.length; i++)
                    PlaylistPositionedEntry(i, rows[i]),
                ],
                onRemove: (_) => removal.future,
                onSettled: () => 1,
                onPlayFrom: (_, _) async {},
                loadMatches: (terms) async {
                  reads.add(terms);
                  return PlaylistMatches.empty;
                },
                onPlayRows: (_, _) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await hoverRow(tester, 0);
      await tester.tap(find.byTooltip('Remove from playlist').first);
      await tester.pump();
      await filterBy(tester, 'abc');
      expect(reads, isEmpty);

      await tester.runAsync(() async => removal.complete(true));
      await tester.pumpAndSettle();

      expect(reads, [
        ['abc'],
      ]);
    });
  });
}
