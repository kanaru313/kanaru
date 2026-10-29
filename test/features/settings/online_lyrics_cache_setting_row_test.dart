import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_actions.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status_provider.dart';
import 'package:kanaru/features/settings/online_lyrics_cache_setting_row.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/fake_lyrics_provider.dart';
import '../../core/lyrics/online/status_test_rig.dart';
import 'online_lyrics_switch_harness.dart';
import 'translation_settings_harness.dart' show pumpIo;

void main() {
  final clearButton = find.widgetWithText(FilledButton, 'Clear');

  /// One transaction: separate writes would queue behind the stats stream's
  /// re-read, which only the test clock can run.
  Future<void> seed(WidgetTester tester, LyricsRowsHarness r) =>
      tester.runAsync(
        () => r.h.db.transaction(() async {
          final db = r.h.db;
          for (final n in ['1', '2']) {
            await db.saveOnlineLyrics(
              OnlineLyricsCompanion.insert(
                cacheKey: 'k$n',
                providerId: 'fake',
                status: 'found',
                remoteId: Value(n),
                syncedText: const Value('abc'),
                fetchedAt: 1,
              ),
            );
          }
          await db.saveOnlineLyrics(
            OnlineLyricsCompanion.insert(
              cacheKey: 'k3',
              providerId: 'fake',
              status: 'not_found',
              fetchedAt: 1,
            ),
          );
          await db.pinLyrics(
            LyricsPinsCompanion.insert(
              trackKey: '/m/p.flac',
              pinnedAt: 1,
              providerId: const Value('fake'),
              remoteId: const Value('9'),
              plainText: const Value('de'),
            ),
          );
          await db.rejectOnlineLyrics(
            cacheKey: 'k9',
            providerId: 'fake',
            remoteId: '8',
            trackKey: '/m/q.flac',
            now: 1,
          );
        }),
      );

  Future<List<int>> tableSizes(WidgetTester tester, LibraryDatabase db) async =>
      (await tester.runAsync(
        () async => [
          (await db.select(db.onlineLyrics).get()).length,
          (await db.select(db.lyricsPins).get()).length,
          (await db.select(db.onlineLyricsRejects).get()).length,
        ],
      ))!;

  testWidgets('shows the stats live; Clear is off at zero', (tester) async {
    final r = await LyricsRowsHarness.create(
      tester,
      const OnlineLyricsCacheSettingRow(),
    );
    await pumpIo(tester);
    expect(find.text('No saved lyrics'), findsOneWidget);
    expect(tester.widget<FilledButton>(clearButton).onPressed, isNull);

    await seed(tester, r);
    // Two found rows and one pick; a reject is no song.
    await pumpIo(
      tester,
      done: () => find
          .text('3 songs · 8 B · 1 not found (retried after 14 days)')
          .evaluate()
          .isNotEmpty,
    );
    expect(tester.widget<FilledButton>(clearButton).onPressed, isNotNull);
  });

  for (final (name, write)
      in <(String, Future<void> Function(LibraryDatabase))>[
        (
          'only a lyrics choice',
          (db) => db.pinLyrics(
            LyricsPinsCompanion.insert(
              trackKey: '/m/s.flac',
              pinnedAt: 1,
              mode: const Value('off'),
            ),
          ),
        ),
        (
          'only a rejected match',
          (db) => db.transaction(() async {
            await db.rejectOnlineLyrics(
              cacheKey: 'k9',
              providerId: 'fake',
              remoteId: '8',
              trackKey: '/m/q.flac',
              now: 1,
            );
            await db.removeLyricsPin('/m/q.flac');
          }),
        ),
      ]) {
    testWidgets('$name counts no song but can still be cleared', (
      tester,
    ) async {
      final r = await LyricsRowsHarness.create(
        tester,
        const OnlineLyricsCacheSettingRow(),
      );
      await pumpIo(tester);
      await tester.runAsync(() => write(r.h.db));
      await pumpIo(
        tester,
        done: () => find.textContaining('0 songs').evaluate().isNotEmpty,
      );
      expect(tester.widget<FilledButton>(clearButton).onPressed, isNotNull);
    });
  }

  testWidgets(
    'Clear asks first, then clears found, not found, picks and rejects',
    (tester) async {
      final r = await LyricsRowsHarness.create(
        tester,
        const OnlineLyricsCacheSettingRow(),
      );
      await seed(tester, r);
      await pumpIo(
        tester,
        done: () => tester.widget<FilledButton>(clearButton).onPressed != null,
      );

      await tester.tap(clearButton);
      await tester.pumpAndSettle();
      expect(find.text('Clear saved lyrics?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await pumpIo(tester);
      expect((await tableSizes(tester, r.h.db)).every((n) => n > 0), isTrue);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(clearButton);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Clear'),
        ),
      );
      await pumpIo(
        tester,
        done: () => find.text('Saved lyrics cleared').evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();

      expect(await tableSizes(tester, r.h.db), [0, 0, 0]);
      expect(find.text('No saved lyrics'), findsOneWidget);
      expect(tester.widget<FilledButton>(clearButton).onPressed, isNull);
    },
  );

  testWidgets('without a library the button is off', (tester) async {
    await LyricsRowsHarness.create(
      tester,
      const OnlineLyricsCacheSettingRow(),
      withDatabase: false,
    );
    await pumpIo(tester);
    expect(tester.widget<FilledButton>(clearButton).onPressed, isNull);
    expect(find.text('No saved lyrics'), findsOneWidget);
  });

  group('the playing song after Clear (auto lookup off)', () {
    test('a saved answer is dropped and nothing is requested', () async {
      final rig = await createStatusRig(autoFetch: false);
      final song = fakeSong('/m/a.flac');
      await rig.h.db.saveOnlineLyrics(
        OnlineLyricsCompanion.insert(
          cacheKey: LyricsTarget.fromTrack(song).cacheKey,
          providerId: 'fake',
          status: 'found',
          remoteId: const Value('1'),
          syncedText: const Value('[00:01.00] hello'),
          fetchedAt: rig.h.now.millisecondsSinceEpoch,
        ),
      );
      rig.watch();
      await rig.play([song]);
      await rig.until(() => rig.status is LyricsFound);

      await rig.h.db.clearOnlineLyrics();
      await rig.until(() => rig.status is LyricsNone);
      await rig.settle();

      expect((rig.status as LyricsNone).reason, LyricsNoneReason.noLyrics);
      expect(rig.requests, 0);
    });

    test('after a manual lookup, Clear sends no further request', () async {
      final rig = await createStatusRig(autoFetch: false);
      rig.fake.lookupResult = fakeCandidate();
      final song = fakeSong('/m/a.flac');
      rig.watch();
      await rig.play([song]);
      await rig.until(() => rig.status is LyricsNone);

      await rig.container
          .read(onlineLyricsActionsProvider)
          .retry(LyricsTarget.fromTrack(song));
      await rig.until(() => rig.status is LyricsFound);
      final before = rig.requests;
      expect(before, 1);

      await rig.h.db.clearOnlineLyrics();
      await rig.until(() => rig.status is LyricsNone);
      await rig.settle();

      expect((rig.status as LyricsNone).reason, LyricsNoneReason.noLyrics);
      expect(rig.requests, before);
    });
  });
}
