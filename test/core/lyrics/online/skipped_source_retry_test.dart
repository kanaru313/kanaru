import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_backoff.dart';

import 'status_test_rig.dart';

void main() {
  test('a skipped source is not asked again at every debounce', () async {
    final rig = await createStatusRig();
    rig.fake.lookupResult = const LyricsSourceSkipped();
    rig.watch();
    await rig.play([fakeSong('/m/a.flac')]);
    await rig.until(() => rig.fake.lookupCalls == 1);

    // Many debounce periods later (the default wait is 30 s) it is still one.
    await rig.settle();
    await rig.settle();

    expect(rig.fake.lookupCalls, 1);
  });

  test('it is asked again after the wait', () async {
    final rig = await createStatusRig(
      overrides: [
        onlineLyricsSkipRetryProvider.overrideWithValue(
          const Duration(milliseconds: 150),
        ),
      ],
    );
    rig.fake.lookupResult = const LyricsSourceSkipped();
    rig.watch();
    await rig.play([fakeSong('/m/a.flac')]);
    await rig.until(() => rig.fake.lookupCalls == 1);
    await rig.settle();
    expect(rig.fake.lookupCalls, 1);

    await rig.until(() => rig.fake.lookupCalls >= 2);
    // Once the source runs, nothing more is asked.
    rig.fake.lookupResult = null;
    rig.fake.searchResult = const [];
    await rig.until(() => rig.fake.lookupCalls >= 3);
    await rig.settle();
    await rig.settle();
    expect(rig.fake.lookupCalls, 3);
  });

  test('leaving the song drops the pending retry', () async {
    final rig = await createStatusRig(
      overrides: [
        onlineLyricsSkipRetryProvider.overrideWithValue(
          const Duration(milliseconds: 150),
        ),
      ],
    );
    rig.fake.lookupResult = const LyricsSourceSkipped();
    rig.watch();
    await rig.play([fakeSong('/m/a.flac')]);
    await rig.until(() => rig.fake.lookupCalls == 1);

    rig.unwatch();
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(rig.fake.lookupCalls, 1);
  });
}
