import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lyrics_provider_registry.dart';

/// How the UI names one lyrics source it knows of.
class LyricsSourceName {
  const LyricsSourceName({
    required this.displayName,
    this.author,
    this.removed = false,
  });

  final String displayName;

  /// Who wrote the source, when it says.
  final String? author;

  /// The source is gone but its stored lyrics are still shown.
  final bool removed;

  @override
  bool operator ==(Object other) =>
      other is LyricsSourceName &&
      other.displayName == displayName &&
      other.author == author &&
      other.removed == removed;

  @override
  int get hashCode => Object.hash(displayName, author, removed);
}

/// An unmodifiable name map that is equal to another one with the same
/// entries, whatever their order, so a provider holding it notifies only
/// when a name changes, not on every rebuild.
class _NameMap extends UnmodifiableMapView<String, LyricsSourceName> {
  _NameMap(super.map);

  @override
  bool operator ==(Object other) =>
      other is _NameMap && mapEquals<String, LyricsSourceName>(this, other);

  // An XOR fold, so the order of the entries does not matter.
  @override
  int get hashCode =>
      entries.fold(0, (h, e) => h ^ Object.hash(e.key, e.value));
}

/// Every source whose stored lyrics may be shown, by provider id: the
/// enabled ones and, apart from them, sources that are known but do not run.
/// It decides what is listed and how it is named; [lyricsProvidersProvider]
/// decides what runs.
final lyricsSourceNamesProvider = Provider<Map<String, LyricsSourceName>>((
  ref,
) {
  final enabled = ref.watch(lyricsProvidersProvider);
  return _NameMap({
    for (final r in enabled) r.id: LyricsSourceName(displayName: r.displayName),
  });
});

/// Whether the list of sources is complete. Until it is, no row is listed
/// and no lookup starts, so a source still being loaded is not mistaken for
/// a missing one.
final lyricsSourcesLoadedProvider = Provider<bool>((ref) => true);

/// Completes once [lyricsSourcesLoadedProvider] is true; at once when it
/// already is. Also completes when [ref] is disposed first, so a waiting
/// caller never hangs: it must check that [ref] is still mounted after the
/// await.
Future<void> whenLyricsSourcesLoaded(Ref ref) {
  if (ref.read(lyricsSourcesLoadedProvider)) return Future.value();
  final done = Completer<void>();
  final sub = ref.listen<bool>(lyricsSourcesLoadedProvider, (_, loaded) {
    if (loaded && !done.isCompleted) done.complete();
  });
  ref.onDispose(() {
    if (!done.isCompleted) done.complete();
  });
  return done.future.whenComplete(sub.close);
}
