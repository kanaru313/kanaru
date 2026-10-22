import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:logging/logging.dart';

import 'audio_device_choice.dart';
import 'audio_output_device.dart';
import 'replay_gain_options.dart';

final _log = Logger('player');

/// Whether an mpv log line says the audio output could not be opened.
/// mpv prints `Could not open/initialize audio device -> no sound.` from
/// `audio.c` when `audio-device` names a device that exists in its list but
/// fails to open (a card PipeWire holds, say), and it does not fall back to
/// another one. It is text, not API: if a newer mpv words it differently the
/// fallback to `auto` is lost, and only a device that left the list is
/// recovered.
@visibleForTesting
bool isAudioOpenFailure(String text) =>
    text.startsWith('Could not open/initialize audio device');

/// What decides the audio output of the mpv player: ReplayGain options, the
/// output device and the list of devices. Knows nothing of media_kit, so it
/// runs under test: `MpvAudioOutput` hands it the player's property setter,
/// device list and device updates.
///
/// Its calls run in their own chain, not the playlist chain of the backend:
/// a slow `open` must not hold back a ReplayGain change, and a decision for
/// the track that is about to start has to reach mpv before the open does.
/// [dispose] waits for the chain, so no call reaches a player that is being
/// destroyed. Nothing here throws; failures are logged.
class AudioOutputControl {
  AudioOutputControl({
    required this._setProperty,
    required this._listed,
    required this._updates,
  });

  final Future<void> Function(String name, String value) _setProperty;
  final List<AudioOutputDevice> Function() _listed;
  final Stream<List<AudioOutputDevice>> _updates;
  final _failed = StreamController<String>.broadcast();

  /// The `audio-device` mpv was last told, and so what a failed open is
  /// blamed on.
  String _device = autoAudioDevice;
  bool _disposed = false;
  Future<void> _pending = Future.value();

  Future<void> _serial(Future<void> Function() command) {
    final run = _pending.then((_) => _disposed ? null : command());
    // A failed command must not block the ones after it.
    _pending = run.catchError((_) {});
    return run;
  }

  Future<void> setReplayGain(ReplayGainOptions options) =>
      _serial(() async {
        for (final (name, value) in options.toMpvProperties()) {
          if (_disposed) return;
          await _setProperty(name, value);
        }
      }).catchError((Object error) {
        _log.warning('Could not set ReplayGain', error);
      });

  /// Sets `audio-device`; [name] must be `auto` or in [devices], anything
  /// else is replaced by `auto`.
  Future<void> setAudioDevice(String name) {
    var device = name;
    if (effectiveAudioDevice(name, devices) != name) {
      _log.warning(
        'Output device not in the list (${audioDriverForLog(name)}), using auto',
      );
      device = autoAudioDevice;
    }
    return _serial(() async {
      if (_disposed) return;
      _device = device;
      await _setProperty('audio-device', device);
    }).catchError((Object error) {
      _log.warning(
        'Could not set the output device (${audioDriverForLog(device)})',
        error,
      );
    });
  }

  List<AudioOutputDevice> get devices => _listed();

  /// The current list first, then every change. Listens before reading the
  /// list so one that arrives in between is not lost. media_kit only
  /// de-duplicates by device name, so a changed description is compared here.
  Stream<List<AudioOutputDevice>> get devicesChanged => Stream.multi((out) {
    List<AudioOutputDevice>? last;
    void emit(List<AudioOutputDevice> list) {
      if (last != null && _sameDevices(last!, list)) return;
      last = list;
      out.add(list);
    }

    final subscription = _updates.listen(emit);
    emit(_listed());
    out.onCancel = subscription.cancel;
  }, isBroadcast: true);

  /// The device that failed to open; the output is already back on `auto`.
  Stream<String> get deviceFailed => _failed.stream;

  /// Call with the text of every mpv log line, to catch a device that fails
  /// to open. Only a device other than `auto` is blamed: with `auto` there is
  /// nothing to fall back to.
  void onMpvLog(String text) {
    if (_disposed || !isAudioOpenFailure(text)) return;
    final failing = _device;
    if (failing == autoAudioDevice) return;
    _log.warning('Output device did not open (${audioDriverForLog(failing)})');
    _failed.add(failing);
    unawaited(setAudioDevice(autoAudioDevice));
  }

  /// Stops new calls and waits for the ones running.
  Future<void> dispose() async {
    _disposed = true;
    await _pending;
    await _failed.close();
  }

  static bool _sameDevices(
    List<AudioOutputDevice> a,
    List<AudioOutputDevice> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
