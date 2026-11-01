import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/features/settings/online_lyrics_cache_setting_row.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/stats/gated_query_interceptor.dart';
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
    expect(find.text('Nothing saved'), findsOneWidget);
    expect(tester.widget<FilledButton>(clearButton).onPressed, isNull);

    await seed(tester, r);
    // Two found rows and one pick; the reject has its own segment.
    await pumpIo(
      tester,
      done: () => find
          .text('3 songs with lyrics · 8 B · 1 not found · 1 rejected')
          .evaluate()
          .isNotEmpty,
    );
    expect(tester.widget<FilledButton>(clearButton).onPressed, isNotNull);
  });

  Future<void> pin(LibraryDatabase db, String key, String mode) => db.pinLyrics(
    LyricsPinsCompanion.insert(trackKey: key, pinnedAt: 1, mode: Value(mode)),
  );

  for (final (name, write, text)
      in <(String, Future<void> Function(LibraryDatabase), String)>[
        (
          'only a lyrics choice',
          (db) => pin(db, '/m/s.flac', 'off'),
          '1 source choice',
        ),
        (
          'a choice of online without a pick and one from a newer build',
          // One transaction: separate writes queue behind the stats re-read.
          (db) => db.transaction(() async {
            await pin(db, '/m/s.flac', 'online');
            await pin(db, '/m/t.flac', 'future-mode');
          }),
          '2 source choices',
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
          '1 rejected',
        ),
      ]) {
    testWidgets('$name reads as itself and can still be cleared', (
      tester,
    ) async {
      final r = await LyricsRowsHarness.create(
        tester,
        const OnlineLyricsCacheSettingRow(),
      );
      await pumpIo(tester);
      await tester.runAsync(() => write(r.h.db));
      await pumpIo(tester, done: () => find.text(text).evaluate().isNotEmpty);
      expect(find.text('Nothing saved'), findsNothing);
      expect(tester.widget<FilledButton>(clearButton).onPressed, isNotNull);
    });
  }

  testWidgets('choices and picks are each counted once', (tester) async {
    final r = await LyricsRowsHarness.create(
      tester,
      const OnlineLyricsCacheSettingRow(),
    );
    await pumpIo(tester);
    await tester.runAsync(
      () => r.h.db.transaction(() async {
        await pin(r.h.db, '/m/a.flac', 'off');
        await pin(r.h.db, '/m/b.flac', 'local');
        await r.h.db.pinLyrics(
          LyricsPinsCompanion.insert(
            trackKey: '/m/c.flac',
            pinnedAt: 1,
            providerId: const Value('fake'),
            remoteId: const Value('9'),
            plainText: const Value('de'),
          ),
        );
      }),
    );
    await pumpIo(
      tester,
      done: () => find
          .text('1 song with lyrics · 2 B · 2 source choices')
          .evaluate()
          .isNotEmpty,
    );
  });

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
      expect(find.textContaining('.lrc files next to songs stay'), findsOne);
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
      expect(find.text('Nothing saved'), findsOneWidget);
      expect(tester.widget<FilledButton>(clearButton).onPressed, isNull);
    },
  );

  Future<void> startClear(WidgetTester tester) async {
    await tester.tap(clearButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Clear'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<(LyricsRowsHarness, GatedQueryInterceptor)> seeded(
    WidgetTester tester,
  ) async {
    final gate = GatedQueryInterceptor();
    final db = LibraryDatabase(NativeDatabase.memory().interceptWith(gate));
    addTearDown(db.close);
    final r = await LyricsRowsHarness.create(
      tester,
      const OnlineLyricsCacheSettingRow(),
      database: db,
    );
    await seed(tester, r);
    await pumpIo(
      tester,
      done: () => tester.widget<FilledButton>(clearButton).onPressed != null,
    );
    return (r, gate);
  }

  testWidgets('a clear in flight keeps the rebuilt row busy', (tester) async {
    final (r, gate) = await seeded(tester);
    final release = gate.holdNext('DELETE FROM');

    await startClear(tester);
    await pumpIo(tester, rounds: 2);
    expect(tester.widget<FilledButton>(clearButton).onPressed, isNull);

    // The row is disposed and built again while the delete is held.
    r.visible.value = false;
    await tester.pump();
    expect(clearButton, findsNothing);
    r.visible.value = true;
    await tester.pump();
    expect(tester.widget<FilledButton>(clearButton).onPressed, isNull);

    release();
    await pumpIo(
      tester,
      done: () => find.text('Saved lyrics cleared').evaluate().isNotEmpty,
    );
    expect(find.byType(SnackBar), findsOneWidget);
    expect(await tableSizes(tester, r.h.db), [0, 0, 0]);
  });

  testWidgets('a failed clear is announced and the button comes back', (
    tester,
  ) async {
    final (_, gate) = await seeded(tester);
    gate.failNext('DELETE FROM');

    await startClear(tester);
    await pumpIo(
      tester,
      done: () => find.byType(SnackBar).evaluate().isNotEmpty,
    );

    expect(find.text('Could not clear saved lyrics'), findsOneWidget);
    expect(tester.widget<FilledButton>(clearButton).onPressed, isNotNull);
  });

  testWidgets('without a library the button is off', (tester) async {
    await LyricsRowsHarness.create(
      tester,
      const OnlineLyricsCacheSettingRow(),
      withDatabase: false,
    );
    await pumpIo(tester);
    expect(tester.widget<FilledButton>(clearButton).onPressed, isNull);
    expect(find.text('Nothing saved'), findsOneWidget);
  });
}
