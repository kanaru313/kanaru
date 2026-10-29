import '../../../../core/lyrics/lyrics.dart';
import '../../../../core/lyrics/online/lyrics_choice.dart';
import '../../../../core/lyrics/online/lyrics_provider_registry.dart';
import '../../../../core/lyrics/online/playing_lyrics_source_provider.dart';
import '../../../../core/lyrics/online/playing_lyrics_status.dart';
import '../../../../l10n/l10n.dart';
import '../lyrics_provider_name.dart';

/// The text of the lyrics source button for [source]: what the song shows
/// now and, for lyrics picked without a choice, that Kanaru picked them
/// ("Auto · …"). [providers] names the online service.
String lyricsSourceLabel(
  AppLocalizations l10n,
  LyricsSourceResolution source,
  List<LyricsProviderRegistration> providers,
) {
  final status = source.status;
  switch (status) {
    case LyricsNone(reason: LyricsNoneReason.off):
      return l10n.lyricsSourceOff;
    case LyricsNone(reason: LyricsNoneReason.paused):
      return l10n.lyricsSourcePaused;
    // Reading the next song's lyrics is a lookup too: it must not claim
    // "No lyrics" for the moment before the answer.
    case LyricsSearching() || LyricsReading():
      return l10n.lyricsSourceSearching;
    case LyricsFound(:final origin?) when !origin.pinned:
      return l10n.lyricsSourceAuto(
        lyricsProviderName(providers, origin.providerId),
      );
    case LyricsFound():
      final detail = lyricsSourceDetail(l10n, status, providers);
      return source.effective == LyricsChoice.auto
          ? l10n.lyricsSourceAuto(detail)
          : detail;
    case LyricsNone():
      return l10n.lyricsSourceNone;
  }
}

/// The menu's header and the pill's tooltip: where the shown lyrics come from
/// ("Lyrics from LRCLIB · Synced", or from the file or tag), the only place
/// the round icon says it. Without lyrics it is the plain header.
String lyricsSourceMenuTitle(
  AppLocalizations l10n,
  LyricsSourceResolution source,
  List<LyricsProviderRegistration> providers,
) {
  final status = source.status;
  if (status is! LyricsFound) return l10n.lyricsSourceMenuHeader;
  return l10n.lyricsSourceMenuFrom(lyricsSourceDetail(l10n, status, providers));
}

/// What [found] is, without the "Auto" mark: the file or the tag, or the
/// online service and the kind of its lyrics.
String lyricsSourceDetail(
  AppLocalizations l10n,
  LyricsFound found,
  List<LyricsProviderRegistration> providers,
) {
  final origin = found.origin;
  if (origin != null) {
    return l10n.lyricsSourceOnline(
      lyricsProviderName(providers, origin.providerId),
      lyricsSourceKind(l10n, found.lyrics.synced),
    );
  }
  return switch (found.lyrics.source) {
    LyricsSource.sidecar => l10n.lyricsSourceFile,
    LyricsSource.embedded => l10n.lyricsSourceTag,
  };
}

/// "Synced" or "Plain".
String lyricsSourceKind(AppLocalizations l10n, bool synced) =>
    synced ? l10n.lyricsSourceSynced : l10n.lyricsSourcePlain;

/// Whether the button is quiet (no primary colour): nothing is shown, or the
/// lyrics are off, paused or still being looked for.
bool lyricsSourceMuted(LyricsSourceResolution source) =>
    source.status is! LyricsFound;
