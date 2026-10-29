import '../lyrics/online/lyrics_provider_registry.dart';

/// Options of the online lyrics lookup.
///
/// [noticeAcknowledged] holds consent keys (`LyricsProviderRegistration`):
/// the manual key `<id>@<hosts>` lets the user search that provider, the
/// auto key `<id>@<hosts>:auto` lets Kanaru look lyrics up without asking.
/// Consent to search never implies consent to look up automatically.
class OnlineLyricsPrefs {
  const OnlineLyricsPrefs({
    this.autoFetch = false,
    this.writeLrc = false,
    this.noticeAcknowledged = const {},
  });

  /// Look lyrics up online for the playing song (only with auto consent).
  final bool autoFetch;

  /// Write a `.lrc` file next to a song when the user picks its lyrics.
  final bool writeLrc;

  /// Consent keys the user accepted. Open-ended: keys of providers this
  /// version does not know are kept.
  final Set<String> noticeAcknowledged;

  /// At least one provider was accepted for automatic lookup.
  bool get hasAutoConsent => noticeAcknowledged.any(isAutoConsentKey);

  /// Automatic lookup may run for [registration]: the switch is on and that
  /// provider's own auto key was accepted (a key of another provider or of
  /// other hosts does not count).
  bool autoAllowedFor(LyricsProviderRegistration registration) =>
      autoFetch && noticeAcknowledged.contains(registration.autoConsentKey);

  OnlineLyricsPrefs copyWith({
    bool? autoFetch,
    bool? writeLrc,
    Set<String>? noticeAcknowledged,
  }) => OnlineLyricsPrefs(
    autoFetch: autoFetch ?? this.autoFetch,
    writeLrc: writeLrc ?? this.writeLrc,
    noticeAcknowledged: noticeAcknowledged ?? this.noticeAcknowledged,
  );

  @override
  bool operator ==(Object other) =>
      other is OnlineLyricsPrefs &&
      other.autoFetch == autoFetch &&
      other.writeLrc == writeLrc &&
      other.noticeAcknowledged.length == noticeAcknowledged.length &&
      other.noticeAcknowledged.containsAll(noticeAcknowledged);

  @override
  int get hashCode => Object.hash(
    autoFetch,
    writeLrc,
    Object.hashAllUnordered(noticeAcknowledged),
  );

  @override
  String toString() =>
      'OnlineLyricsPrefs(autoFetch: $autoFetch, writeLrc: $writeLrc, '
      'noticeAcknowledged: ${noticeAcknowledged.toList()..sort()})';
}

/// Whether [key] is an automatic-lookup consent key. A manual key is
/// `<id>@<hosts>` and a host name never holds a colon, so only an auto key
/// ends this way.
bool isAutoConsentKey(String key) => key.endsWith(':auto');
