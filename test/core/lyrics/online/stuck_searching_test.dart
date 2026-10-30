import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status_provider.dart';

import 'fake_lyrics_provider.dart';
import 'status_test_rig.dart';

void main() {
  group('Clear during an automatic lookup', () {
    test(
      'a failure dropped by Clear does not leave Searching for good',
      () async {
        final rig = await createStatusRig();
        rig.fake.gate = Completer<void>();
        rig.fake.lookupResult = const LyricsFetchException(
          LyricsFetchKind.server,
        );
        rig.watch();
        await rig.play([fakeSong('/m/a.flac')]);
        await rig.until(() => rig.h.lookups.state.isNotEmpty);

        // Settings Clear while the request is in flight, then it fails.
        rig.h.lookups.forgetFailures();
        rig.h.backoff.clear();
        rig.fake.gate!.complete();

        // The dropped failure is retried once and that failure is recorded.
        await rig.until(() => rig.status is LyricsNone && rig.requests == 2);
        expect((rig.status as LyricsNone).reason, LyricsNoneReason.error);
        await rig.settle();
        expect(rig.requests, 2);
        expect(rig.status, isNot(isA<LyricsSearching>()));
      },
    );

    test('a found answer after Clear is not requested again', () async {
      final rig = await createStatusRig();
      rig.fake.gate = Completer<void>();
      rig.fake.lookupResult = fakeCandidate();
      rig.watch();
      await rig.play([fakeSong('/m/a.flac')]);
      await rig.until(() => rig.h.lookups.state.isNotEmpty);

      rig.h.lookups.forgetFailures();
      rig.h.backoff.clear();
      rig.fake.gate!.complete();

      await rig.until(() => rig.status is! LyricsSearching);
      await rig.settle();
      await rig.settle();
      expect(rig.requests, 1);
      expect(rig.status, isNot(isA<LyricsSearching>()));
    });
  });
}
