import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/candidate_content_hash.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_actions.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status_provider.dart';

import 'fake_lyrics_provider.dart';
import 'status_test_rig.dart';

void main() {
  late StatusRig rig;
  final song = fakeSong('/m/a.flac');
  final target = LyricsTarget.fromTrack(song);

  OnlineLyricsActions actions() =>
      rig.container.read(onlineLyricsActionsProvider);
  LyricsFound found() => rig.status as LyricsFound;

  Future<LyricsCandidate> showAutoMatch() async {
    rig = await createStatusRig();
    final match = fakeCandidate(remoteId: 'x');
    rig.fake.lookupResult = match;
    rig.watch();
    await rig.play([song]);
    await rig.until(() => rig.status is LyricsFound);
    // A user taps frames later; let the one-shot lookup provider go first.
    await rig.settle();
    return match;
  }

  group('reject', () {
    test('an automatic match: flagged by id and by the shown text', () async {
      final match = await showAutoMatch();
      final shown = found();
      expect(rig.requests, 1);

      await actions().reject(target, shown.origin!, shown.lyrics);
      await rig.until(() => rig.status is LyricsNone);
      await rig.settle();

      final rejected = await rig.h.db.rejectedMatches(target.cacheKey);
      expect(rejected.ids, {('fake', 'x')});
      // The shown lyrics and the stored candidate come from the same parse,
      // so the hashes are equal.
      expect(rejected.hashes, {candidateContentHash(match)});
      // The cached copy is gone and automatic resolution ran again by itself:
      // the exact lookup is excluded, so one search follows.
      expect(rig.fake.lookupCalls, 2);
      expect(rig.fake.searchCalls, 1);
      expect((rig.status as LyricsNone).reason, LyricsNoneReason.notFound);
      expect(await rig.h.db.watchLyricsPin(target.trackKey).first, isNull);
    });

    test(
      'a cached copy of the text from another provider is dropped',
      () async {
        await showAutoMatch();
        final shown = found();
        await rig.h.db.saveOnlineLyrics(
          OnlineLyricsCompanion.insert(
            cacheKey: target.cacheKey,
            providerId: 'other',
            status: 'found',
            remoteId: const Value('copy'),
            syncedText: const Value('[00:09.00] hello'),
            fetchedAt: 1,
          ),
        );
        await rig.h.db.saveOnlineLyrics(
          OnlineLyricsCompanion.insert(
            cacheKey: target.cacheKey,
            providerId: 'third',
            status: 'found',
            remoteId: const Value('different'),
            plainText: const Value('other words'),
            fetchedAt: 1,
          ),
        );

        await actions().reject(target, shown.origin!, shown.lyrics);

        final rows = await rig.h.db.watchOnlineLyrics(target.cacheKey).first;
        expect(
          {for (final r in rows) (r.providerId, r.remoteId)},
          {('third', 'different')},
        );
      },
    );

    test('a pick: the pin goes and the song is resolved again', () async {
      rig = await createStatusRig();
      rig.watch();
      await rig.play([song]);
      await rig.until(() => rig.status is LyricsNone);
      await rig.settle();
      final pick = fakeCandidate(remoteId: 'p');
      await actions().pick(target, pick);
      await rig.until(() => rig.status is LyricsFound);
      await rig.settle();
      final shown = found();
      final requests = rig.requests;

      await actions().reject(target, shown.origin!, shown.lyrics);
      await rig.until(() => rig.status is LyricsNone);
      await rig.settle();

      expect(await rig.h.db.watchLyricsPin(target.trackKey).first, isNull);
      expect((await rig.h.db.rejectedMatches(target.cacheKey)).ids, {
        ('fake', 'p'),
      });
      // The earlier "no match" answer is still cached, so nothing is asked.
      expect((rig.status as LyricsNone).reason, LyricsNoneReason.notFound);
      expect(rig.requests, requests);
    });

    test('keeps the song\'s own lyrics', () async {
      rig = await createStatusRig();
      rig.sidecar.byPath['/m/a.flac'] = '[00:00.00]local';
      rig.watch();
      await rig.play([song]);
      await rig.until(() => rig.status is LyricsFound);
      await rig.settle();

      await actions().reject(
        target,
        const OnlineLyricsOrigin(
          providerId: 'fake',
          remoteId: 'x',
          pinned: false,
        ),
        found().lyrics,
      );
      await rig.settle();

      expect(found().origin, isNull);
      expect(found().lyrics.lines.single.text, 'local');
      expect(rig.requests, 0);
    });

    test('with only the rejected match available finds none', () async {
      await showAutoMatch();
      await actions().reject(target, found().origin!, found().lyrics);
      await rig.until(() => rig.status is LyricsNone);
      await rig.settle();

      expect((rig.status as LyricsNone).reason, LyricsNoneReason.notFound);
    });
  });
}
