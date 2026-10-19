import 'dart:async';
import 'dart:io' as io;

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/player_service.dart';
import '../../player/player_state.dart';
import '../media_controls.dart';
import 'mpris_bus_name.dart';
import 'mpris_method_handler.dart';
import 'mpris_object.dart';
import 'mpris_properties.dart';

/// Changes within this window go out as one `PropertiesChanged`. A track
/// change moves several properties, and the length arrives after the title.
const _coalesceWindow = Duration(milliseconds: 150);

const _closeTimeout = Duration(seconds: 1);

/// MPRIS 2.2 on the D-Bus session bus. Publishes the state of
/// [playerServiceProvider] and runs the commands that media keys,
/// `playerctl` and desktop widgets send.
///
/// Starts on its own and never throws: when the bus is missing or no name is
/// free it logs and stays idle. It does not reconnect if the bus goes away.
class MprisMediaControls implements MediaControls {
  /// [createClient] runs inside the guarded start, so a bad bus address
  /// (`DBusClient.session` throws `FormatException`) only leaves the controls
  /// idle. The client is closed by [dispose]. [onRaise] answers `Raise()`.
  MprisMediaControls(
    Ref ref,
    this._createClient, {
    required Future<void> Function() onRaise,
  }) {
    _ref = ref;
    final handler = MprisMethodHandler(ref, _ids, onRaise);
    _object = MprisObject(
      handler,
      () => ref.read(playerServiceProvider),
      _ids,
      () => !_disposed,
    );
    final state = ref.read(playerServiceProvider);
    _ids.observe(state.queue);
    _emitted = _latest = playerProperties(state, _ids);
    // Listening starts before the first await so no change is missed while
    // the connection is still being set up.
    _stateSubscription = ref.listen(playerServiceProvider, (_, next) {
      _ids.observe(next.queue);
      _latest = playerProperties(next, _ids);
      // A new player (rebuild) may have a new seeked stream; see there.
      _listenToSeeked();
      // Idle: nothing can be sent, and `_start` syncs `_emitted` on
      // activation. Position ticks change nothing we publish; do not wake up
      // for them either.
      if (_active && changedProperties(_emitted, _latest).isNotEmpty) {
        _timer ??= Timer(_coalesceWindow, _flush);
      }
    });
    _listenToSeeked();
    _started = _start();
  }

  final DBusClient Function() _createClient;
  DBusClient? _client;
  late final Ref _ref;
  final _ids = MprisTrackIds();
  late final MprisObject _object;
  late final ProviderSubscription<PlayerState> _stateSubscription;
  StreamSubscription<Duration>? _seekedSubscription;
  Stream<Duration>? _seekedStream;
  late final Future<void> _started;

  /// Properties as last sent to clients, and as they are now.
  late Map<String, DBusValue> _emitted;
  late Map<String, DBusValue> _latest;
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
      _emitted = _latest;
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
      debugPrint('MPRIS unavailable: $error\n$stack');
    }
  }

  /// The usual reasons for not starting (no session bus, bus refused us):
  /// one line, no stack trace.
  void _unavailable(Object error) => debugPrint('MPRIS unavailable: $error');

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
      debugPrint('MPRIS: not following seeks: $error');
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

  void _flush() {
    _timer = null;
    if (_disposed || !_active) return;
    final changed = changedProperties(_emitted, _latest);
    _emitted = _latest;
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
        debugPrint('MPRIS: lost the bus, no more updates: $error');
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
      debugPrint('MPRIS: $what on shutdown failed: $error');
    }
  }
}
