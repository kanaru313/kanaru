import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_source_names.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_http_factory.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_lookups.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_streams.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'counting_http_client.dart';

/// A song every scripted candidate of [fakeCandidate] matches.
final fakeTarget = LyricsTarget.fromFields(
  uri: '/music/song.flac',
  title: 'Song',
  artist: 'Artist',
  album: 'Alb',
  duration: const Duration(seconds: 200),
);

/// Sends every request to [base] whatever its host, so a loopback server can
/// answer for `https://lrclib.net`. Counts the connections asked for.
class RewritingHttpClient implements HttpClient {
  RewritingHttpClient(this.base);

  final Uri base;
  final inner = HttpClient();
  int opened = 0;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    opened++;
    return inner.openUrl(
      method,
      base.replace(path: url.path, query: url.hasQuery ? url.query : null),
    );
  }

  @override
  void close({bool force = false}) => inner.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A container over an in-memory library, with a movable clock and a
/// jitter-free backoff.
class LyricsHarness {
  LyricsHarness._();

  late final ProviderContainer container;
  late final LibraryDatabase db;
  late final List<LyricsProviderRegistration> registrations;
  DateTime now = DateTime.utc(2026, 10, 29, 12);

  /// The random share of the backoff jitter, 0..1.
  double jitter = 0;

  OnlineLyricsLookups get lookups =>
      container.read(onlineLyricsLookupsProvider.notifier);
  OnlineLyricsBackoff get backoff =>
      container.read(onlineLyricsBackoffProvider.notifier);
}

/// [registrations] replaces the whole source list; `null` keeps the real one
/// (LRCLIB and the plugins in the database), for tests of the dynamic list.
Future<LyricsHarness> createHarness(
  List<LyricsProviderRegistration>? registrations, {
  HttpClient? client,
  bool autoFetch = true,
  bool autoConsent = true,
  bool manualConsent = true,
  bool withDatabase = true,
  bool forceSourcesLoaded = true,
  LibraryDatabase? database,
  List<Override> overrides = const [],
}) async {
  final harness = LyricsHarness._()..registrations = registrations ?? const [];
  // A database given by the test is closed by the test.
  harness.db = database ?? LibraryDatabase(NativeDatabase.memory());
  if (database == null) addTearDown(harness.db.close);
  harness.container = ProviderContainer(
    overrides: [
      initialSettingsProvider.overrideWithValue(
        AppSettings(
          onlineLyrics: OnlineLyricsPrefs(
            autoFetch: autoFetch,
            manualConsent: manualConsent,
            autoConsent: autoConsent,
          ),
        ),
      ),
      if (registrations != null)
        lyricsProvidersProvider.overrideWithValue(registrations),
      // The source list is ready at once unless a test of the loading gate
      // asks for [forceSourcesLoaded] false or passes its own override.
      if (forceSourcesLoaded)
        lyricsSourcesLoadedProvider.overrideWithValue(true),
      lyricsHttpClientProvider.overrideWithValue(
        client ?? CountingHttpClient(),
      ),
      libraryDatabaseProvider.overrideWithValue(
        withDatabase ? harness.db : null,
      ),
      onlineLyricsClockProvider.overrideWithValue(() => harness.now),
      onlineLyricsRandomProvider.overrideWithValue(() => harness.jitter),
      ...overrides,
    ],
  );
  addTearDown(harness.container.dispose);
  return harness;
}
