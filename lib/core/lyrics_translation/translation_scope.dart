import 'package:flutter/foundation.dart';

import 'translation_service.dart';

/// Which choice decided the service of a song.
enum TranslationScope {
  /// The song's own choice.
  song,

  /// The playing queue's choice (the queue tier arrives with the queue).
  queue,

  /// The default service (Settings, or "All songs" in the Now Playing menu).
  all,
}

/// An explicit choice for one song or one queue: the service, its AI tune
/// (`model`/`style`, empty when none) and when it was made. [chosenAt] null
/// counts as older than any time.
@immutable
class ScopedTranslationChoice {
  const ScopedTranslationChoice({
    required this.service,
    this.tune = const {},
    this.chosenAt,
  });

  final TranslationServiceId service;
  final Map<String, String> tune;
  final int? chosenAt;

  @override
  bool operator ==(Object other) =>
      other is ScopedTranslationChoice &&
      other.service == service &&
      other.chosenAt == chosenAt &&
      mapEquals(other.tune, tune);

  @override
  int get hashCode => Object.hash(
    service,
    chosenAt,
    Object.hashAllUnordered([
      for (final e in tune.entries) Object.hash(e.key, e.value),
    ]),
  );
}

/// The service a song translates with, and which choice decided it.
@immutable
class TranslationChoice {
  const TranslationChoice({
    required this.service,
    required this.scope,
    required this.tune,
    required this.defaultService,
  });

  /// The winning service, or null when no tier names an installed plugin.
  final TranslationServiceId? service;
  final TranslationScope scope;

  /// The winning tier's AI tune; empty for [TranslationScope.all] (the
  /// plugin's shared settings apply).
  final Map<String, String> tune;

  /// The default service if its plugin is installed, else null. Shown as
  /// "default: NAME" next to a narrower choice.
  final TranslationServiceId? defaultService;

  @override
  bool operator ==(Object other) =>
      other is TranslationChoice &&
      other.service == service &&
      other.scope == scope &&
      other.defaultService == defaultService &&
      mapEquals(other.tune, tune);

  @override
  int get hashCode => Object.hash(
    service,
    scope,
    defaultService,
    Object.hashAllUnordered([
      for (final e in tune.entries) Object.hash(e.key, e.value),
    ]),
  );
}

/// `a` is strictly newer than `b`; null is older than any time.
bool _newer(int? a, int? b) {
  if (a == null) return false;
  if (b == null) return true;
  return a > b;
}

/// The newest explicit choice wins, compared strictly (null is older than
/// any time), so on a tie the broader tier wins:
///
/// * the song's choice wins when it is newer than the default's stamp
///   ([allChosenAt]) and than the queue's;
/// * else the queue's choice wins when newer than [allChosenAt];
/// * else the default.
///
/// A tier whose plugin is not in [live] counts as absent. Losing choices are
/// not deleted: a later, newer choice at a narrower tier wins again.
TranslationChoice resolveTranslationChoice({
  required TranslationServiceId? defaultService,
  required int? allChosenAt,
  required Set<TranslationServiceId> live,
  ScopedTranslationChoice? song,
  ScopedTranslationChoice? queue,
}) {
  final base = defaultService != null && live.contains(defaultService)
      ? defaultService
      : null;
  final s = song != null && live.contains(song.service) ? song : null;
  final q = queue != null && live.contains(queue.service) ? queue : null;
  if (s != null &&
      _newer(s.chosenAt, allChosenAt) &&
      (q == null || _newer(s.chosenAt, q.chosenAt))) {
    return TranslationChoice(
      service: s.service,
      scope: TranslationScope.song,
      tune: s.tune,
      defaultService: base,
    );
  }
  if (q != null && _newer(q.chosenAt, allChosenAt)) {
    return TranslationChoice(
      service: q.service,
      scope: TranslationScope.queue,
      tune: q.tune,
      defaultService: base,
    );
  }
  return TranslationChoice(
    service: base,
    scope: TranslationScope.all,
    tune: const {},
    defaultService: base,
  );
}
