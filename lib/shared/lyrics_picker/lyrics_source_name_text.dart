import '../../core/lyrics/online/lyrics_source_names.dart';
import '../../l10n/l10n.dart';

/// How the UI writes the name of lyrics source [providerId], in every place
/// that names one (source pill and menu, status texts, the credit, picker
/// tiles and chips, failure lines):
///
/// * two sources that share a name get their author, "NetEase · hieu05"
///   (a source that gives no author keeps the bare name);
/// * a removed plugin gets "(removed)" after that, because only its saved
///   lyrics are left;
/// * an id that is not known is shown as it is.
String lyricsSourceNameText(
  AppLocalizations l10n,
  Map<String, LyricsSourceName> names,
  String providerId,
) {
  final name = names[providerId];
  if (name == null) return providerId;
  final key = name.displayName.trim().toLowerCase();
  final clash = names.entries.any(
    (e) =>
        e.key != providerId && e.value.displayName.trim().toLowerCase() == key,
  );
  final author = name.author;
  final shown = clash && author != null
      ? l10n.lyricsSourceNameWithAuthor(name.displayName, author)
      : name.displayName;
  return name.removed ? l10n.lyricsSourceNameRemoved(shown) : shown;
}
