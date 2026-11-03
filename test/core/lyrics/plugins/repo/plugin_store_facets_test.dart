import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_catalog.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_store_facets.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_store_filters.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_store_rows.dart';

const urlA = 'https://a.example.com/p.json';
const urlB = 'https://b.example.com/p.json';

StoreRow row(
  String name, {
  PluginKind kind = PluginKind.lyrics,
  String author = '',
  List<String> languages = const [],
  String? repoUrl = urlA,
  String? repoName = 'Repo A',
}) => StoreRow(
  name: name,
  author: author,
  hosts: const [],
  repoUrl: repoUrl,
  repoName: repoName,
  languages: languages,
  entry: PluginCatalogEntry(
    kind: kind,
    slug: name,
    name: name,
    version: 1,
    apiVersion: 1,
    hosts: const [],
    path: Uri.parse('https://x.example.com/$name.zip'),
    author: author,
  ),
);

bool all(StoreRow r) => true;

StoreFacetGroup group(List<StoreFacetGroup> g, StoreFacet f) =>
    g.firstWhere((e) => e.facet == f);

Map<String, int> counts(StoreFacetGroup g) => {
  for (final v in g.values) v.key: v.count,
};

void main() {
  const none = PluginStoreFilters();

  final rows = [
    row('a', author: 'Ann', languages: ['vie']),
    row('b', author: 'ann', kind: PluginKind.translate, languages: ['jpn']),
    row('c', author: 'Bob', repoUrl: urlB, repoName: 'Repo B'),
    row('d', repoUrl: null, repoName: null, languages: ['vie', 'jpn']),
  ];

  test('values come from all rows, in the documented order', () {
    final g = computeStoreFacets(rows, none, all, repoOrder: [urlB, urlA]);
    expect(group(g, StoreFacet.kind).values.map((v) => v.key), [
      'lyrics',
      'translate',
    ]);
    expect(group(g, StoreFacet.language).values.map((v) => v.key), [
      '*',
      'jpn',
      'vie',
    ]);
    final author = group(g, StoreFacet.author);
    expect(author.values.map((v) => v.key), ['ann', 'bob']);
    expect(author.values.first.label, 'Ann', reason: 'first spelling');
    expect(counts(author), {'ann': 2, 'bob': 1});
    expect(group(g, StoreFacet.source).values.map((v) => v.key), [
      urlB,
      urlA,
      storeSourceFromFile,
    ]);
    expect(group(g, StoreFacet.source).values.first.label, 'Repo B');
  });

  test('language counts exclude global plugins', () {
    final g = computeStoreFacets(rows, none, all);
    expect(counts(group(g, StoreFacet.language)), {'*': 1, 'jpn': 2, 'vie': 2});
  });

  test('counts skip their own group but follow the others and the search', () {
    final f = none.toggled(StoreFacet.kind, 'lyrics');
    final g = computeStoreFacets(rows, f, all);
    // Own group ignored: both kinds still counted.
    expect(counts(group(g, StoreFacet.kind)), {'lyrics': 3, 'translate': 1});
    // Other groups follow the kind pick: b (translate) is out.
    expect(counts(group(g, StoreFacet.author)), {'ann': 1, 'bob': 1});
    final searched = computeStoreFacets(rows, f, (r) => r.name == 'a');
    expect(counts(group(searched, StoreFacet.author)), {'ann': 1, 'bob': 0});
    expect(
      group(searched, StoreFacet.author).values.length,
      2,
      reason: 'values ignore the search',
    );
  });

  test('a group with one value is hidden', () {
    final g = computeStoreFacets([row('a'), row('b')], none, all);
    expect(group(g, StoreFacet.kind).visible, isFalse);
    expect(group(g, StoreFacet.source).visible, isFalse);
    expect(group(g, StoreFacet.language).visible, isFalse);
  });

  test(
    'a picked value no row has stays, with count 0, and shows the group',
    () {
      final f = none.toggled(StoreFacet.kind, 'translate');
      final g = computeStoreFacets([row('a')], f, all);
      final kind = group(g, StoreFacet.kind);
      expect(kind.visible, isTrue);
      expect(counts(kind), {'lyrics': 1, 'translate': 0});
      expect(kind.values.last.selected, isTrue);
      expect(kind.values.last.label, isNull);
      final stale = none.toggled(
        StoreFacet.source,
        'https://gone.example.com/x',
      );
      final s = group(
        computeStoreFacets([row('a')], stale, all, repoOrder: [urlA]),
        StoreFacet.source,
      );
      expect(s.visible, isTrue);
      expect(s.values.map((v) => v.key), [urlA, 'https://gone.example.com/x']);
    },
  );

  test(
    'rows of a removed repository form their own source, sorted by name',
    () {
      final g = computeStoreFacets(
        [
          row('a'),
          row('b', repoUrl: 'https://z.example.com', repoName: 'Zed'),
          row('c', repoUrl: 'https://m.example.com', repoName: 'Mid'),
        ],
        none,
        all,
        repoOrder: [urlA],
      );
      expect(group(g, StoreFacet.source).values.map((v) => v.label), [
        'Repo A',
        'Mid',
        'Zed',
      ]);
    },
  );

  test('the same slug in two repositories counts once per source', () {
    final g = computeStoreFacets(
      [row('a'), row('a', repoUrl: urlB, repoName: 'Repo B')],
      none,
      all,
    );
    expect(counts(group(g, StoreFacet.source)), {urlA: 1, urlB: 1});
  });

  test('unknown-kind plugins give no kind value; newer-app ones none anywhere', () {
    // Rows handed in never include needs-newer entries; the view filters them.
    final g = computeStoreFacets([row('a', author: 'Ann')], none, all);
    expect(group(g, StoreFacet.kind).values.map((v) => v.key), ['lyrics']);
  });
}
