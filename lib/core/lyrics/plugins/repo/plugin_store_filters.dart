import '../../../database/lyrics_plugin_spec.dart';
import '../package/plugin_languages.dart';
import 'plugin_store_rows.dart';

/// The store's filter groups, in the order the filter modal shows them.
enum StoreFacet { kind, language, author, source }

/// Source key of plugins installed from a file (repo keys are URLs).
const storeSourceFromFile = ':file';

/// The filter key of an author: trimmed and lower-cased, so spellings that
/// differ in case are one author. Empty when the row has no author.
String storeAuthorKey(String author) => author.trim().toLowerCase();

/// The row's values per facet: the kind value; its language keys or
/// [pluginLanguagesGlobal]; the author key (none when blank); the repo URL or
/// [storeSourceFromFile].
Map<StoreFacet, Set<String>> storeRowFacetKeys(StoreRow row) {
  final author = storeAuthorKey(row.author);
  return {
    StoreFacet.kind: {if (row.kind != null) row.kind!.value},
    StoreFacet.language: row.languages.isEmpty
        ? {pluginLanguagesGlobal}
        : row.languages.toSet(),
    StoreFacet.author: {if (author.isNotEmpty) author},
    StoreFacet.source: {row.repoUrl ?? storeSourceFromFile},
  };
}

/// Whether a row with [rowKeys] in [facet] passes the [selected] keys of that
/// facet: an empty selection passes; otherwise the row needs one of the
/// selected keys. A global plugin carries [pluginLanguagesGlobal] as its
/// language key, so a language pick hides it unless Global is picked too.
bool storeFacetPasses(
  StoreFacet facet,
  Set<String> selected,
  Set<String> rowKeys,
) {
  if (selected.isEmpty) return true;
  return rowKeys.any(selected.contains);
}

/// The values picked in each group of the store filter. An empty group means
/// "All". Values of one group are OR-ed, groups are AND-ed. Immutable.
class PluginStoreFilters {
  const PluginStoreFilters() : _selected = const {};

  const PluginStoreFilters._(this._selected);

  /// The filters a store opens with: only [kind] picked, or nothing. If [kind]
  /// belongs to the translation family, both translation kinds are picked.
  factory PluginStoreFilters.initial(PluginKind? kind) {
    if (kind == null) return const PluginStoreFilters();
    final values = kind.isTranslation
        ? {PluginKind.translate.value, PluginKind.aiTranslate.value}
        : {kind.value};
    return PluginStoreFilters._(
      Map.unmodifiable({StoreFacet.kind: Set<String>.unmodifiable(values)}),
    );
  }

  final Map<StoreFacet, Set<String>> _selected;

  /// The picked keys of [facet]; empty means All.
  Set<String> selected(StoreFacet facet) => _selected[facet] ?? const {};

  /// A copy with [key] picked in [facet], or unpicked when it was picked.
  PluginStoreFilters toggled(StoreFacet facet, String key) {
    final next = {...selected(facet)};
    if (!next.remove(key)) next.add(key);
    return _with(facet, next);
  }

  /// A copy with nothing picked in [facet].
  PluginStoreFilters cleared(StoreFacet facet) => _with(facet, const {});

  PluginStoreFilters _with(StoreFacet facet, Set<String> keys) {
    final map = {..._selected};
    if (keys.isEmpty) {
      map.remove(facet);
    } else {
      map[facet] = Set<String>.unmodifiable(keys);
    }
    return PluginStoreFilters._(Map.unmodifiable(map));
  }

  /// Groups with a pick.
  int get activeCount => _selected.length;

  bool get isEmpty => _selected.isEmpty;

  /// Whether a row with [keys] (see [storeRowFacetKeys]) passes every group,
  /// except [skip] when given (used to count one group's values).
  bool matches(Map<StoreFacet, Set<String>> keys, {StoreFacet? skip}) {
    for (final facet in StoreFacet.values) {
      if (facet == skip) continue;
      if (!storeFacetPasses(facet, selected(facet), keys[facet] ?? const {})) {
        return false;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is PluginStoreFilters &&
      StoreFacet.values.every(
        (f) =>
            selected(f).length == other.selected(f).length &&
            selected(f).containsAll(other.selected(f)),
      );

  @override
  int get hashCode => Object.hashAll([
    for (final f in StoreFacet.values) Object.hashAllUnordered(selected(f)),
  ]);
}
