import 'dart:async';

import 'stream_resolver.dart';

/// How a playthrough asks for a resolve of its key.
typedef StreamResolve = Future<ResolvedStream> Function(
  String key, {
  required bool fresh,
  required bool Function() abandoned,
});

/// How long one resolve may take before it is given up.
const streamResolveDeadline = Duration(seconds: 20);

/// A resolved URL is not used once it is this close to its expiry.
const streamExpiryMargin = Duration(seconds: 60);

/// How many item keys keep their playthrough: the last ones begun. A key
/// past them is forgotten unless a body of it is still being sent.
const maxPlaythroughKeys = 16;

/// The playthrough of [Playthrough.key] has ended (superseded, its owner
/// dropped) or its item is dead: nothing more is resolved for it.
class PlaythroughEnded implements Exception {
  const PlaythroughEnded();
}

/// One play of one item, from the `urlFor` that began it to the next one.
///
/// Every request of the playthrough shares one resolve. A resolve is used
/// until [streamExpiryMargin] before its expiry (past it, one plain resolve
/// replaces it), or until a 403 when the expiry is unknown. The first 403
/// spends the one `fresh` resolve of the playthrough; a later one makes the
/// item dead, and so does a failed resolve: from then on every request
/// fails at once and nothing is resolved until the next `urlFor`.
///
/// A playthrough superseded by a newer one of the same key hands its
/// requests on to it, so a body still being sent goes on with the newer
/// playthrough's stream; one whose owner was dropped fails them. The newer
/// one takes over the resolve in flight or cached (with its validity) and
/// the count of open bodies, but starts with its own fresh budget and not
/// dead; the resolve of a dead playthrough is not taken over.
class Playthrough {
  Playthrough._(this.key, this.owner, this._resolve, this._clock, this._limit);

  final String key;
  final String owner;
  final StreamResolve _resolve;
  final DateTime Function() _clock;
  final Duration _limit;

  Future<ResolvedStream>? _current;
  DateTime? _validUntil;
  bool _freshUsed = false;
  bool _dead = false;
  Object? _failure;
  bool _ended = false;
  Playthrough? _successor;
  int _openBodies = 0;

  /// Superseded by a newer playthrough of [key], or its owner was dropped.
  bool get ended => _ended;

  /// A second 403 or a failed resolve: no request of it can succeed.
  bool get dead => _dead;

  /// The error of the last failed resolve of this playthrough, or null.
  /// Kept after the item is dead so a caller can tell why (a refused
  /// playlist, say).
  Object? get failure => _failure;

  /// A body of this playthrough is being sent; [bodyClosed] when it ends.
  /// Counted on the newest playthrough of the key.
  void bodyOpened() => _latest._openBodies++;

  /// A body counted by [bodyOpened] has ended.
  void bodyClosed() => _latest._openBodies--;

  /// The newest playthrough of the key this one handed its requests to, or
  /// itself.
  Playthrough get _latest {
    var playthrough = this;
    for (var next = _successor; next != null; next = next._successor) {
      playthrough = next;
    }
    return playthrough;
  }

  /// The shared resolve, started when there is none or the one there is
  /// past its margin. Fails with [PlaythroughEnded] once ended or dead.
  Future<ResolvedStream> current() {
    final successor = _successor;
    if (successor != null) return successor.current();
    if (_ended || _dead) return Future.error(const PlaythroughEnded());
    final until = _validUntil;
    if (_current == null || (until != null && !_clock().isBefore(until))) {
      _current = _start(fresh: false);
    }
    return _current!;
  }

  /// The stream to retry with after [used] was answered 403: the newer
  /// resolve when another request already replaced [used], else the one
  /// fresh resolve, else none (the item is dead, [PlaythroughEnded]).
  Future<ResolvedStream> onForbidden(Future<ResolvedStream> used) {
    final successor = _successor;
    if (successor != null) return successor.onForbidden(used);
    if (_ended || _dead) return Future.error(const PlaythroughEnded());
    if (!identical(used, _current)) return current();
    if (_freshUsed) {
      _dead = true;
      return Future.error(const PlaythroughEnded());
    }
    _freshUsed = true;
    return _current = _start(fresh: true);
  }

  void _end([Playthrough? successor]) {
    _ended = true;
    _successor = successor;
  }

