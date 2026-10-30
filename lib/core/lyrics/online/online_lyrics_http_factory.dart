import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/settings_provider.dart';
import 'lyrics_fetch_exception.dart';
import 'lyrics_http.dart';
import 'lyrics_http_retry.dart';
import 'lyrics_provider_registry.dart';

/// The single place a [LyricsHttp] is made for the app. It hands one out only
/// when the user's recorded consent covers the request, so no host path
/// (automatic lookup, Retry, Search again, the Choose lyrics dialog) can
/// reach the network without it.
///
/// Consent is read when asked for and again before every send of the
/// [LyricsHttp] handed out (retries and a second request included), so
/// withdrawing it takes effect at once. The shared [HttpClient] is created
/// on the first allowed request; a refusal opens nothing.
class OnlineLyricsHttpFactory {
  OnlineLyricsHttpFactory({
    required this._prefs,
    required this._client,
    this._sleep = realLyricsSleep,
  });

  final OnlineLyricsPrefs Function() _prefs;
  final HttpClient Function() _client;
  final LyricsSleep _sleep;

  /// For a request the user started (a search in the dialog, Retry, Search
  /// again). Needs the manual consent. Throws
  /// `LyricsFetchException(notConsented)` before any socket otherwise.
  /// [abandoned], when given, is asked before every send like in [forAuto]:
  /// a search that a newer one replaced sends nothing more.
  LyricsHttp forManual(
    LyricsProviderRegistration registration, {
    bool Function()? abandoned,
  }) => _make(registration, (p) => p.manualConsent, abandoned);

  /// For a lookup Kanaru starts by itself. Needs the separate automatic
  /// consent; the manual one is not enough. [abandoned] is asked before
  /// every send, the first one included; once it is true no further request
  /// goes out.
  LyricsHttp forAuto(
    LyricsProviderRegistration registration, {
    bool Function()? abandoned,
  }) => _make(registration, (p) => p.autoConsent, abandoned);

  LyricsHttp _make(
    LyricsProviderRegistration registration,
    bool Function(OnlineLyricsPrefs) consent,
    bool Function()? abandoned,
  ) {
    if (!consent(_prefs())) {
      throw const LyricsFetchException(LyricsFetchKind.notConsented);
    }
    return LyricsHttp(
      registration,
      _client(),
      sleep: _sleep,
      abandoned: abandoned,
      allowed: () => consent(_prefs()),
    );
  }
}

/// How long opening a connection may take.
const lyricsConnectTimeout = Duration(seconds: 10);

/// The shared client for online lyrics, closed with its container. Tests
/// override it.
final lyricsHttpClientProvider = Provider<HttpClient>((ref) {
  final client = HttpClient()..connectionTimeout = lyricsConnectTimeout;
  ref.onDispose(() => client.close(force: true));
  return client;
});

/// How the wait between two sends of a busy answer is spent; tests replace
/// it with a fake one.
final lyricsRetrySleepProvider = Provider<LyricsSleep>(
  (ref) => realLyricsSleep,
);

/// The consent-checking [LyricsHttp] source. Reads the settings and the
/// client lazily, on each request.
final onlineLyricsHttpFactoryProvider = Provider<OnlineLyricsHttpFactory>(
  (ref) => OnlineLyricsHttpFactory(
    prefs: () => ref.read(settingsProvider).onlineLyrics,
    client: () => ref.read(lyricsHttpClientProvider),
    sleep: (wait) => ref.read(lyricsRetrySleepProvider)(wait),
  ),
);
