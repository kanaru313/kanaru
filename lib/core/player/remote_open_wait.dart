import 'dart:async';

import '../sources/source_models.dart';
import 'mpv_remote_file_options.dart';
import 'track.dart';

/// How long a remote `open` must stay the newest before its stream is
/// resolved. An `open` superseded within it (skipping through tracks) begins
/// no playthrough and runs no `stream.js`.
const remoteOpenGrace = Duration(milliseconds: 300);

enum _TicketState { waiting, queued, running, done }

/// One `open` call, from the call until it ran or gave up.
///
/// [next], [play] and [start] are what the `open` will use when it runs: the
/// calls it was made with, replaced by the later ones the coordinator hands
/// it (see [OpenCoordinator]).
class OpenTicket {
  OpenTicket._(
    this.generation,
    this._owner, {
    required this.next,
    required this.play,
    required this.start,
    required bool waits,
  }) : _state = waits ? _TicketState.waiting : _TicketState.queued;

  /// Order of the call among all `open` calls: a bigger number is newer.
  final int generation;
  final OpenCoordinator _owner;

  /// The track queued behind the one this `open` starts.
  Track? next;

  /// Whether the track starts playing, or paused.
  bool play;

  /// Where in the track it starts.
  Duration start;

  _TicketState _state;
  bool _gaveUp = false;
  bool _released = false;
  final _gaveUpSignal = Completer<void>();

  /// A newer `open` or a `stop` replaced this one before it ran. It must open
  /// nothing.
  bool get gaveUp => _gaveUp;

  /// Completes at the moment this `open` gives up, never if it does not.
  Future<void> get onGaveUp => _gaveUpSignal.future;

  /// The wait is over and the body goes into the command chain.
  void leaveWait() {
    if (_state == _TicketState.waiting) _state = _TicketState.queued;
  }

  /// The chain reached this `open`: whether it may run. False when it gave up
  /// (a newer `open` exists), whatever order the waits ended in.
  bool tryStart() {
    if (_gaveUp || generation != _owner._latest) return false;
    _state = _TicketState.running;
    return true;
  }

  /// The `open` ran or gave up. Safe to call more than once.
  void finish() {
    _state = _TicketState.done;
    _release();
  }

  void _giveUp() {
    if (_gaveUp) return;
    _gaveUp = true;
    _state = _TicketState.done;
    _gaveUpSignal.complete();
    _release();
  }

  void _release() {
    if (_released) return;
    _released = true;
    _owner._pending--;
  }
}

/// Decides which `open` wins and what a waiting `open` takes from the calls
/// made meanwhile. Pure bookkeeping: the backend runs the commands.
class OpenCoordinator {
  int _latest = 0;
  int _pending = 0;
  final _tickets = <OpenTicket>[];

  /// `open` calls counted from their call until they ran or gave up. The
  /// handlers of mpv's events skip them while it is above zero: the newest
  /// `open` replaces whatever those events describe.
  int get pending => _pending;

  /// A new `open` call. Every older `open` that has not started running gives
  /// up at once; one that is running finishes.
  ///
  /// [waits]: the `open` waits (outside the command chain) for the format of
  /// its stream before it runs.
  OpenTicket begin({
    required Track? next,
    required bool play,
    required Duration start,
    required bool waits,
  }) {
    for (final older in _tickets) {
      if (older._state != _TicketState.running) older._giveUp();
    }
    _tickets.removeWhere((ticket) => ticket._state == _TicketState.done);
    final ticket = OpenTicket._(
      ++_latest,
      this,
      next: next,
      play: play,
      start: start,
      waits: waits,
    );
    _pending++;
    _tickets.add(ticket);
    return ticket;
  }

  OpenTicket? get _waiting => _find((state) => state == _TicketState.waiting);

  /// The newest `open` that has not started running, waiting or queued.
  OpenTicket? get _unstarted => _find(
    (state) => state == _TicketState.waiting || state == _TicketState.queued,
  );

  OpenTicket? _find(bool Function(_TicketState state) test) {
    for (final ticket in _tickets.reversed) {
      if (!ticket._gaveUp && test(ticket._state)) return ticket;
    }
    return null;
  }

  /// Play or pause was pressed: a waiting `open` follows the last press.
  void onPlayPause({required bool playing}) => _waiting?.play = playing;

  /// A seek was asked. A waiting `open` takes it as its start (the last one
  /// wins) and returns true: there is nothing to seek yet.
  bool onSeek(Duration position) {
    final ticket = _waiting;
    if (ticket == null) return false;
    ticket.start = position;
    return true;
  }

  /// The next track was replaced. An `open` that has not started running
  /// queues [next] instead of its own (the last call wins) and returns true.
  bool onSetNext(Track? next) {
    final ticket = _unstarted;
    if (ticket == null) return false;
    ticket.next = next;
    return true;
  }

  /// `stop` was called: every waiting `open` gives up.
  void onStop() {
    for (final ticket in _tickets) {
      if (ticket._state == _TicketState.waiting) ticket._giveUp();
    }
  }

  /// The backend is gone: no `open` that has not started running goes on.
  void dispose() {
    for (final ticket in _tickets) {
      if (ticket._state != _TicketState.running) ticket._giveUp();
    }
  }
}

/// Runs [work] unless [ticket] gives up first; null when it did.
Future<T?> _unlessGaveUp<T>(OpenTicket ticket, Future<T> work) {
  if (ticket.gaveUp) return Future.value();
  return Future.any<T?>([work, ticket.onGaveUp.then<T?>((_) => null)]);
}

/// The wait of a remote `open`, before its body enters the command chain.
///
/// After [grace] (during which a newer `open` or a `stop` ends it) it asks
/// [handOut] for the URL mpv will be given, then waits at most [wait] for
/// [formatOf] to answer for it, so the resolve is done (or running) when mpv
/// reaches the file. The answer itself is not used: mpv's load hook asks
/// again. Returns the URL, or null when [ticket] gave up, at once when it
/// does, whatever [handOut] and [formatOf] are still doing. No answer, an
/// error (reported to [onError], which must not log the URL) or a timeout
/// still returns the URL: the track opens as it would without the wait. A
/// [handOut] that fails returns null with [ticket] still alive: the caller
/// opens as it would without the wait. Never throws.
Future<String?> waitForRemoteFormat({
  required OpenTicket ticket,
  required Future<String> Function() handOut,
  required Future<RemoteStreamFormat?> Function(String url) formatOf,
  Duration grace = remoteOpenGrace,
  Duration wait = mpvRemoteFormatWait,
  void Function(Object error)? onError,
}) async {
  try {
    await _unlessGaveUp(ticket, Future<void>.delayed(grace));
    if (ticket.gaveUp) return null;
    final url = await _unlessGaveUp(ticket, handOut());
    if (url == null || ticket.gaveUp) return null;
    try {
      await _unlessGaveUp(ticket, formatOf(url).timeout(wait));
    } on TimeoutException {
      // The track opens as it would without the wait.
    } on Object catch (error) {
      onError?.call(error);
    }
    return ticket.gaveUp ? null : url;
  } on Object catch (error) {
    onError?.call(error);
    return null;
  }
}
