import '../../../../core/lyrics/lyrics.dart';
import '../../../../core/lyrics/online/lyrics_source_names.dart';
import '../../../../core/lyrics/online/playing_lyrics_source_provider.dart';
import '../../../../core/lyrics/online/playing_lyrics_status.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/lyrics_picker/lyrics_source_name_text.dart';

/// The first line of the lyrics button's tooltip: where the shown lyrics come
/// from ("Lyrics from <source> · Synced", or ".lrc file" / "Tag lyrics"), else what
/// the song shows instead (lyrics off, paused, looking, none).
String lyricsSourceTooltipTitle(
  AppLocalizations l10n,
  LyricsSourceResolution source,
  Map<String, LyricsSourceName> names,
) {
  final status = source.status;
  switch (status) {
    // The song's own lyrics are named plainly (".lrc file", "Tag lyrics");
    // online ones say whose they are.
    case LyricsFound(origin: null):
      return lyricsSourceDetail(l10n, status, names);
    case LyricsFound():
      return l10n.lyricsSourceMenuFrom(lyricsSourceDetail(l10n, status, names));
    case LyricsNone(reason: LyricsNoneReason.off):
      return l10n.lyricsSourceOff;
    case LyricsNone(reason: LyricsNoneReason.paused):
      return l10n.lyricsSourcePaused;
    // Reading the next song's lyrics is a lookup too: it must not claim
    // "No lyrics" for the moment before the answer.
    case LyricsSearching() || LyricsReading():
      return l10n.lyricsSourceSearching;
    case LyricsNone():
      return l10n.lyricsSourceNone;
  }
}

/// What [found] is: the file or the tag, or the online service and the kind
/// of its lyrics.
String lyricsSourceDetail(
  AppLocalizations l10n,
  LyricsFound found,
  Map<String, LyricsSourceName> names,
) {
  final origin = found.origin;
  if (origin != null) {
    return l10n.lyricsSourceOnline(
      lyricsSourceNameText(l10n, names, origin.providerId),
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
