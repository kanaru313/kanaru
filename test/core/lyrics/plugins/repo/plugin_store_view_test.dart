import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_catalog.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_repo.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_store_view.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_address_rules.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_fetch_exception.dart';

const urlA = 'https://a.example.com/plugins.json';
const urlB = 'https://b.example.com/plugins.json';

PluginCatalogEntry entry(
  String slug, {
  String? name,
  int version = 1,
  int apiVersion = 1,
  List<String> hosts = const ['host.example.com'],
  String author = '',
  Uri? icon,
  PluginKind kind = PluginKind.lyrics,
  List<String> languages = const [],
}) => PluginCatalogEntry(
  kind: kind,
  slug: slug,
  name: name ?? slug,
  version: version,
  apiVersion: apiVersion,
  hosts: hosts,
  path: Uri.parse('https://a.example.com/$slug.zip'),
  author: author,
  icon: icon,
  languages: languages,
);

PluginRepo repo(
  String url,
  String name,
  List<PluginCatalogEntry> entries, {
  RepoLoadError? error,
}) => PluginRepo(
  url: url,
  name: name,
  author: '',
  addedAt: 1,
  error: error,
  kind: RepoAddressKind.public,
  catalog: PluginCatalog(name: name, author: '', entries: entries, dropped: 0),
);

LyricsPluginRecord record(
  String id,
  String name, {
  int version = 1,
  String? repoUrl,
  String? slug,
  String sourceName = 'x.zip',
  bool removed = false,
  String? author,
  List<String> hosts = const ['host.example.com'],
  PluginKind? kind = PluginKind.lyrics,
}) => LyricsPluginRecord(
  kind: kind,
  installId: id,
  name: name,
  author: author,
  version: version,
  apiVersion: 1,
  hosts: hosts,
  config: const [],
  packageDir: '$id/v1-1',
  sourceKind: repoUrl == null
      ? LyricsPluginSourceKind.file
      : LyricsPluginSourceKind.repo,
  sourceName: sourceName,
  repoUrl: repoUrl,
  repoSlug: slug,
  installedAt: 1,
  updatedAt: 1,
  removedAt: removed ? 5 : null,
);

PluginStoreFilters only(StoreFacet facet, String key) =>
    const PluginStoreFilters().toggled(facet, key);

List<String> names(List<StoreRow> rows) => [for (final r in rows) r.name];

PluginStoreView view(
  List<LyricsPluginRecord> records,
  List<PluginRepo> repos, {
  String search = '',
  PluginStoreFilters filters = const PluginStoreFilters(),
  Map<String, List<String>> installedLanguages = const {},
}) => buildPluginStoreView(
  PluginStoreInput(
    records: records,
    repos: repos,
    search: search,
    filters: filters,
    installedLanguages: installedLanguages,
  ),
);

