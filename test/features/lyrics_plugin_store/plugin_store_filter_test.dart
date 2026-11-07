import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_catalog.dart';
import 'package:kanaru/features/lyrics_plugin_store/plugin_store_kind_tag.dart';
import 'package:kanaru/features/lyrics_plugin_store/plugin_store_page.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_sheet_frame.dart';
import 'package:material_ui/material_ui.dart';

import 'store_test_harness.dart';

PluginCatalogEntry _entry(
  String slug,
  String name, {
  PluginKind kind = PluginKind.lyrics,
  String author = 'someone',
  List<String> languages = const [],
}) => PluginCatalogEntry(
  kind: kind,
  slug: slug,
  name: name,
  version: 3,
  apiVersion: 1,
  hosts: const ['music.example.com'],
  path: Uri.parse('https://a.example.com/$slug.zip'),
  author: author,
  languages: languages,
);

Widget _page({PluginKind? initialKind}) => PluginStorePage(
  initialKind: initialKind,
  onOpenInstalled: (_, _) {},
  onOpenCatalogItem: (_, _) {},
  onOpenRepositories: () {},
);

/// A filter chip whose label starts with [label] (the count follows it).
Finder _chip(String label) => find.byWidgetPredicate((w) {
  if (w is! FilterChip || w.label is! Text) return false;
  final text = w.label as Text;
  final plain = text.textSpan?.toPlainText() ?? text.data ?? '';
  return plain == label || plain.startsWith('$label  ');
});

bool _selected(WidgetTester tester, String label) =>
    tester.widget<FilterChip>(_chip(label)).selected;

Finder get _filterButton => find.byIcon(AppIcons.filter);