  /// Supersedes [previous], a playthrough of the same key.
  void _takeOver(Playthrough previous) {
    _openBodies = previous._openBodies;
    if (!previous._dead) {
      _current = previous._current;
      _validUntil = previous._validUntil;
    }
    previous._end(this);
  }

  Future<ResolvedStream> _start({required bool fresh}) {
    _validUntil = null;
    var timedOut = false;
    late final Future<ResolvedStream> started;
    // Abandoned only when the playthrough holding it now was dropped: a
    // newer playthrough of the key takes the resolve over.
    bool abandoned() => _latest._ended || timedOut;
    started = _resolveSpendingFresh(fresh, abandoned)
        .timeout(
          _limit,
          onTimeout: () {
            timedOut = true;
            throw const ResolveFailure('timeout');
          },
        )
        .then(
          (stream) {
            final holder = _latest;
            if (identical(holder._current, started)) {
              holder._validUntil = holder._validity(stream);
            }
            return stream;
          },
          onError: (Object error, StackTrace trace) {
            final holder = _latest;
            if (identical(holder._current, started)) {
              holder._dead = true;
              holder._failure = error;
            }
            Error.throwWithStackTrace(error, trace);
          },
        );
    // Callers may all be gone; the failure is theirs, not the zone's.
    started.ignore();
    return started;
  }

  /// One resolve. When it throws [ResolveForbidden] (a playlist it fetched
  /// was refused with 403) it goes on with `fresh: true` if the playthrough's
  /// fresh resolve is not spent yet, in the same future and so inside the
  /// same deadline; otherwise the error ends it (and so marks the item dead).
  Future<ResolvedStream> _resolveSpendingFresh(
    bool fresh,
    bool Function() abandoned,
  ) async {
    try {
      return await _resolve(key, fresh: fresh, abandoned: abandoned);
    } on ResolveForbidden {
      final holder = _latest;
      if (fresh || holder._freshUsed || abandoned()) rethrow;
      holder._freshUsed = true;
      return _resolve(key, fresh: true, abandoned: abandoned);
    }
  }

  /// Until when [stream] is used. An expiry that is already inside the
  /// margin counts as unknown, so a bad value cannot make every request
  /// resolve again.
  DateTime? _validity(ResolvedStream stream) {
    final expiresAt = stream.expiresAt;
    if (expiresAt == null) return null;
    final until = expiresAt.subtract(streamExpiryMargin);
    return until.isAfter(_clock()) ? until : null;
  }
}

/// The playthroughs of the proxy, one per item key, for the last
/// [maxPlaythroughKeys] keys begun and any older key with a body still being
/// sent.
class ResolvedStreams {
  ResolvedStreams(
    this._resolve, {
    DateTime Function()? clock,
    Duration resolveDeadline = streamResolveDeadline,
  }) : _clock = clock ?? DateTime.now,
       _limit = resolveDeadline;

  final StreamResolve _resolve;
  final DateTime Function() _clock;
  final Duration _limit;
  final _byKey = <String, Playthrough>{};

  /// Starts a new playthrough of [key], superseding the one before (whose
  /// requests go on with the new one), and makes [key] the newest one
  /// begun. Then forgets the keys past the last [maxPlaythroughKeys] begun
  /// that have no body being sent.
  Playthrough begin(String key, String owner) {
    final next = Playthrough._(key, owner, _resolve, _clock, _limit);
    final previous = _byKey.remove(key);
    if (previous != null) next._takeOver(previous);
    _byKey[key] = next;
    _forgetOld();
    return next;
  }

  /// The current playthrough of [key], or null when none was begun or it
  /// was forgotten.
  Playthrough? lookup(String key) => _byKey[key];

  /// Removes old keys from the map only: a resolve or body of theirs still
  /// going ends on its own, and their next request is not served.
  void _forgetOld() {
    final over = _byKey.length - maxPlaythroughKeys;
    if (over <= 0) return;
    final old = [
      for (final MapEntry(:key, :value) in _byKey.entries.take(over))
        if (value._openBodies <= 0) key,
    ];
    old.forEach(_byKey.remove);
  }

  /// Ends and forgets every playthrough of [owner].
  void dropOwner(String owner) {
    _byKey.removeWhere((_, playthrough) {
      if (playthrough.owner != owner) return false;
      playthrough._end();
      return true;
    });
  }

  /// Ends and forgets every playthrough.
  void clear() {
    for (final playthrough in _byKey.values) {
      playthrough._end();
    }
    _byKey.clear();
  }
}