void main() {
  final repos = [
    repo(urlA, 'Alpha Repo', [
      entry('one', name: 'One', version: 2),
      entry('two', name: 'Two'),
      entry('three', name: 'Three', author: 'Zed', hosts: ['lyrics.zed.org']),
      entry('future', name: 'Future', apiVersion: 2),
    ]),
    repo(urlB, 'Beta Repo', [entry('one', name: 'One')]),
  ];

  test('sections: updates, installed, not installed, hidden count', () {
    final records = [
      record('p1', 'One', repoUrl: urlA, slug: 'one'),
      record('p2', 'Two', repoUrl: urlA, slug: 'two'),
      record('p3', 'Mine', sourceName: 'mine.zip'),
    ];
    final v = view(records, repos);
    expect(names(v.updates), ['One']);
    expect(v.updates.single.record!.installId, 'p1');
    expect(v.updates.single.entry!.version, 2);
    expect(names(v.installed), ['Two', 'Mine']);
    expect(v.installed.last.isFromFile, isTrue);
    expect(v.installed.last.repoName, isNull);
    expect(names(v.notInstalled), ['Three', 'One']);
    expect(v.notInstalled.last.repoName, 'Beta Repo');
    expect(v.needsNewerApp, 1);
    expect(v.hasFileSource, isTrue);
    expect(v.hasFilters, isTrue);
    expect(v.isEmpty, isFalse);
  });

  test('installed is by (repo url, slug): same slug in another repo shows', () {
    final v = view([
      record('p1', 'One', repoUrl: urlA, slug: 'one', version: 2),
    ], repos);
    expect(names(v.installed), ['One']);
    expect(v.notInstalled.map((r) => r.repoUrl), contains(urlB));
    expect(
      v.notInstalled.where((r) => r.repoUrl == urlA && r.entry!.slug == 'one'),
      isEmpty,
    );
  });

  test('a newer catalog entry that needs a newer app is no update', () {
    final r = [
      repo(urlA, 'A', [entry('one', version: 9, apiVersion: 2)]),
    ];
    final v = view([record('p1', 'One', repoUrl: urlA, slug: 'one')], r);
    expect(v.updates, isEmpty);
    expect(names(v.installed), ['One']);
    expect(v.needsNewerApp, 0, reason: 'installed entries are not counted');
  });

  test('file plugins never update, even with a matching catalog name', () {
    final v = view([record('p1', 'One')], repos);
    expect(v.updates, isEmpty);
    expect(names(v.installed), ['One']);
  });

  test(
    'a removed record is not installed; its entry is under not installed',
    () {
      final v = view([
        record('p1', 'One', repoUrl: urlA, slug: 'one', removed: true),
      ], repos);
      expect(v.installed, isEmpty);
      expect(
        v.notInstalled.where((r) => r.repoUrl == urlA && r.name == 'One'),
        hasLength(1),
      );
      expect(v.hasFileSource, isFalse);
    },
  );

  test(
    'a plugin whose repo was removed stays installed with its stored name',
    () {
      final v = view([
        record(
          'p1',
          'Old',
          repoUrl: 'https://gone.example.com/x',
          slug: 'old',
          sourceName: 'Gone Repo',
        ),
      ], repos);
      expect(v.updates, isEmpty);
      final row = v.installed.single;
      expect(row.repoName, 'Gone Repo');
      expect(row.entry, isNull);
      expect(row.isFromFile, isFalse);
    },
  );

  test('search matches name, author, repo name and host', () {
    final records = [
      record(
        'p3',
        'Mine',
        author: 'Quinn',
        sourceName: 'mine.zip',
        hosts: ['quinn.example.net'],
      ),
    ];
    expect(names(view(records, repos, search: 'THREE').notInstalled), [
      'Three',
    ]);
    expect(names(view(records, repos, search: 'zed').notInstalled), ['Three']);
    expect(names(view(records, repos, search: 'zed.org').notInstalled), [
      'Three',
    ]);
    expect(names(view(records, repos, search: 'beta').notInstalled), ['One']);
    expect(names(view(records, repos, search: 'quinn').installed), ['Mine']);
    expect(names(view(records, repos, search: 'quinn.example').installed), [
      'Mine',
    ]);
    expect(view(records, repos, search: 'nothing').isEmpty, isTrue);
    expect(view(records, repos, search: ' ').isEmpty, isFalse);
  });

  test('search and filter also apply to the hidden count', () {
    expect(view([], repos, search: 'future').needsNewerApp, 1);
    expect(view([], repos, search: 'one').needsNewerApp, 0);
    expect(
      view([], repos, filters: only(StoreFacet.source, urlB)).needsNewerApp,
      0,
    );
    expect(
      view([], repos, filters: only(StoreFacet.source, urlA)).needsNewerApp,
      1,
    );
  });

  test('source filter: repos and from file, OR within the group', () {
    final records = [
      record('p1', 'Two', repoUrl: urlA, slug: 'two'),
      record('p3', 'Mine'),
      record('p4', 'Gone', repoUrl: 'https://gone.example.com/x', slug: 'g'),
    ];
    final a = view(records, repos, filters: only(StoreFacet.source, urlA));
    expect(names(a.installed), ['Two']);
    expect(names(a.notInstalled), ['One', 'Three']);
    final b = view(records, repos, filters: only(StoreFacet.source, urlB));
    expect(b.installed, isEmpty);
    expect(names(b.notInstalled), ['One']);
    final file = view(
      records,
      repos,
      filters: only(StoreFacet.source, storeSourceFromFile),
    );
    expect(names(file.installed), ['Mine']);
    expect(file.notInstalled, isEmpty);
    final both = view(
      records,
      repos,
      filters: only(
        StoreFacet.source,
        urlB,
      ).toggled(StoreFacet.source, storeSourceFromFile),
    );
    expect(names(both.installed), ['Mine']);
    expect(names(both.notInstalled), ['One']);
    final gone = view(
      records,
      repos,
      filters: only(StoreFacet.source, 'https://gone.example.com/x'),
    );
    expect(names(gone.installed), ['Gone']);
    expect(names(view(records, repos).installed), ['Two', 'Mine', 'Gone']);
  });

  test('failing repos are listed and their plugins still shown', () {
    const error = RepoLoadError(RepoFetchErrorKind.network);
    final r = [
      repo(urlA, 'Alpha Repo', [entry('one')], error: error),
      repo(urlB, 'Beta Repo', [entry('two')]),
    ];
    final v = view([], r);
    expect(v.failingRepos.single.name, 'Alpha Repo');
    expect(v.failingRepos.single.url, urlA);
    expect(v.failingRepos.single.error, error);
    expect(names(v.notInstalled), ['one', 'two']);
    expect(
      view([], r, filters: only(StoreFacet.source, urlB)).failingRepos,
      hasLength(1),
      reason: 'the banner does not depend on the filter',
    );
  });

  test('a repo that was never fetched lists nothing', () {
    const never = PluginRepo(url: urlA, name: 'N', author: '', addedAt: 1);
    final v = view([], [never]);
    expect(v.isEmpty, isTrue);
    expect(v.hasFilters, isFalse);
  });

  test('catalog icon', () {
    final icon = Uri.parse('https://a.example.com/i.png');
    final v = view([], [
      repo(urlA, 'A', [entry('one', icon: icon)]),
    ]);
    expect(v.notInstalled.single.catalogIcon, icon);
    expect(v.sources.single.url, urlA);
  });

  test('an unavailable feature is told apart from an empty store', () {
    final empty = buildPluginStoreView(
      const PluginStoreInput(records: [], repos: []),
    );
    final unavailable = buildPluginStoreView(
      const PluginStoreInput(records: [], repos: [], available: false),
    );
    expect(empty.isEmpty && empty.available, isTrue);
    expect(unavailable.isEmpty, isTrue);
    expect(unavailable.available, isFalse);
  });

  group('kind filter', () {
    final mixed = [
      repo(urlA, 'Alpha Repo', [
        entry('lyr', name: 'LyrNew'),
        entry('tr', name: 'TrNew', kind: PluginKind.translate),
        entry('lyr-up', name: 'LyrUp', version: 2),
        entry('tr-up', name: 'TrUp', version: 2, kind: PluginKind.translate),
        entry('src', name: 'SrcNew', kind: PluginKind.source),
        entry('src-up', name: 'SrcUp', version: 2, kind: PluginKind.source),
      ]),
    ];
    final records = [
      record('plugin-lyr-up', 'LyrUp', repoUrl: urlA, slug: 'lyr-up'),
      record(
        'plugin-tr-up',
        'TrUp',
        repoUrl: urlA,
        slug: 'tr-up',
        kind: PluginKind.translate,
      ),
      record(
        'plugin-src-up',
        'SrcUp',
        repoUrl: urlA,
        slug: 'src-up',
        kind: PluginKind.source,
      ),
      record('plugin-lyr-file', 'LyrFile'),
      record('plugin-tr-file', 'TrFile', kind: PluginKind.translate),
      record('plugin-src-file', 'SrcFile', kind: PluginKind.source),
      record('plugin-odd', 'Odd', kind: null),
    ];

    test('no filter lists every known kind in every section', () {
      final v = view(records, mixed);
      expect(names(v.updates), ['LyrUp', 'TrUp', 'SrcUp']);
      expect(names(v.installed), ['LyrFile', 'TrFile', 'SrcFile']);
      expect(names(v.notInstalled), ['LyrNew', 'TrNew', 'SrcNew']);
      expect(v.showKindTag, isTrue);
    });

    test('one kind or the translation family lists only that family', () {
      for (final kind in PluginKind.values) {
        final v = view(
          records,
          mixed,
          filters: PluginStoreFilters.initial(kind),
        );
        for (final row in [...v.updates, ...v.installed, ...v.notInstalled]) {
          // A translation kind lists the whole translation family.
          expect(row.kind?.isTranslation, kind.isTranslation);
        }
        expect(v.shownCount, 3);
        expect(v.showKindTag, isFalse);
      }
      final tr = view(
        records,
        mixed,
        filters: PluginStoreFilters.initial(PluginKind.translate),
      );
      expect(names(tr.updates), ['TrUp']);
      expect(names(tr.installed), ['TrFile']);
      expect(names(tr.notInstalled), ['TrNew']);
      final src = view(
        records,
        mixed,
        filters: PluginStoreFilters.initial(PluginKind.source),
      );
      expect(names(src.updates), ['SrcUp']);
      expect(names(src.installed), ['SrcFile']);
      expect(names(src.notInstalled), ['SrcNew']);
    });

    test('kind tags show only when the filtered rows mix kinds', () {
      final ai = [
        repo(urlA, 'Alpha Repo', [
          entry('tr', name: 'Tr', kind: PluginKind.translate),
          entry('ai', name: 'Ai', kind: PluginKind.aiTranslate),
        ]),
      ];
      final filters = PluginStoreFilters.initial(PluginKind.translate);
      expect(view(const [], ai, filters: filters).showKindTag, isTrue);
      // The search text does not change it.
      expect(
        view(const [], ai, filters: filters, search: 'Ai').showKindTag,
        isTrue,
      );
      final plain = [
        repo(urlA, 'Alpha Repo', [
          entry('tr', name: 'Tr', kind: PluginKind.translate),
        ]),
      ];
      expect(view(const [], plain, filters: filters).showKindTag, isFalse);
    });

    test('a record of an unknown kind is never listed', () {
      final all = view(records, mixed);
      expect([
        ...names(all.installed),
        ...names(all.updates),
      ], isNot(contains('Odd')));
      expect(all.shownCount, 9);
    });
  });

  group('filters and languages', () {
    final catalog = [
      repo(urlA, 'Alpha Repo', [
        entry('vi', name: 'Viet', author: 'Ann', languages: ['vie']),
        entry('ja', name: 'Jap', author: 'ann', languages: ['jpn']),
        entry('any', name: 'Any', author: 'Bob'),
      ]),
    ];

    test('a language pick lists only plugins of that language', () {
      final v = view([], catalog, filters: only(StoreFacet.language, 'vie'));
      expect(names(v.notInstalled), ['Viet']);
      final both = only(
        StoreFacet.language,
        'vie',
      ).toggled(StoreFacet.language, '*');
      expect(names(view([], catalog, filters: both).notInstalled), [
        'Viet',
        'Any',
      ]);
    });

    test('author filter folds case and OR-s values', () {
      final v = view([], catalog, filters: only(StoreFacet.author, 'ann'));
      expect(names(v.notInstalled), ['Viet', 'Jap']);
    });

    test('groups are AND-ed', () {
      final v = view(
        [],
        catalog,
        filters: only(
          StoreFacet.author,
          'ann',
        ).toggled(StoreFacet.language, 'jpn'),
      );
      expect(names(v.notInstalled), ['Jap']);
    });

    test('languages: entry wins, else installed map, else global', () {
      final records = [
        record('p1', 'Viet', repoUrl: urlA, slug: 'vi'),
        record('p2', 'Mine'),
        record('p3', 'Other'),
      ];
      final v = view(
        records,
        catalog,
        installedLanguages: {
          'p1': ['jpn'],
          'p2': ['kor'],
        },
      );
      final byName = {
        for (final r in [...v.installed, ...v.notInstalled]) r.name: r,
      };
      expect(byName['Viet']!.languages, ['vie']);
      expect(byName['Mine']!.languages, ['kor']);
      expect(byName['Other']!.languages, isEmpty);
    });

    test('facets are built from the listed rows, needs-newer excluded', () {
      final v = view([], [
        repo(urlA, 'A', [
          entry('x', author: 'Zed'),
          entry('y', author: 'Yan'),
          entry('z', author: 'Qua', apiVersion: 2),
        ]),
      ]);
      final author = v.facets.firstWhere((g) => g.facet == StoreFacet.author);
      expect(author.values.map((e) => e.key), ['yan', 'zed']);
      expect(v.needsNewerApp, 1);
    });

    test('needs-newer entries and unknown kinds add no facet values', () {
      final v = view(
        [record('p9', 'Odd', kind: null, author: 'Nobody')],
        [
          repo(urlA, 'A', [
            entry('x', author: 'Zed', languages: ['vie']),
            entry('f', author: 'Future', apiVersion: 2, languages: ['jpn']),
          ]),
        ],
      );
      final keys = {
        for (final g in v.facets) g.facet: g.values.map((e) => e.key).toList(),
      };
      expect(keys[StoreFacet.author], ['zed']);
      expect(keys[StoreFacet.language], ['vie']);
      expect(keys[StoreFacet.source], [urlA]);
    });
  });
}
