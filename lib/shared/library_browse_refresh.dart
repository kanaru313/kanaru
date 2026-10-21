import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shortest time between two reloads of the Albums, Artists, Songs and Search
/// results while the library changes (see `throttledTracksQuery`). Tests set
/// it to zero.
final libraryBrowseRefreshIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 2),
);
