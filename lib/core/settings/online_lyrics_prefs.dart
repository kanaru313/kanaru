/// Options of the online lyrics lookup.
///
/// Consent is one answer for every online lyrics source, not tied to a
/// source: [manualConsent] lets the user search, [autoConsent] lets Kanaru
/// look lyrics up without asking. Consent to search never implies consent to
/// look up automatically.
class OnlineLyricsPrefs {
  const OnlineLyricsPrefs({
    this.autoFetch = false,
    this.manualConsent = false,
    this.autoConsent = false,
  });

  /// Look lyrics up online for the playing song (only with auto consent).
  final bool autoFetch;

  /// The user accepted sending song details to the enabled sources when they
  /// search.
  final bool manualConsent;

  /// The user accepted looking lyrics up without being asked each time.
  final bool autoConsent;

  /// Automatic lookup may run: the switch is on and its consent was given.
  bool get autoAllowed => autoFetch && autoConsent;

  OnlineLyricsPrefs copyWith({
    bool? autoFetch,
    bool? manualConsent,
    bool? autoConsent,
  }) => OnlineLyricsPrefs(
    autoFetch: autoFetch ?? this.autoFetch,
    manualConsent: manualConsent ?? this.manualConsent,
    autoConsent: autoConsent ?? this.autoConsent,
  );

  @override
  bool operator ==(Object other) =>
      other is OnlineLyricsPrefs &&
      other.autoFetch == autoFetch &&
      other.manualConsent == manualConsent &&
      other.autoConsent == autoConsent;

  @override
  int get hashCode => Object.hash(autoFetch, manualConsent, autoConsent);

  @override
  String toString() =>
      'OnlineLyricsPrefs(autoFetch: $autoFetch, '
      'manualConsent: $manualConsent, autoConsent: $autoConsent)';
}
