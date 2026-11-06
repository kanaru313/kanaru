import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http_retry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_http_factory.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'counting_http_client.dart';
import 'support/http_test_lyrics_provider.dart';

void main() {
  final testSource = LyricsProviderRegistration(HttpTestLyricsProvider());
  late CountingHttpClient client;

  ProviderContainer containerWith(OnlineLyricsPrefs prefs) {
    client = CountingHttpClient();
    final container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(
          AppSettings(onlineLyrics: prefs),
        ),
        lyricsHttpClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  LyricsFetchKind? kindOf(void Function() call) {
    try {
      call();
    } on LyricsFetchException catch (e) {
      return e.kind;
    }
    return null;
  }

  test('without consent both are refused and no socket is opened', () async {
    final factory = containerWith(const OnlineLyricsPrefs())
        .read(onlineLyricsHttpFactoryProvider);

    expect(
      kindOf(() => factory.forManual(testSource)),
      LyricsFetchKind.notConsented,
    );
    expect(
      kindOf(() => factory.forAuto(testSource)),
      LyricsFetchKind.notConsented,
    );
    expect(client.opened, 0);
  });

  test('the manual consent allows manual but refuses auto', () async {
    final factory = containerWith(const OnlineLyricsPrefs(manualConsent: true))
        .read(onlineLyricsHttpFactoryProvider);

    expect(kindOf(() => factory.forManual(testSource)), isNull);
    expect(
      kindOf(() => factory.forAuto(testSource)),
      LyricsFetchKind.notConsented,
    );
    expect(client.opened, 0);
  });

  test('the automatic consent alone allows auto and refuses manual', () {
    final factory = containerWith(const OnlineLyricsPrefs(autoConsent: true))
        .read(onlineLyricsHttpFactoryProvider);

    expect(kindOf(() => factory.forAuto(testSource)), isNull);
    expect(
      kindOf(() => factory.forManual(testSource)),
      LyricsFetchKind.notConsented,
    );
  });

  test('both consents allow both', () {
    final factory = containerWith(
      const OnlineLyricsPrefs(manualConsent: true, autoConsent: true),
    ).read(onlineLyricsHttpFactoryProvider);

    expect(kindOf(() => factory.forManual(testSource)), isNull);
    expect(kindOf(() => factory.forAuto(testSource)), isNull);
  });

  test('consent given later is seen by an existing factory', () {
    final container = containerWith(const OnlineLyricsPrefs());
    final factory = container.read(onlineLyricsHttpFactoryProvider);
    expect(
      kindOf(() => factory.forManual(testSource)),
      LyricsFetchKind.notConsented,
    );

    container
        .read(settingsProvider.notifier)
        .acknowledgeOnlineLyricsNotice(auto: false);

    expect(kindOf(() => factory.forManual(testSource)), isNull);
  });

  test('consent is checked again before every send of the same client', () {
    var prefs = const OnlineLyricsPrefs(manualConsent: true);
    final unused = CountingHttpClient();
    final factory = OnlineLyricsHttpFactory(
      prefs: () => prefs,
      client: () => unused,
    );
    final http = factory.forManual(testSource);
    prefs = const OnlineLyricsPrefs();

    expect(
      http.get(Uri.parse('https://lyrics.test.net/api/get')),
      throwsA(
        isA<LyricsFetchException>().having(
          (e) => e.kind,
          'kind',
          LyricsFetchKind.notConsented,
        ),
      ),
    );
    expect(unused.opened, 0);
  });

  test('a manual client asks abandoned before every send', () {
    final unused = CountingHttpClient();
    final factory = OnlineLyricsHttpFactory(
      prefs: () => const OnlineLyricsPrefs(manualConsent: true),
      client: () => unused,
    );
    var abandoned = false;
    final http = factory.forManual(testSource, abandoned: () => abandoned);
    abandoned = true;

    expect(
      http.get(Uri.parse('https://lyrics.test.net/api/get')),
      throwsA(isA<LyricsRequestAbandoned>()),
    );
    expect(unused.opened, 0);
  });

  test('the default client times out connecting after 10 s and closes', () {
    final container = ProviderContainer();
    final client = container.read(lyricsHttpClientProvider);

    expect(client.connectionTimeout, const Duration(seconds: 10));
    container.dispose();
    expect(
      () => client.getUrl(Uri.parse('https://lyrics.test.net')),
      throwsA(isA<StateError>()),
    );
  });
}
