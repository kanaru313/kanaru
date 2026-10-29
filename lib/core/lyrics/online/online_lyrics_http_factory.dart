import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/settings_provider.dart';
import 'lyrics_fetch_exception.dart';
import 'lyrics_http.dart';
import 'lyrics_provider_registry.dart';

/// The single place a [LyricsHttp] is made for the app. It hands one out only
/// when the user's recorded consent covers the request, so no host path
/// (automatic lookup, Retry, Search again, the Choose lyrics dialog) can
/// reach the network without it.
///
/// Consent is read when asked for, not when the factory is made, so
/// withdrawing it takes effect at once. The shared [HttpClient] is created
/// on the first allowed request; a refusal opens nothing.
class OnlineLyricsHttpFactory {
  OnlineLyricsHttpFactory({required this._acknowledged, required this._client});

  final Set<String> Function() _acknowledged;
  final HttpClient Function() _client;

  /// For a request the user started (a search in the dialog, Retry, Search
  /// again). Needs the provider's manual consent key. Throws
  /// `LyricsFetchException(notConsented)` before any socket otherwise.
  LyricsHttp forManual(LyricsProviderRegistration registration) =>
      _make(registration, registration.consentKey);

  /// For a lookup Kanaru starts by itself. Needs the provider's separate
  /// automatic key; the manual key is not enough.
  LyricsHttp forAuto(LyricsProviderRegistration registration) =>
      _make(registration, registration.autoConsentKey);

  LyricsHttp _make(LyricsProviderRegistration registration, String key) {
    if (!_acknowledged().contains(key)) {
      throw const LyricsFetchException(LyricsFetchKind.notConsented);
    }
    return LyricsHttp(registration, _client());
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

/// The consent-checking [LyricsHttp] source. Reads the settings and the
/// client lazily, on each request.
final onlineLyricsHttpFactoryProvider = Provider<OnlineLyricsHttpFactory>(
  (ref) => OnlineLyricsHttpFactory(
    acknowledged: () =>
        ref.read(settingsProvider).onlineLyrics.noticeAcknowledged,
    client: () => ref.read(lyricsHttpClientProvider),
  ),
);
