import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/lyrics_plugin_spec.dart' show lrclibSourceId;
import '../plugins/lyrics_sources_provider.dart';
import 'lrclib_provider.dart';
import 'lyrics_provider_registry.dart';

export '../plugins/lyrics_sources_provider.dart'
    show lyricsSourcesLoadedProvider;

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

/// Every source whose stored lyrics may be shown, by provider id: LRCLIB (a
/// known provider, named even when turned off), the enabled sources and
/// every plugin record, installed (on or off) or removed. A removed record
/// is only a name for lyrics it saved. It decides what is listed and how it
/// is named; [lyricsProvidersProvider] decides what runs.
final lyricsSourceNamesProvider = Provider<Map<String, LyricsSourceName>>((
  ref,
) {
  final names = <String, LyricsSourceName>{
    lrclibSourceId: LyricsSourceName(displayName: LrclibProvider().displayName),
    for (final r in ref.watch(lyricsProvidersProvider))
      r.id: LyricsSourceName(displayName: r.displayName),
  };
  for (final record in ref.watch(lyricsPluginRecordsProvider)) {
    final author = record.author?.trim();
    names[record.installId] = LyricsSourceName(
      displayName: record.name,
      author: author == null || author.isEmpty ? null : author,
      removed: record.isRemoved,
    );
  }
  return _NameMap(names);
});

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
