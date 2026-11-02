import '../../../database/lyrics_plugin_spec.dart';
import '../package/plugin_languages.dart';
import 'plugin_store_filters.dart';
import 'plugin_store_rows.dart';

/// One pickable value of a filter group.
class StoreFacetValue {
  const StoreFacetValue({
    required this.key,
    required this.count,
    required this.selected,
    this.label,
  });

  /// Kind value, language key (or [pluginLanguagesGlobal]), author key,
  /// repository URL or [storeSourceFromFile].
  final String key;

  /// Author spelling or repository name; null for kind, language and file
  /// (the UI labels those) and for a picked value no row has any more.
  final String? label;

  /// Rows the list would show if only this value were picked in its group
  /// (every other group and the search still apply).
  final int count;
  final bool selected;
}

/// One filter group with its values.
class StoreFacetGroup {
  const StoreFacetGroup({
    required this.facet,
    required this.values,
    required this.selected,
  });

  final StoreFacet facet;
  final List<StoreFacetValue> values;
  final Set<String> selected;

  /// Worth showing from two values on, or while something is picked (so a
  /// stale pick can be cleared).
  bool get visible => values.length >= 2 || selected.isNotEmpty;
}

/// The filter groups for [rows] (rows that need a newer Kanaru are not
/// passed). Values come from every row, so groups do not jump while typing;
/// counts also follow [matchesSearch] and the other groups' picks. A picked
/// value no row has is kept with count 0. [repoOrder] orders the source
/// values: listed repositories first, then others by name, then "from file".
List<StoreFacetGroup> computeStoreFacets(
  List<StoreRow> rows,
  PluginStoreFilters filters,
  bool Function(StoreRow) matchesSearch, {
  List<String> repoOrder = const [],
}) {
  final keys = [for (final row in rows) storeRowFacetKeys(row)];
  final labels = {for (final f in StoreFacet.values) f: <String, String>{}};
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final author = keys[i][StoreFacet.author]!;
    if (author.isNotEmpty) {
      labels[StoreFacet.author]!.putIfAbsent(
        author.first,
        () => row.author.trim(),
      );
    }
    final repo = row.repoUrl;
    if (repo != null && row.repoName != null) {
      labels[StoreFacet.source]!.putIfAbsent(repo, () => row.repoName!);
    }
  }
  final searched = [for (final row in rows) matchesSearch(row)];

  return [
    for (final facet in StoreFacet.values)
      _group(facet, keys, searched, filters, labels[facet]!, repoOrder),
  ];
}

StoreFacetGroup _group(
  StoreFacet facet,
  List<Map<StoreFacet, Set<String>>> keys,
  List<bool> searched,
  PluginStoreFilters filters,
  Map<String, String> labels,
  List<String> repoOrder,
) {
  final selected = filters.selected(facet);
  final present = {for (final k in keys) ...k[facet]!};
  final ordered = _order(facet, {...present, ...selected}, labels, repoOrder);
  // Rows that pass the search and every other group.
  final candidates = [
    for (var i = 0; i < keys.length; i++)
      if (searched[i] && filters.matches(keys[i], skip: facet)) keys[i][facet]!,
  ];
  return StoreFacetGroup(
    facet: facet,
    selected: selected,
    values: [
      for (final key in ordered)
        StoreFacetValue(
          key: key,
          label: labels[key],
          selected: selected.contains(key),
          count: candidates
              .where((row) => storeFacetPasses(facet, {key}, row))
              .length,
        ),
    ],
  );
}

List<String> _order(
  StoreFacet facet,
  Set<String> values,
  Map<String, String> labels,
  List<String> repoOrder,
) {
  int byLabel(String a, String b) =>
      (labels[a] ?? a).toLowerCase().compareTo((labels[b] ?? b).toLowerCase());
  switch (facet) {
    case StoreFacet.kind:
      final known = PluginKind.values.map((k) => k.value).toList();
      return [
        for (final k in known)
          if (values.contains(k)) k,
        ...values.where((v) => !known.contains(v)).toList()..sort(),
      ];
    case StoreFacet.language:
      return [
        if (values.contains(pluginLanguagesGlobal)) pluginLanguagesGlobal,
        ...values.where((v) => v != pluginLanguagesGlobal).toList()..sort(),
      ];
    case StoreFacet.author:
      return values.toList()..sort(byLabel);
    case StoreFacet.source:
      return [
        for (final url in repoOrder)
          if (values.contains(url)) url,
        ...(values
            .where((v) => v != storeSourceFromFile && !repoOrder.contains(v))
            .toList()
          ..sort(byLabel)),
        if (values.contains(storeSourceFromFile)) storeSourceFromFile,
      ];
  }
}
