import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';

import 'fake_lyrics_provider.dart';
import 'status_test_rig.dart';

const _song = '/m/a.flac';

void main() {
  late StatusRig rig;
  late FakeLyricsProvider second;

  setUp(() async {
    second = FakeLyricsProvider(id: 'second');
    rig = await createStatusRig(others: [second]);
  });

  test('the first source is paused: the second one is asked', () async {
    rig.h.backoff.failed('fake');
    rig.watch();
    await rig.play([fakeSong(_song)]);
    await rig.until(() => second.lookupCalls > 0);
    await rig.settle();

    expect(rig.fake.lookupCalls + rig.fake.searchCalls, 0);
    expect(second.lookupCalls, 1);
  });

  test(
    'every source paused: nothing runs, the earliest end is shown',
    () async {
      rig.h.backoff.failed('fake', const Duration(minutes: 5));
      rig.h.backoff.failed('second');
      rig.watch();
      await rig.play([fakeSong(_song)]);
      await rig.until(() => rig.status is LyricsNone);
      await rig.settle();

      final none = rig.status as LyricsNone;
      expect(none.reason, LyricsNoneReason.paused);
      expect(none.resumeAt, rig.h.now.add(const Duration(seconds: 60)));
      expect(rig.requests, 0);
    },
  );

  test('a source paused for a minute is asked again when it ends', () async {
    rig.h.backoff.failed('fake');
    rig.h.backoff.failed('second');
    rig.watch();
    await rig.play([fakeSong(_song)]);
    await rig.until(() => rig.status is LyricsNone);

    rig.h.now = rig.h.now.add(const Duration(seconds: 61));
    await rig.rewatch();
    await rig.until(() => rig.fake.lookupCalls > 0);

    expect(rig.fake.lookupCalls, 1);
  });
}