Future<void> _openModal(WidgetTester tester) async {
  await tester.tap(_filterButton);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  // The groups scroll inside the modal.
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

int? _badge(WidgetTester tester) {
  final badge = tester.widget<Badge>(find.byType(Badge));
  if (!badge.isLabelVisible) return null;
  return int.parse(((badge.label! as ExcludeSemantics).child! as Text).data!);
}

void main() {
  // Repo A: two lyrics plugins by "kanaru313" (Vietnamese, Chinese) and a
  // global translate plugin; repo B: a Japanese lyrics plugin; plus a
  // translate plugin installed from a file; one repo plugin is installed.
  final repoAWith = repoOf(
    repoA,
    'Kho A',
    entries: [
      _entry('lyr-vi', 'Lyr VI', author: 'kanaru313', languages: ['vie']),
      _entry('lyr-zh', 'Lyr ZH', author: 'kanaru313', languages: ['zho']),
      _entry('tr-glob', 'Tr Glob', kind: PluginKind.translate, author: 'Other'),
    ],
  );
  final repoBWith = repoOf(
    repoB,
    'Kho B',
    entries: [
      _entry('lyr-ja', 'Lyr JA', author: 'jp-fans', languages: ['jpn']),
    ],
  );
  final records = [
    recordOf(
      'plugin-lyr-vi',
      name: 'Lyr VI',
      repoUrl: repoA,
      repoSlug: 'lyr-vi',
      sourceName: 'Kho A',
      author: 'kanaru313',
    ),
    recordOf(
      'plugin-file',
      name: 'FileTr',
      kind: PluginKind.translate,
      author: 'oss',
    ),
  ];
  const all = ['Lyr VI', 'Lyr ZH', 'Tr Glob', 'Lyr JA', 'FileTr'];

  Future<void> pump(
    WidgetTester tester, {
    PluginKind? initialKind,
    Locale locale = const Locale('en'),
    Size size = const Size(1000, 1600),
  }) => pumpStore(
    tester,
    _page(initialKind: initialKind),
    repos: [repoAWith, repoBWith],
    records: records,
    locale: locale,
    size: size,
  );

  void expectRows(Iterable<String> shown) {
    for (final name in all) {
      expect(
        find.text(name),
        shown.contains(name) ? findsOneWidget : findsNothing,
        reason: name,
      );
    }
  }

  group('type', () {
    testWidgets('opens on every kind with a kind tag on each row', (
      tester,
    ) async {
      await pump(tester);
      expectRows(all);
      expect(find.byType(PluginStoreKindTag), findsNWidgets(5));
      expect(_badge(tester), isNull);
    });

    testWidgets('the translation mount preselects Translate, clearable', (
      tester,
    ) async {
      await pump(tester, initialKind: PluginKind.translate);
      expectRows(['Tr Glob', 'FileTr']);
      expect(find.byType(PluginStoreKindTag), findsNothing);
      expect(_badge(tester), 1);
      await _openModal(tester);
      expect(_selected(tester, 'Translate'), isTrue);
      expect(_selected(tester, 'Lyrics'), isFalse);
      await _tap(tester, find.widgetWithText(FilterChip, 'All').first);
      expectRows(all);
      expect(find.byType(PluginStoreKindTag), findsNWidgets(5));
      expect(_badge(tester), isNull);
    });

    testWidgets('translate and ai-translate rows both carry a kind tag', (
      tester,
    ) async {
      await pumpStore(
        tester,
        _page(initialKind: PluginKind.translate),
        repos: [
          repoOf(
            repoA,
            'Kho A',
            entries: [
              _entry('tr', 'Plain Tr', kind: PluginKind.translate),
              _entry('ai', 'Smart Tr', kind: PluginKind.aiTranslate),
            ],
          ),
        ],
        records: const [],
        size: const Size(1000, 1600),
      );
      expect(find.text('Plain Tr'), findsOneWidget);
      expect(find.text('Smart Tr'), findsOneWidget);
      expect(find.byType(PluginStoreKindTag), findsNWidgets(2));
    });

    testWidgets('a source entry adds a Source chip that filters to it', (
      tester,
    ) async {
      await pumpStore(
        tester,
        _page(),
        repos: [
          repoOf(
            repoA,
            'Kho A',
            entries: [
              _entry('lyr-vi', 'Lyr VI'),
              _entry('yt', 'YT Source', kind: PluginKind.source),
            ],
          ),
        ],
        records: const [],
        size: const Size(1000, 1600),
      );
      expect(find.text('Lyr VI'), findsOneWidget);
      expect(find.text('YT Source'), findsOneWidget);
      await _openModal(tester);
      await _tap(tester, _chip('Source'));
      expect(find.text('Lyr VI'), findsNothing);
      expect(find.text('YT Source'), findsOneWidget);
    });

    testWidgets('picks add up and unpick back to all', (tester) async {
      await pump(tester);
      await _openModal(tester);
      await _tap(tester, _chip('Lyrics'));
      expectRows(['Lyr VI', 'Lyr ZH', 'Lyr JA']);
      expect(find.byType(PluginStoreKindTag), findsNothing);
      await _tap(tester, _chip('Translate'));
      expectRows(all);
      expect(find.byType(PluginStoreKindTag), findsNWidgets(5));
      await _tap(tester, _chip('Lyrics'));
      await _tap(tester, _chip('Translate'));
      expectRows(all);
      expect(_badge(tester), isNull);
    });
  });

  group('author, language and source', () {
    testWidgets('authors are multi-select and counts follow other groups', (
      tester,
    ) async {
      await pump(tester);
      await _openModal(tester);
      await _tap(tester, _chip('kanaru313'));
      await _tap(tester, _chip('jp-fans'));
      expectRows(['Lyr VI', 'Lyr ZH', 'Lyr JA']);
      await _tap(tester, _chip('Translate'));
      expectRows([]);
      // With Translate picked, no kanaru313 plugin would be listed.
      expect(find.text('kanaru313  0'), findsOneWidget);
      expect(find.text('Other  1'), findsOneWidget);
    });

    testWidgets(
      'a language pick lists only that language; Global adds global plugins',
      (tester) async {
        await pump(tester);
        await _openModal(tester);
        expect(find.text('Global  2'), findsOneWidget);
        await _tap(tester, _chip(en.languageNameVie));
        expectRows(['Lyr VI']);
        expect(find.text('Global  2'), findsOneWidget);
        await _tap(tester, _chip(en.languageNameZho));
        expectRows(['Lyr VI', 'Lyr ZH']);
        await _tap(tester, _chip('Global'));
        expectRows(['Lyr VI', 'Lyr ZH', 'Tr Glob', 'FileTr']);
      },
    );

    testWidgets('the source group lists repositories and From file', (
      tester,
    ) async {
      await pump(tester);
      await _openModal(tester);
      expect(_chip('Kho A'), findsOneWidget);
      expect(_chip('Kho B'), findsOneWidget);
      await _tap(tester, _chip('From file'));
      expectRows(['FileTr']);
      await _tap(tester, _chip('Kho B'));
      expectRows(['FileTr', 'Lyr JA']);
    });

    testWidgets('the badge counts groups with a pick, in primary', (
      tester,
    ) async {
      await pump(tester);
      await _openModal(tester);
      await _tap(tester, _chip('Lyrics'));
      await _tap(tester, _chip('Translate'));
      await _tap(tester, _chip('kanaru313'));
      expect(_badge(tester), 2);
      final primary = Theme.of(tester.element(find.byType(Badge))).colorScheme;
      expect(
        tester.widget<Icon>(find.byIcon(AppIcons.filter)).color,
        primary.primary,
      );
    });
  });

  testWidgets('the active filter button announces its count once', (
    tester,
  ) async {
    await pump(tester, initialKind: PluginKind.translate);
    expect(find.byTooltip('Filter, 1 active'), findsOneWidget);
    expect(find.byTooltip('Filter'), findsNothing);
  });

  group('visibility', () {
    // One author, global languages, one repo: only the type has 2 values.
    Future<void> pumpTwoKinds(WidgetTester tester, {String second = 'solo'}) =>
        pumpStore(
          tester,
          _page(),
          repos: [
            repoOf(
              repoA,
              'Kho A',
              entries: [
                _entry('a', 'A', author: 'solo'),
                _entry('b', 'B', kind: PluginKind.translate, author: second),
              ],
            ),
          ],
        );

    testWidgets('groups with fewer than two values are hidden', (tester) async {
      await pumpTwoKinds(tester);
      await _openModal(tester);
      expect(find.text('Type'), findsOneWidget);
      expect(find.text('Author'), findsNothing);
      expect(find.text('Language'), findsNothing);
      expect(find.text('Source'), findsNothing);
    });

    testWidgets('the icon is hidden when nothing can be filtered', (
      tester,
    ) async {
      await pumpStore(
        tester,
        _page(),
        repos: [
          repoOf(repoA, 'Kho A', entries: [_entry('a', 'A')]),
        ],
      );
      expect(find.text('A'), findsOneWidget);
      expect(_filterButton, findsNothing);
    });

    testWidgets('author search shows from four authors on', (tester) async {
      await pump(tester);
      await _openModal(tester);
      final search = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Search authors',
      );
      expect(search, findsOneWidget);
      await tester.enterText(search, 'oss');
      await tester.pumpAndSettle();
      expect(_chip('oss'), findsOneWidget);
      expect(_chip('kanaru313'), findsNothing);
      expect(_chip('jp-fans'), findsNothing);
    });

    testWidgets('Clear all also clears the author search', (tester) async {
      await pump(tester);
      await _openModal(tester);
      final search = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Search authors',
      );
      await tester.enterText(search, 'oss');
      await tester.pumpAndSettle();
      expect(_chip('kanaru313'), findsNothing);
      await _tap(tester, _chip('Lyrics'));
      await _tap(tester, find.text('Clear all'));
      final field = find.descendant(
        of: search,
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(field).controller.text, '');
      expect(_chip('kanaru313'), findsOneWidget);
      expect(_chip('jp-fans'), findsOneWidget);
      expect(_chip('oss'), findsOneWidget);
      expectRows(all);
    });

    testWidgets('no author search below four authors', (tester) async {
      await pumpTwoKinds(tester, second: 'other');
      await _openModal(tester);
      expect(_chip('solo'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Search authors',
        ),
        findsNothing,
      );
    });
  });

  group('footer and empty state', () {
    testWidgets('shows the count, clears all, and Done keeps the picks', (
      tester,
    ) async {
      await pump(tester);
      await _openModal(tester);
      expect(find.text('Showing 5 plugins'), findsOneWidget);
      TextButton clearAll() =>
          tester.widget(find.widgetWithText(TextButton, 'Clear all'));
      expect(clearAll().onPressed, isNull);
      await _tap(tester, _chip('Lyrics'));
      expect(find.text('Showing 3 plugins'), findsOneWidget);
      expect(clearAll().onPressed, isNotNull);
      await _tap(tester, find.text('Clear all'));
      expect(find.text('Showing 5 plugins'), findsOneWidget);
      await _tap(tester, _chip('Lyrics'));
      await _tap(tester, find.text('Done'));
      expect(find.text('Filters'), findsNothing);
      expectRows(['Lyr VI', 'Lyr ZH', 'Lyr JA']);
      expect(_badge(tester), 1);
    });

    testWidgets('an empty list offers Clear filters', (tester) async {
      await pump(tester);
      await _openModal(tester);
      await _tap(tester, _chip('Translate'));
      await _tap(tester, _chip('kanaru313'));
      expect(find.text('Showing 0 plugins'), findsOneWidget);
      await _tap(tester, find.text('Done'));
      expect(find.text('No matching plugins.'), findsOneWidget);
      await _tap(tester, find.text('Clear filters'));
      expectRows(all);
      expect(find.text('Clear filters'), findsNothing);
    });
  });

  group('layout and locale', () {
    testWidgets('a narrow window opens the filters as a bottom sheet', (
      tester,
    ) async {
      await pump(tester, size: const Size(400, 800));
      await _openModal(tester);
      expect(find.byType(ContextModalSheetFrame), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
    });

    testWidgets('a wide window opens a dialog', (tester) async {
      await pump(tester);
      await _openModal(tester);
      expect(find.byType(ContextModalSheetFrame), findsNothing);
    });

    testWidgets('Vietnamese titles and the global language', (tester) async {
      await pump(tester, locale: const Locale('vi'));
      await tester.tap(find.byTooltip(vi.lyricsStoreFilterTooltip));
      await tester.pumpAndSettle();
      for (final title in ['Loại', 'Ngôn ngữ', 'Tác giả', 'Nguồn']) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.textContaining('Quốc tế'), findsOneWidget);
    });
  });
}
