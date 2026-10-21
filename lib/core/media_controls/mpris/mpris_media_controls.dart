import 'dart:async';
import 'dart:io' as io;

import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/player_service.dart';
import '../../player/player_state.dart';
import '../../player/playing_track_art.dart';
import '../media_controls.dart';
import 'mpris_bus_name.dart';
import 'mpris_method_handler.dart';
import 'mpris_object.dart';
import 'mpris_properties.dart';

final _log = Logger('mpris');

/// Default for `coalesceWindow`: changes within it go out as one
/// `PropertiesChanged`. A track change moves several properties, and the
/// length arrives after the title.
const defaultMprisCoalesceWindow = Duration(milliseconds: 150);

const _closeTimeout = Duration(seconds: 1);

/// MPRIS 2.2 on the D-Bus session bus. Publishes the state of
/// [playerServiceProvider], with the art of [playingTrackArtProvider], and
/// runs the commands that media keys, `playerctl` and desktop widgets send.
///
/// Starts on its own and never throws: when the bus is missing or no name is
/// free it logs and stays idle. It does not reconnect if the bus goes away.
class MprisMediaControls implements MediaControls {
  /// [createClient] runs inside the guarded start, so a bad bus address
  /// (`DBusClient.session` throws `FormatException`) only leaves the controls
  /// idle. The client is closed by [dispose]. [onRaise] answers `Raise()`.
  /// [coalesceWindow] is how long changes are collected before one signal
  /// goes out. [buildProperties] makes the published properties from a state
  /// and the current track's art; it is only replaced to observe how often
  /// that work happens.
  MprisMediaControls(
    Ref ref,
    this._createClient, {
    required Future<void> Function() onRaise,
    this._coalesceWindow = defaultMprisCoalesceWindow,
    this._buildProperties = playerProperties,
  }) {
    _ref = ref;
    final handler = MprisMethodHandler(ref, _ids, onRaise);
    _object = MprisObject(
      handler,
      () => ref.read(playerServiceProvider),
      _art,
      _ids,
      () => !_disposed,
    );
    // Listening starts before the first await so no change is missed while
    // the connection is still being set up. Listeners only schedule a flush,
    // which reads the state and the art together: a listener may run before
    // the art provider knows the track changed, and pairing the new track's
    // id with the previous track's art would publish a wrong cover.
    _stateSubscription = ref.listen(playerServiceProvider, (previous, next) {
      // A new player (rebuild) may have a new seeked stream; see there.
      // Checked before the early return below: a rebuild can come with a
      // state that differs only in position.
      _listenToSeeked();
      // Position is read live and never signalled, so a tick changes
      // nothing we publish: no property work, no timer.
      if (previous != null && _samePublished(previous, next)) return;
      _schedule();
    });
    _artSubscription = ref.listen(playingTrackArtProvider, (_, _) {
      _schedule();
    });
    _listenToSeeked();
    _started = _start();
  }

  /// How long changes are collected into one `PropertiesChanged`.
  final Duration _coalesceWindow;
  final Map<String, DBusValue> Function(
    PlayerState,
    MprisTrackIds, {
    required String? artUri,
  })
  _buildProperties;
  final DBusClient Function() _createClient;
  DBusClient? _client;
  late final Ref _ref;
  final _ids = MprisTrackIds();
  late final MprisObject _object;
  late final ProviderSubscription<PlayerState> _stateSubscription;
  late final ProviderSubscription<String?> _artSubscription;
  StreamSubscription<Duration>? _seekedSubscription;
  Stream<Duration>? _seekedStream;
  late final Future<void> _started;

  /// Properties as last sent to clients; built when the name is ours.
  late Map<String, DBusValue> _emitted;
  Timer? _timer;

  String? _ownedName;

  /// The name is ours and signals may go out.
  bool _active = false;
  bool _disposed = false;
  bool _emitFailed = false;

