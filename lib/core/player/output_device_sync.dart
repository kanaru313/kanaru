import 'dart:async';

import '../settings/playback_prefs.dart';
import 'audio_backend.dart';
import 'audio_device_choice.dart';
import 'audio_output_device.dart';
import 'send_audio_call.dart';

/// Keeps the engine's output device in line with the saved choice and the
/// devices mpv lists. One per `PlayerService` build; a new engine starts on
/// `auto`, which is what this assumes at the start. No Riverpod in it.
///
/// The backend and this class each see the device list through their own
/// stream, so for a moment they can disagree (the backend turns a name it no
/// longer lists into `auto`). The next list change heals that; accepted.
class OutputDeviceSync {
  OutputDeviceSync({
    required this._backend,
    required this._onFailedDeviceChanged,
    this.deviceSettle = const Duration(seconds: 2),
  });

  /// How long a saved device that came back must stay in the list before the
  /// output moves to it. Each move reopens the output and seeks, and a
  /// Bluetooth sink flickers while it changes profile.
  final Duration deviceSettle;

  final AudioBackend _backend;
  final void Function(String? name) _onFailedDeviceChanged;
  bool _disposed = false;

  String? _saved;
  var _devices = const <AudioOutputDevice>[];
  var _applied = autoAudioDevice;
  String? _failed;
  bool _hadDevice = false;
  bool _needsSettle = false;
  Timer? _settleTimer;

  /// The saved device that failed to open this session, or `null`.
  String? get failedDevice => _failed;

  void setPrefs(PlaybackPrefs prefs) {
    if (_disposed) return;
    final changed = prefs.audioDeviceName != _saved;
    _saved = prefs.audioDeviceName;
    if (changed) {
      // A different choice starts clean: no failure, no flicker wait.
      _settleTimer?.cancel();
      _settleTimer = null;
      _hadDevice = false;
      _needsSettle = false;
      _setFailed(null);
    }
    _apply();
  }

  void setDevices(List<AudioOutputDevice> devices) {
    if (_disposed) return;
    _devices = devices;
    _apply();
  }

  /// The engine could not open [name] and already went back to `auto`.
  void markDeviceFailed(String name) {
    if (_disposed) return;
    // Whatever failed, the engine is on `auto` now.
    _applied = autoAudioDevice;
    if (name != _saved) {
      // A late report of a device that is no longer the choice: the engine
      // fell back to `auto` under the choice that is.
      _apply();
      return;
    }
    _setFailed(name);
  }

  /// The failure mark was cleared from outside (the user picked the failed
  /// device again): use the saved device again if it is listed.
  void retryDevice() {
    if (_disposed || _failed == null) return;
    _setFailed(null);
    _apply();
  }

  void dispose() {
    _disposed = true;
    _settleTimer?.cancel();
  }

  void _setFailed(String? name) {
    if (_failed == name) return;
    _failed = name;
    _onFailedDeviceChanged(name);
  }

  void _apply() {
    final saved = _saved;
    if (!isAudioDeviceAvailable(saved, _devices)) {
      _settleTimer?.cancel();
      _settleTimer = null;
      // Coming back after it was here is a return, not a first sighting.
      if (_hadDevice) _needsSettle = true;
      // A device that left the list is tried again when it returns.
      _setFailed(null);
      _send(autoAudioDevice);
      return;
    }
    _hadDevice = true;
    if (_failed == saved) {
      _send(autoAudioDevice);
      return;
    }
    if (_needsSettle) {
      _settleTimer ??= Timer(deviceSettle, () {
        _settleTimer = null;
        if (_disposed) return;
        _needsSettle = false;
        _apply();
      });
      return;
    }
    _send(saved!);
  }

  void _send(String name) {
    if (name == _applied) return;
    _applied = name;
    sendAudioCall(() => _backend.setAudioDevice(name), 'the output device');
  }
}
