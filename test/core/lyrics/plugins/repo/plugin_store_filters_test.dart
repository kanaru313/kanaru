import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_store_filters.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_store_rows.dart';

StoreRow row({
  String author = '',
  List<String> languages = const [],
  String? repoUrl = 'https://a.example.com/p.json',
}) => StoreRow(
  name: 'n',
  author: author,
  hosts: const [],
  repoUrl: repoUrl,
  languages: languages,
);

Map<StoreFacet, Set<String>> keys({
  String kind = 'lyrics',
  Set<String> languages = const {'*'},
  Set<String> author = const {},
  String source = 'u',
}) => {
  StoreFacet.kind: {kind},
  StoreFacet.language: languages,
  StoreFacet.author: author,
  StoreFacet.source: {source},
};

void main() {
  const none = PluginStoreFilters();

  test('initial: null is empty, a kind is picked', () {
    expect(PluginStoreFilters.initial(null).isEmpty, isTrue);
    final f = PluginStoreFilters.initial(PluginKind.translate);
    expect(f.selected(StoreFacet.kind), {'translate', 'ai-translate'});
    expect(f.activeCount, 1);
    final lyrics = PluginStoreFilters.initial(PluginKind.lyrics);
    expect(lyrics.selected(StoreFacet.kind), {'lyrics'});
    expect(lyrics.activeCount, 1);
    final ai = PluginStoreFilters.initial(PluginKind.aiTranslate);
    expect(ai.selected(StoreFacet.kind), {'translate', 'ai-translate'});
    expect(ai.activeCount, 1);
  });

  test('toggle adds and removes; cleared empties one group', () {
    final f = none
        .toggled(StoreFacet.author, 'a')
        .toggled(StoreFacet.author, 'b')
        .toggled(StoreFacet.source, 'u');
    expect(f.selected(StoreFacet.author), {'a', 'b'});
    expect(f.activeCount, 2);
    expect(f.toggled(StoreFacet.author, 'a').selected(StoreFacet.author), {
      'b',
    });
    expect(f.toggled(StoreFacet.source, 'u').activeCount, 1);
    expect(f.cleared(StoreFacet.author).activeCount, 1);
    expect(f.cleared(StoreFacet.author).selected(StoreFacet.author), isEmpty);
  });

  test('filters are values', () {
    final a = none
        .toggled(StoreFacet.author, 'a')
        .toggled(StoreFacet.kind, 'k');
    final b = none
        .toggled(StoreFacet.kind, 'k')
        .toggled(StoreFacet.author, 'a');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == none, isFalse);
  });

  test('OR within a group, AND across groups', () {
    final f = none
        .toggled(StoreFacet.author, 'a')
        .toggled(StoreFacet.author, 'b')
        .toggled(StoreFacet.kind, 'lyrics');
    expect(f.matches(keys(author: {'a'})), isTrue);
    expect(f.matches(keys(author: {'b'})), isTrue);
    expect(f.matches(keys(author: {'c'})), isFalse);
    expect(f.matches(keys(author: {'a'}, kind: 'translate')), isFalse);
  });

  test('skip ignores one group', () {
    final f = none.toggled(StoreFacet.author, 'a');
    expect(f.matches(keys(author: {'c'})), isFalse);
    expect(f.matches(keys(author: {'c'}), skip: StoreFacet.author), isTrue);
  });

  test('a language pick hides global plugins unless Global is picked', () {
    final vie = none.toggled(StoreFacet.language, 'vie');
    expect(vie.matches(keys()), isFalse);
    expect(vie.matches(keys(languages: {'vie', 'jpn'})), isTrue);
    expect(vie.matches(keys(languages: {'zho'})), isFalse);
    final both = vie.toggled(StoreFacet.language, '*');
    expect(both.matches(keys()), isTrue);
    expect(both.matches(keys(languages: {'vie'})), isTrue);
    expect(both.matches(keys(languages: {'zho'})), isFalse);
  });

  test('the global value selects only global plugins', () {
    final global = none.toggled(StoreFacet.language, '*');
    expect(global.matches(keys()), isTrue);
    expect(global.matches(keys(languages: {'vie'})), isFalse);
  });

  test('an author selection hides plugins without an author', () {
    final f = none.toggled(StoreFacet.author, 'a');
    expect(f.matches(keys()), isFalse);
  });

  test('row keys: kind-less, global, blank author, file source', () {
    final k = storeRowFacetKeys(row(author: '  Ann ', repoUrl: null));
    expect(k[StoreFacet.language], {'*'});
    expect(k[StoreFacet.author], {'ann'});
    expect(k[StoreFacet.source], {storeSourceFromFile});
    expect(k[StoreFacet.kind], isEmpty);
    final v = storeRowFacetKeys(row(languages: ['vie'], author: ' '));
    expect(v[StoreFacet.language], {'vie'});
    expect(v[StoreFacet.author], isEmpty);
    expect(v[StoreFacet.source], {'https://a.example.com/p.json'});
  });

  test('picked sets cannot be mutated from outside', () {
    final initial = PluginStoreFilters.initial(PluginKind.lyrics);
    expect(
      () => initial.selected(StoreFacet.kind).add('x'),
      throwsUnsupportedError,
    );
    final f = none.toggled(StoreFacet.author, 'a');
    expect(
      () => f.selected(StoreFacet.author).add('x'),
      throwsUnsupportedError,
    );
    expect(f.toggled(StoreFacet.author, 'a'), none);
    expect(f.toggled(StoreFacet.author, 'a').activeCount, 0);
  });
}