  Future<void> _start() async {
    try {
      final client = _client = _createClient();
      await client.registerObject(_object);
      if (_disposed) return;
      final name = await acquireMprisBusName(
        client,
        cancelled: () => _disposed,
      );
      if (name == null) return;
      // Kept even when disposed meanwhile, so dispose can give it back.
      _ownedName = name;
      if (_disposed) return;
      _emitted = _build();
      _active = true;
    } on FormatException catch (error) {
      _unavailable(error);
    } on io.IOException catch (error) {
      _unavailable(error);
    } on DBusClosedException catch (error) {
      _unavailable(error);
    } on DBusMethodResponseException catch (error) {
      _unavailable(error);
    } catch (error, stack) {
      _log.severe('MPRIS unavailable', error, stack);
    }
  }

  /// The usual reasons for not starting (no session bus, bus refused us):
  /// one line, no stack trace.
  void _unavailable(Object error) => _log.warning('MPRIS unavailable', error);

  /// [a] and [b] give the same `playerProperties`: everything it reads
  /// except `position` is equal. The queue is compared by identity; it is
  /// immutable and replaced on every edit.
  static bool _samePublished(PlayerState a, PlayerState b) =>
      identical(a.queue, b.queue) &&
      a.playing == b.playing &&
      a.stopped == b.stopped &&
      a.duration == b.duration &&
      a.volume == b.volume;

  /// Follows `PlayerService.seeked`. The service makes a new stream when its
  /// provider rebuilds and closes the old one, so a finished stream means:
  /// look for the new one. A stream that is still the closed one (the
  /// rebuild failed) is not subscribed again, which would end at once and
  /// loop; the state listener tries again when a rebuild succeeds.
  void _listenToSeeked() {
    if (_disposed || _seekedSubscription != null) return;
    final Stream<Duration> stream;
    try {
      stream = _ref.read(playerServiceProvider.notifier).seeked;
    } catch (error) {
      _log.warning('Not following seeks', error);
      return;
    }
    if (stream == _seekedStream) return;
    _seekedStream = stream;
    _seekedSubscription = stream.listen(
      _onSeeked,
      onDone: () {
        _seekedSubscription = null;
        // A turn of the event loop later the rebuild has made its new stream.
        Timer.run(_listenToSeeked);
      },
    );
  }

  String? _art() => _ref.read(playingTrackArtProvider);

  /// The properties as they are now, the art read with the state.
  Map<String, DBusValue> _build() {
    final state = _ref.read(playerServiceProvider);
    _ids.observe(state.queue);
    return _buildProperties(state, _ids, artUri: _art());
  }

  /// Something published may have changed: flush after the coalescing
  /// window. Idle, nothing can be sent, and `_start` builds afresh on
  /// activation.
  void _schedule() {
    if (_active) _timer ??= Timer(_coalesceWindow, _flush);
  }

  void _flush() {
    _timer = null;
    if (_disposed || !_active) return;
    final latest = _build();
    final changed = changedProperties(_emitted, latest);
    _emitted = latest;
    if (changed.isEmpty) return;
    _send(
      _object.emitPropertiesChanged(
        mprisPlayerInterface,
        changedProperties: changed,
      ),
    );
  }

  void _onSeeked(Duration position) {
    if (_disposed || !_active) return;
    _send(
      _object.emitSignal(mprisPlayerInterface, 'Seeked', [
        DBusInt64(position.inMicroseconds),
      ]),
    );
  }

  /// Sends in the background. A failed send (the bus went away) is logged
  /// once and ends all further sending.
  void _send(Future<void> emit) {
    if (_emitFailed) return;
    unawaited(
      emit.catchError((Object error) {
        if (_emitFailed) return;
        _emitFailed = true;
        _active = false;
        _log.warning('Lost the bus, no more updates', error);
      }),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _active = false;
    _timer?.cancel();
    _stateSubscription.close();
    _artSubscription.close();
    await _seekedSubscription?.cancel();
    // Let a start that is still waiting on the bus finish, so the name it
    // may be about to get is released too.
    await _bounded('start', _started);
    final client = _client;
    if (client == null) return;
    final name = _ownedName;
    if (name != null) await _bounded('release', client.releaseName(name));
    await _bounded('close', client.close());
  }

  /// A client that never connected never completes its calls; do not wait
  /// for them past [_closeTimeout].
  Future<void> _bounded(String what, Future<Object?> future) async {
    try {
      await future.timeout(_closeTimeout);
    } catch (error) {
      _log.warning('$what on shutdown failed', error);
    }
  }
}
