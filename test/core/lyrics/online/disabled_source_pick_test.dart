import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/lyrics_source_pref_queries.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_search_controller.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_actions.dart';

import 'bodyless_lyrics_provider.dart';
import 'fake_lyrics_provider.dart';
import 'lookup_test_harness.dart';

void main() {
  test('picking from a searched disabled source pins it and leaves settings '
      'alone', () async {
    final off = BodylessLyricsProvider(id: 'off');
    final h = await createHarness(
      [LyricsProviderRegistration(FakeLyricsProvider())],
      overrides: [
        disabledLyricsProvidersProvider.overrideWithValue([
          LyricsProviderRegistration(off),
        ]),
      ],
    );
    h.container.listen(lyricsSearchControllerProvider(fakeTarget), (_, _) {});
    final controller = h.container.read(
      lyricsSearchControllerProvider(fakeTarget).notifier,
    );
    await h.db
        .into(h.db.lyricsSourcePrefs)
        .insert(
          LyricsSourcePrefsCompanion.insert(
            providerId: 'off',
            enabled: const Value(false),
            position: 0,
          ),
        );
    off.searchResult = [fakeCandidate(providerId: 'off', body: null)];
    off.bodies['1'] = const LyricsBody(syncedLrc: '[00:01.00] words');

    await controller.search('artist song');
    expect(off.searchCalls, 0);
    await controller.searchDisabled();
    final state = h.container.read(lyricsSearchControllerProvider(fakeTarget));
    final picked = state.selection!.candidate;
    expect(picked.providerId, 'off');
    expect(picked.body, isNotNull);

    await h.container
        .read(onlineLyricsActionsProvider)
        .pick(fakeTarget, picked);

    final pin = await h.db.watchLyricsPin(fakeTarget.trackKey).first;
    expect(pin!.providerId, 'off');
    final prefs = await h.db.watchLyricsSourcePrefs().first;
    expect(prefs.single.providerId, 'off');
    expect(prefs.single.enabled, isFalse);
    expect(await h.db.watchOnlineLyrics(fakeTarget.cacheKey).first, isEmpty);

    final searches = off.searchCalls;
    await h.lookups.start(fakeTarget, auto: true);
    expect(off.searchCalls, searches);
    expect(off.lookupCalls, 0);
    expect(off.fetched, ['1']);
  });
}
