import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/player_service.dart';
import '../../player/player_state.dart';
import 'mpris_properties.dart';

final _log = Logger('mpris');

/// Turns MPRIS method calls and property writes into [PlayerService]
/// commands. Checks every signature and value range first, replies at once
/// and runs the command in the background: a command can wait behind the
/// engine, and a caller waiting on it would time out.
class MprisMethodHandler {
  MprisMethodHandler(this._ref, this._ids, this._onRaise);

  final Ref _ref;
  final MprisTrackIds _ids;
  final Future<void> Function() _onRaise;

  PlayerService get _player => _ref.read(playerServiceProvider.notifier);
  PlayerState get _state => _ref.read(playerServiceProvider);

  DBusMethodResponse root(DBusMethodCall call) => switch (call.name) {
    'Raise' => _call(call, '', 'Raise', _onRaise),
    // Closing the app from outside is not offered (CanQuit is false).
    'Quit' => DBusMethodErrorResponse.notSupported(),
    _ => DBusMethodErrorResponse.unknownMethod(),
  };

  DBusMethodResponse player(DBusMethodCall call) => switch (call.name) {
    'Play' => _call(call, '', 'Play', () => _player.play()),
    'Pause' => _call(call, '', 'Pause', () => _player.pause()),
    'PlayPause' => _call(call, '', 'PlayPause', () => _player.playPause()),
    'Stop' => _call(call, '', 'Stop', () => _player.stop()),
    'Next' => _call(call, '', 'Next', () => _player.next()),
    'Previous' => _call(call, '', 'Previous', () => _player.previous()),
    'Seek' => _seek(call),
    'SetPosition' => _setPosition(call),
    'OpenUri' =>
      call.signature != DBusSignature('s')
          ? DBusMethodErrorResponse.invalidArgs()
          : DBusMethodErrorResponse.notSupported(),
    _ => DBusMethodErrorResponse.unknownMethod(),
  };

  /// Replies success and runs [command] in the background, logging failures.
  DBusMethodResponse _call(
    DBusMethodCall call,
    String signature,
    String label,
    Future<void> Function() command,
  ) {
    if (call.signature != DBusSignature(signature)) {
      return DBusMethodErrorResponse.invalidArgs();
    }
    _run(label, command);
    return DBusMethodSuccessResponse();
  }

  void _run(String label, Future<void> Function() command) {
    // `sync` also catches a command that throws before returning a future.
    unawaited(
      Future<void>.sync(command).catchError((Object error, StackTrace stack) {
        _log.severe('$label failed', error, stack);
      }),
    );
  }

  DBusMethodResponse _seek(DBusMethodCall call) {
    if (call.signature != DBusSignature('x')) {
      return DBusMethodErrorResponse.invalidArgs();
    }
    final state = _state;
    if (state.duration <= Duration.zero) return DBusMethodSuccessResponse();
    final length = state.duration.inMicroseconds;
    // Clamped first so adding it to the position cannot overflow int64.
    final offset = call.values[0].asInt64().clamp(-length, length);
    final target = state.position.inMicroseconds + offset;
    if (target >= length) {
      _run('Seek', () => _player.next());
    } else {
      final to = Duration(microseconds: target < 0 ? 0 : target);
      _run('Seek', () => _player.seek(to));
    }
    return DBusMethodSuccessResponse();
  }

  DBusMethodResponse _setPosition(DBusMethodCall call) {
    if (call.signature != DBusSignature('ox')) {
      return DBusMethodErrorResponse.invalidArgs();
    }
    final state = _state;
    final position = call.values[1].asInt64();
    final valid =
        state.duration > Duration.zero &&
        call.values[0].asObjectPath() == _ids.of(state.queue) &&
        position >= 0 &&
        position <= state.duration.inMicroseconds;
    // Anything else is ignored, as the spec says.
    if (valid) {
      _run('SetPosition', () => _player.seek(Duration(microseconds: position)));
    }
    return DBusMethodSuccessResponse();
  }

  /// `Set` on `org.mpris.MediaPlayer2.Player`.
  DBusMethodResponse setPlayerProperty(String name, DBusValue value) {
    switch (name) {
      case 'LoopStatus':
        if (value is! DBusString) return DBusMethodErrorResponse.invalidArgs();
        final mode = repeatModeFromLoopStatus(value.value);
        if (mode == null) return DBusMethodErrorResponse.invalidArgs();
        _run('LoopStatus', () => _player.setRepeat(mode));
      case 'Shuffle':
        if (value is! DBusBoolean) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        _run('Shuffle', () => _player.setShuffle(value.value));
      case 'Volume':
        if (value is! DBusDouble || !value.value.isFinite) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        final volume = value.value.clamp(0, 1).toDouble() * 100;
        _run('Volume', () => _player.setVolume(volume));
      case 'Rate':
        if (value is! DBusDouble || (value.value != 1 && value.value != 0)) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        // Only 1.0 is supported; the spec says 0.0 means Pause.
        if (value.value == 0) _run('Rate', () => _player.pause());
      case _ when playerProperties(_state, _ids).containsKey(name):
        return DBusMethodErrorResponse.propertyReadOnly();
      default:
        return DBusMethodErrorResponse.unknownProperty();
    }
    return DBusMethodSuccessResponse();
  }
}
