/// One entry of mpv's `audio-device-list`. Kept here so `core` does not
/// expose the `media_kit` type.
class AudioOutputDevice {
  const AudioOutputDevice({required this.name, required this.description});

  /// What mpv takes as `audio-device`: `<driver>/<device>`, or `auto`.
  final String name;

  /// Human readable name, as mpv lists it.
  final String description;

  @override
  bool operator ==(Object other) =>
      other is AudioOutputDevice &&
      other.name == name &&
      other.description == description;

  @override
  int get hashCode => Object.hash(name, description);

  @override
  String toString() => 'AudioOutputDevice($name)';
}
