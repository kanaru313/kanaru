import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_search_controller.dart';
import 'package:kanaru/core/lyrics/online/lyrics_source_names.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';

import 'fake_lyrics_provider.dart';
import 'lookup_test_harness.dart';
import 'status_test_rig.dart';

class _Gate extends Notifier<bool> {
  @override
  bool build() => false;

  void open() => state = true;
}

final _gate = NotifierProvider<_Gate, bool>(_Gate.new);
final _gated = lyricsSourcesLoadedProvider.overrideWith(
  (ref) => ref.watch(_gate),
);

void main() {
  test('a cached-miss song sends nothing and reads until loaded', () async {
    final rig = await createStatusRig(overrides: [_gated]);
    rig.watch();
    await rig.play([fakeSong('/m/a.flac')]);
    await rig.settle();

    expect(rig.status, isA<LyricsReading>());
    expect(rig.requests, 0);
    expect(rig.statuses.whereType<LyricsSearching>(), isEmpty);

    rig.container.read(_gate.notifier).open();
    await rig.until(() => rig.fake.lookupCalls > 0);
    await rig.until(() => rig.status is LyricsNone);

    expect((rig.status as LyricsNone).reason, LyricsNoneReason.notFound);
  });

  test('a lookup waits for the sources, then runs', () async {
    final fake = FakeLyricsProvider();
    final h = await createHarness(
      [LyricsProviderRegistration(fake)],
      overrides: [_gated],
    );

    final done = h.lookups.start(fakeTarget, auto: false);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(fake.lookupCalls, 0);

    h.container.read(_gate.notifier).open();
    await done;
    expect(fake.lookupCalls, 1);
  });

  test('a manual search waits for the sources, then runs', () async {
    final fake = FakeLyricsProvider();
    final h = await createHarness(
      [LyricsProviderRegistration(fake)],
      overrides: [_gated],
    );
    final provider = lyricsSearchControllerProvider(fakeTarget);
    h.container.listen(provider, (_, _) {});

    final done = h.container.read(provider.notifier).search('Song');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(fake.searchCalls, 0);

    h.container.read(_gate.notifier).open();
    await done;
    expect(fake.searchCalls, 1);
  });
}
