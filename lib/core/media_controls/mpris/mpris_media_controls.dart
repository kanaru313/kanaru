import 'dart:async';
import 'dart:io' as io;

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/player_service.dart';
import '../../player/player_state.dart';
import '../media_controls.dart';
import 'mpris_method_handler.dart';
import 'mpris_object.dart';
import 'mpris_properties.dart';

const _busName = 'org.mpris.MediaPlayer2.kanaru';

/// How many `.instance<pid>_<n>` names to try after the plain ones.
const _maxExtraNames = 5;

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
  /// [client] is closed by [dispose]. [onRaise] answers `Raise()`.
  MprisMediaControls(
    Ref ref,
    this._client, {
    required Future<void> Function() onRaise,
  }) {
    final handler = MprisMethodHandler(ref, _ids, onRaise);
    _object = MprisObject(handler, () => ref.read(playerServiceProvider), _ids);
    final state = ref.read(playerServiceProvider);
    _ids.observe(state.queue);
    _emitted = _latest = playerProperties(state, _ids);
    // Listening starts before the first await so no change is missed while
    // the connection is still being set up.
    _stateSubscription = ref.listen(playerServiceProvider, (_, next) {
      _ids.observe(next.queue);
      _latest = playerProperties(next, _ids);
      _timer ??= Timer(_coalesceWindow, _flush);
    });
    _seekedSubscription = ref
        .read(playerServiceProvider.notifier)
        .seeked
        .listen(_onSeeked);
    _started = _start();
  }

  final DBusClient _client;
  final _ids = MprisTrackIds();
  late final MprisObject _object;
  late final ProviderSubscription<PlayerState> _stateSubscription;
  late final StreamSubscription<Duration> _seekedSubscription;
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
      await _client.registerObject(_object);
      if (_disposed) return;
      final name = await _acquireName();
      if (name == null) return;
      // Kept even when disposed meanwhile, so dispose can give it back.
      _ownedName = name;
      if (_disposed) return;
      _emitted = _latest;
      _active = true;
    } catch (error, stack) {
      debugPrint('MPRIS unavailable: $error\n$stack');
    }
  }

  /// First free name of: plain, `.instance<pid>`, `.instance<pid>_<n>`.
  /// A hot restart keeps the old connection (and its name) alive, hence the
  /// numbered ones. `null` when none is free.
  Future<String?> _acquireName() async {
    final names = [
      _busName,
      '$_busName.instance${io.pid}',
      for (var n = 1; n <= _maxExtraNames; n++)
        '$_busName.instance${io.pid}_$n',
    ];
    for (final name in names) {
      if (_disposed) return null;
      final reply = await _client.requestName(
        name,
        flags: {DBusRequestNameFlag.doNotQueue},
      );
      if (reply == DBusRequestNameReply.primaryOwner ||
          reply == DBusRequestNameReply.alreadyOwner) {
        if (name != _busName) {
          debugPrint('MPRIS: $_busName is taken, using $name');
        }
        return name;
      }
    }
    debugPrint('MPRIS: no free bus name, media controls are off');
    return null;
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
    await _seekedSubscription.cancel();
    // Let a start that is still waiting on the bus finish, so the name it
    // may be about to get is released too.
    await _bounded('start', _started);
    final name = _ownedName;
    if (name != null) await _bounded('release', _client.releaseName(name));
    await _bounded('close', _client.close());
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
