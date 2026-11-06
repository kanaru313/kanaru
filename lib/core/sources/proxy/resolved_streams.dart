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
/// playthrough's stream; one whose owner was dropped fails them.
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
  bool _ended = false;
  Playthrough? _successor;

  /// Superseded by a newer playthrough of [key], or its owner was dropped.
  bool get ended => _ended;

  /// A second 403 or a failed resolve: no request of it can succeed.
  bool get dead => _dead;

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

  Future<ResolvedStream> _start({required bool fresh}) {
    _validUntil = null;
    var timedOut = false;
    late final Future<ResolvedStream> started;
    started = _resolve(key, fresh: fresh, abandoned: () => _ended || timedOut)
        .timeout(
          _limit,
          onTimeout: () {
            timedOut = true;
            throw const ResolveFailure('timeout');
          },
        )
        .then(
          (stream) {
            if (identical(_current, started)) _validUntil = _validity(stream);
            return stream;
          },
          onError: (Object error, StackTrace trace) {
            if (identical(_current, started)) _dead = true;
            Error.throwWithStackTrace(error, trace);
          },
        );
    // Callers may all be gone; the failure is theirs, not the zone's.
    started.ignore();
    return started;
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

/// The playthroughs of the proxy, one per item key.
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

  /// Starts a new playthrough of [key], ending the one before (whose
  /// requests go on with the new one).
  Playthrough begin(String key, String owner) {
    final next = Playthrough._(key, owner, _resolve, _clock, _limit);
    _byKey[key]?._end(next);
    return _byKey[key] = next;
  }

  /// The current playthrough of [key], or null when none was begun.
  Playthrough? lookup(String key) => _byKey[key];

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
