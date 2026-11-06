import '../../../../core/lyrics/lyrics.dart';
import '../../../../l10n/l10n.dart';

/// "`.lrc` file" or "In the tag", from where the song's own lyrics come from.
String? lyricsSourceLocalSubtitle(AppLocalizations l10n, LyricsSource? own) =>
    switch (own) {
      LyricsSource.sidecar => l10n.lyricsSourceFile,
      LyricsSource.embedded => l10n.lyricsSourceLocalTag,
      null => null,
    };
