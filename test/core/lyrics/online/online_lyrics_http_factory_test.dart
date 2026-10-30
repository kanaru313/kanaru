import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lrclib_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http_retry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_http_factory.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'counting_http_client.dart';

void main() {
  final lrclib = LyricsProviderRegistration(LrclibProvider());
  late CountingHttpClient client;

  ProviderContainer containerWith(Set<String> acknowledged) {
    client = CountingHttpClient();
    final container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(
          AppSettings(
            onlineLyrics: OnlineLyricsPrefs(noticeAcknowledged: acknowledged),
          ),
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

  test('without any key both are refused and no socket is opened', () async {
    final factory = containerWith({}).read(onlineLyricsHttpFactoryProvider);

    expect(
      kindOf(() => factory.forManual(lrclib)),
      LyricsFetchKind.notConsented,
    );
    expect(kindOf(() => factory.forAuto(lrclib)), LyricsFetchKind.notConsented);
    expect(client.opened, 0);
  });

  test('the manual key allows manual but refuses auto', () async {
    final factory = containerWith({lrclib.consentKey})
        .read(onlineLyricsHttpFactoryProvider);

    expect(kindOf(() => factory.forManual(lrclib)), isNull);
    expect(kindOf(() => factory.forAuto(lrclib)), LyricsFetchKind.notConsented);
    expect(client.opened, 0);
  });

  test('the auto key allows both', () {
    final factory = containerWith({lrclib.consentKey, lrclib.autoConsentKey})
        .read(onlineLyricsHttpFactoryProvider);

    expect(kindOf(() => factory.forManual(lrclib)), isNull);
    expect(kindOf(() => factory.forAuto(lrclib)), isNull);
  });

  test('a key of the same id at other hosts is not consent', () {
    final factory = containerWith({
      'lrclib@elsewhere.example',
      'lrclib@elsewhere.example:auto',
    }).read(onlineLyricsHttpFactoryProvider);

    expect(
      kindOf(() => factory.forManual(lrclib)),
      LyricsFetchKind.notConsented,
    );
  });

  test('consent given later is seen by an existing factory', () {
    final container = containerWith({});
    final factory = container.read(onlineLyricsHttpFactoryProvider);
    expect(
      kindOf(() => factory.forManual(lrclib)),
      LyricsFetchKind.notConsented,
    );

    container
        .read(settingsProvider.notifier)
        .acknowledgeOnlineLyricsNotice(lrclib.consentKey);

    expect(kindOf(() => factory.forManual(lrclib)), isNull);
  });

  test('consent is checked again before every send of the same client', () {
    final acknowledged = {lrclib.consentKey};
    final unused = CountingHttpClient();
    final factory = OnlineLyricsHttpFactory(
      acknowledged: () => acknowledged,
      client: () => unused,
    );
    final http = factory.forManual(lrclib);
    acknowledged.clear();

    expect(
      http.get(Uri.parse('https://lrclib.net/api/get')),
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
      acknowledged: () => {lrclib.consentKey},
      client: () => unused,
    );
    var abandoned = false;
    final http = factory.forManual(lrclib, abandoned: () => abandoned);
    abandoned = true;

    expect(
      http.get(Uri.parse('https://lrclib.net/api/get')),
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
      () => client.getUrl(Uri.parse('https://lrclib.net')),
      throwsA(isA<StateError>()),
    );
  });
}
