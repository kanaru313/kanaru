import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../core/database/home_queries.dart';
import '../../core/database/home_windows.dart';
import '../../core/database/library_database.dart';
import '../../core/database/library_startup.dart';
import 'home_data_version.dart';

export 'home_data_version.dart' show homeClockProvider;

final _log = Logger('home');

/// Rows read for each shelf of the page.
const homeShelfLimit = 20;

/// Reads are not retried by Riverpod's default back-off: a failed read shows
/// the old rows (or none), and the next change reads again.
Duration? _noRetry(int count, Object error) => null;

/// Runs [read] and logs the type of a failure (never its message, as SQLite
/// puts the statement's parameters in it) before passing it on.
Future<T> _logged<T>(String what, Future<T> Function() read) async {
  try {
    return await read();
  } on Object catch (error) {
    _log.warning('Reading $what failed: ${error.runtimeType}');
    rethrow;
  }
}

/// The "recently added" chip the user picked, null until they pick one. Not
/// auto-disposed: the pick lasts for the whole session.
final homeAddedWindowChoiceProvider =
    NotifierProvider<HomeAddedWindowChoice, HomeAddedWindow?>(
      HomeAddedWindowChoice.new,
    );

class HomeAddedWindowChoice extends Notifier<HomeAddedWindow?> {
  @override
  HomeAddedWindow? build() => null;

  /// Remembers [window] as the chip to show.
  void select(HomeAddedWindow window) => state = window;
}

/// The latest `added_at` in the library, null when it is empty.
final homeNewestAddedAtProvider = FutureProvider.autoDispose<int?>((ref) async {
  final db = ref.watch(libraryDatabaseProvider);
  ref.watch(homeDataVersionProvider);
  if (db == null) return null;
  return _logged('the newest added track', db.homeNewestAddedAt);
}, retry: _noRetry);

/// The chip in effect: the user's pick, else the smallest window that holds
/// the newest track added.
final homeEffectiveAddedWindowProvider =
    FutureProvider.autoDispose<HomeAddedWindow>((ref) async {
      final picked = ref.watch(homeAddedWindowChoiceProvider);
      if (picked != null) return picked;
      final newest = await ref.watch(homeNewestAddedAtProvider.future);
      return defaultAddedWindow(newest, ref.read(homeClockProvider)());
    }, retry: _noRetry);

/// Whether the library holds any track; the page shows nothing else when not.
final homeHasTracksProvider = FutureProvider.autoDispose<bool>((ref) async {
  final db = ref.watch(libraryDatabaseProvider);
  ref.watch(homeDataVersionProvider);
  if (db == null) return false;
  return _logged('the library state', db.homeHasTracks);
}, retry: _noRetry);

/// Tracks by their latest listen, newest first.
final homeRecentlyPlayedProvider =
    FutureProvider.autoDispose<List<TrackListItem>>((ref) async {
      final db = ref.watch(libraryDatabaseProvider);
      ref.watch(homeDataVersionProvider);
      if (db == null) return const [];
      return _logged(
        'the recently played tracks',
        () => db.homeRecentlyPlayed(limit: homeShelfLimit),
      );
    }, retry: _noRetry);

/// Tracks added inside the chip in effect, newest first.
final homeRecentlyAddedProvider =
    FutureProvider.autoDispose<List<TrackListItem>>((ref) async {
      final db = ref.watch(libraryDatabaseProvider);
      ref.watch(homeDataVersionProvider);
      final window = await ref.watch(homeEffectiveAddedWindowProvider.future);
      if (db == null) return const [];
      final since = addedWindowSince(window, ref.read(homeClockProvider)());
      return _logged(
        'the recently added tracks',
        () => db.homeRecentlyAdded(since: since, limit: homeShelfLimit),
      );
    }, retry: _noRetry);

/// Tracks played around today's date last year, most played first.
final homeMemoriesProvider = FutureProvider.autoDispose<List<TrackListItem>>((
  ref,
) async {
  final db = ref.watch(libraryDatabaseProvider);
  ref.watch(homeDataVersionProvider);
  if (db == null) return const [];
  final window = memoriesWindow(ref.read(homeClockProvider)());
  return _logged(
    'the memories',
    () => db.homeMemories(
      start: window.start,
      end: window.end,
      limit: homeShelfLimit,
    ),
  );
}, retry: _noRetry);

/// Albums by their latest listen.
final homeRecentAlbumsProvider = FutureProvider.autoDispose<List<AlbumSummary>>(
  (ref) async {
    final db = ref.watch(libraryDatabaseProvider);
    ref.watch(homeDataVersionProvider);
    if (db == null) return const [];
    return _logged(
      'the recent albums',
      () => db.homeRecentAlbums(limit: homeShelfLimit),
    );
  },
  retry: _noRetry,
);

/// Artists by their latest listen.
final homeRecentArtistsProvider =
    FutureProvider.autoDispose<List<ArtistCredit>>((ref) async {
      final db = ref.watch(libraryDatabaseProvider);
      ref.watch(homeDataVersionProvider);
      if (db == null) return const [];
      return _logged(
        'the recent artists',
        () => db.homeRecentArtists(limit: homeShelfLimit),
      );
    }, retry: _noRetry);
