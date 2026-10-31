import '../../core/lyrics/online/lyrics_fetch_exception.dart';
import '../../l10n/l10n.dart';

/// The sentence for a failed online lyrics lookup at [provider] (its display
/// name), by why it failed. A `null` [kind] is a failure that was not a
/// request error, so the generic message is used. Where Retry would not
/// help, the sentence says why.
String lyricsFailureMessage(
  AppLocalizations l10n,
  LyricsFetchKind? kind,
  String provider,
) => switch (kind) {
  LyricsFetchKind.rateLimited => l10n.lyricsOnlineBusy(provider),
  LyricsFetchKind.network => l10n.lyricsOnlineError(provider),
  LyricsFetchKind.server => l10n.lyricsOnlineServerError(provider),
  LyricsFetchKind.invalidResponse ||
  LyricsFetchKind.blockedHost => l10n.lyricsOnlineUnreadable(provider),
  LyricsFetchKind.notConsented => l10n.lyricsPickerNotConsented(provider),
  null => l10n.libraryUnexpectedError,
};
