import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_actions.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_lookups.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status_provider.dart';
import 'package:kanaru/features/settings/online_lyrics_cache_setting_row.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/fake_lyrics_provider.dart';
import '../../core/lyrics/online/lookup_test_harness.dart';
import '../../core/lyrics/online/status_test_rig.dart';
import 'online_lyrics_switch_harness.dart';
import 'translation_settings_harness.dart' show pumpIo;

void main() {
  final clearButton = find.widgetWithText(FilledButton, 'Clear');

  Future<void> confirmClear(WidgetTester tester) async {
    await tester.tap(clearButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Clear'),
      ),
    );
    await pumpIo(tester);
    await tester.pumpAndSettle();
  }

  Future<LyricsRowsHarness> rowsWithStoredData(WidgetTester tester) async {
    final r = await LyricsRowsHarness.create(
      tester,
      const OnlineLyricsCacheSettingRow(),
      autoConsent: true,
      manualConsent: true,
    );
    await tester.runAsync(
      () => r.h.db.saveOnlineLyrics(
        OnlineLyricsCompanion.insert(
          cacheKey: 'other',
          providerId: 'fake',
          status: 'not_found',
          fetchedAt: 1,
        ),
      ),
    );
    await pumpIo(tester);
    return r;
  }

  group('Clear forgets what went wrong', () {
    testWidgets('a failed lookup and the pause are dropped', (tester) async {
      final r = await rowsWithStoredData(tester);
      final fake = r.registration.provider as FakeLyricsProvider;
      fake.lookupResult = const LyricsFetchException(LyricsFetchKind.server);
      await tester.runAsync(() => r.h.lookups.start(fakeTarget, auto: false));
      expect(
        r.container.read(onlineLyricsLookupsProvider)[fakeTarget.cacheKey],
        isA<LookupFailed>(),
      );
      expect(r.h.backoff.isBlocked, isTrue);

      await confirmClear(tester);

      expect(r.container.read(onlineLyricsLookupsProvider), isEmpty);
      expect(r.h.backoff.isBlocked, isFalse);
    });

    testWidgets('a clear that fails keeps the failure and the pause', (
      tester,
    ) async {
      final r = await rowsWithStoredData(tester);
      final fake = r.registration.provider as FakeLyricsProvider;
      fake.lookupResult = const LyricsFetchException(LyricsFetchKind.server);
      await tester.runAsync(() => r.h.lookups.start(fakeTarget, auto: false));
      // A delete that always aborts makes the clear throw.
      await tester.runAsync(
        () => r.h.db.customStatement(
          'CREATE TRIGGER no_delete BEFORE DELETE ON online_lyrics '
          "BEGIN SELECT RAISE(ABORT, 'blocked'); END",
        ),
      );

      await confirmClear(tester);

      expect(find.text('Could not clear saved lyrics'), findsOneWidget);
      expect(
        r.container.read(onlineLyricsLookupsProvider)[fakeTarget.cacheKey],
        isA<LookupFailed>(),
      );
      expect(r.h.backoff.isBlocked, isTrue);
    });

    testWidgets('a lookup held open across Clear records no failure', (
      tester,
    ) async {
      final r = await rowsWithStoredData(tester);
      final fake = r.registration.provider as FakeLyricsProvider;
      fake.gate = Completer();
      fake.lookupResult = const LyricsFetchException(LyricsFetchKind.server);
      late Future<void> done;
      await tester.runAsync(() async {
        done = r.h.lookups.start(fakeTarget, auto: false);
        await Future<void>.delayed(Duration.zero);
      });
      expect(
        r.container.read(onlineLyricsLookupsProvider)[fakeTarget.cacheKey],
        isA<LookupRunning>(),
      );

      await confirmClear(tester);
      fake.gate!.complete();
      await tester.runAsync(() => done.timeout(const Duration(seconds: 5)));

      expect(r.container.read(onlineLyricsLookupsProvider), isEmpty);
      expect(r.h.backoff.isBlocked, isFalse);
    });
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
