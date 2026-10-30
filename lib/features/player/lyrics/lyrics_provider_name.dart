import '../../../core/lyrics/online/lyrics_source_names.dart';

export '../../../shared/lyrics_picker/lyrics_source_name_text.dart';

/// Raw name of the source [providerId]; the id when it is not known. It has
/// no "(removed)" mark and no author: text the user reads goes through
/// `lyricsSourceNameText`.
String lyricsSourceDisplayName(
  Map<String, LyricsSourceName> names,
  String providerId,
) => names[providerId]?.displayName ?? providerId;
