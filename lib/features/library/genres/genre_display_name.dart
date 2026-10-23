import '../../../l10n/l10n.dart';
import '../../../shared/library_route_keys.dart' show unknownGenreKey;

/// What a genre is called on screen: its [name], or the translated "Unknown
/// genre" for the tracks with no usable genre ([unknownGenreKey], whose stored
/// name is empty).
String genreDisplayName(AppLocalizations l10n, String key, String name) =>
    key == unknownGenreKey ? l10n.genresUnknown : name;
