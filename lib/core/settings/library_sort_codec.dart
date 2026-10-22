import 'library_sort.dart';
import 'settings_codec_values.dart';

// Screens inside `librarySort`, and the fields of each.
const songsScreen = 'songs';
const albumsScreen = 'albums';
const artistsScreen = 'artists';
const knownSortScreens = {songsScreen, albumsScreen, artistsScreen};
const _byKey = 'by';
const _descendingKey = 'descending';

/// Each part falls back on its own: a bad `by` keeps a valid `descending`.
SortChoice<F> decodeSort<F extends Enum>(
  Object? json,
  List<F> values,
  SortChoice<F> fallback,
) {
  if (json is! Map<String, Object?>) return fallback;
  final descending = json[_descendingKey];
  return SortChoice(
    enumOr(values, json[_byKey], fallback.field),
    descending: descending is bool ? descending : fallback.descending,
  );
}

Map<String, Object?> encodeSort(SortChoice<Enum> choice) => {
  _byKey: choice.field.name,
  _descendingKey: choice.descending,
};
