import '../../../core/lyrics/online/lyrics_source_names.dart';

/// Name of the source [providerId]; the id when it is not known.
String lyricsSourceDisplayName(
  Map<String, LyricsSourceName> names,
  String providerId,
) => names[providerId]?.displayName ?? providerId;
