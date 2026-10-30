import '../../../core/lyrics/online/lyrics_provider_registry.dart';

/// Name of the service [providerId]; the id when it is not registered.
String lyricsProviderName(
  List<LyricsProviderRegistration> registrations,
  String providerId,
) {
  for (final r in registrations) {
    if (r.id == providerId) return r.displayName;
  }
  return providerId;
}
