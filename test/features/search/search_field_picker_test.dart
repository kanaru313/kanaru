import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/search_file_text_index.dart';
import 'package:kanaru/core/search/search_fields.dart';
import 'package:kanaru/core/search/search_prefs_provider.dart';
import 'package:kanaru/features/search/search_request_provider.dart';
import 'package:kanaru/shared/widgets/album_list_tile.dart';
import 'package:kanaru/shared/widgets/song_tile.dart';
import 'package:material_ui/material_ui.dart';

import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';
import 'search_test_data.dart';

/// Stored choice of fields, as if loaded from the prefs file.
class _StoredFields extends SearchPrefsNotifier {
  _StoredFields(this.fields);

  final Set<SearchField> fields;

  @override
  Future<SearchPrefs> build() async => SearchPrefs(fields: fields);
}

/// Prefs that never finish loading.
class _NeverLoaded extends SearchPrefsNotifier {
  @override
  Future<SearchPrefs> build() => Completer<SearchPrefs>().future;
}

Set<SearchField> _fields(LibraryHarness h) =>
    h.container.read(searchPrefsProvider).value!.fields;

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(MenuAnchor));
  await tester.pumpAndSettle();
}

CheckboxMenuButton _checkbox(WidgetTester tester, String label) => tester
    .widget<CheckboxMenuButton>(find.widgetWithText(CheckboxMenuButton, label));

void main() {
  testWidgets('the button shows before anything is typed', (tester) async {
    final h = LibraryHarness();
    await openSearch(tester, h, '');

    expect(find.text('Search your library'), findsOneWidget);
    expect(find.text('Search fields'), findsOneWidget);
    expect(find.text('Search fields (filtered)'), findsNothing);
  });

  testWidgets('the menu lists two presets and seven fields', (tester) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'son');
    await _openMenu(tester);

    expect(find.byType(RadioMenuButton<SearchFieldPreset>), findsNWidgets(2));
    expect(find.byType(CheckboxMenuButton), findsNWidgets(7));
    final all = tester.widget<RadioMenuButton<SearchFieldPreset>>(
      find.widgetWithText(RadioMenuButton<SearchFieldPreset>, 'All fields'),
    );
    expect(all.groupValue, SearchFieldPreset.all);
    expect(_checkbox(tester, 'Title').value, isTrue);
    expect(_checkbox(tester, 'File name').value, isFalse);
    expect(_checkbox(tester, 'Description').value, isFalse);
  });

  testWidgets('titles only narrows the results, marks the button and says '
      'to turn on more fields when nothing matches', (tester) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'tung');
    expect(find.byType(SongTile), findsNWidgets(2));

    await _openMenu(tester);
    await tester.tap(find.text('Titles only'));
    await tester.pumpAndSettle();

    expect(_fields(h), {SearchField.title});
    expect(find.byType(SongTile), findsNothing);
    expect(find.text('No results'), findsOneWidget);
    expect(
      find.textContaining('Try turning on more search fields'),
      findsOneWidget,
    );
    expect(find.text('Search fields (filtered)'), findsOneWidget);
  });

  testWidgets('filters ignore the picker, so no hint to turn on fields', (
    tester,
  ) async {
    final h = LibraryHarness(
      overrides: [
        searchPrefsProvider.overrideWith(
          () => _StoredFields({SearchField.title}),
        ),
      ],
    );
    await openSearch(tester, h, 'year:1900');

    expect(find.text('No results'), findsOneWidget);
    expect(find.textContaining('Try turning on more'), findsNothing);
  });

  testWidgets('a narrow choice shows the compact picker as an icon', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'son');
    tester.view.physicalSize = const Size(500, 800);
    await tester.pumpAndSettle();

    expect(find.byType(IconButton), findsWidgets);
    expect(find.text('Search fields'), findsNothing);
    expect(find.byTooltip('Search fields'), findsOneWidget);
  });

  testWidgets('while the saved choice loads, all fields are searched', (
    tester,
  ) async {
    final h = LibraryHarness(
      overrides: [searchPrefsProvider.overrideWith(_NeverLoaded.new)],
    );
    await openSearch(tester, h, 'tung');

    expect(h.container.read(searchPrefsProvider).isLoading, isTrue);
    expect(h.container.read(searchFieldsProvider), defaultSearchFields);
    expect(find.byType(SongTile), findsNWidgets(2));
    expect(find.text('Search fields'), findsOneWidget);
  });

  test('the choice survives a restart', () async {
    final dir = Directory.systemTemp.createTempSync('kanaru-search-prefs');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/search_prefs.json';
    ProviderContainer open() => ProviderContainer(
      overrides: [
        searchPrefsFileProvider.overrideWithValue(SearchPrefsFile(path)),
      ],
    );

    final first = open();
    await first.read(searchPrefsProvider.future);
    await first.read(searchPrefsProvider.notifier).setFields({
      SearchField.title,
    });
    first.dispose();

    final second = open();
    addTearDown(second.dispose);
    await second.read(searchPrefsProvider.future);
    expect(second.read(searchFieldsProvider), {SearchField.title});
  });

  testWidgets('turning a field on and off changes the results', (tester) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'sky');
    expect(find.byType(AlbumListTile), findsOneWidget);

    await _openMenu(tester);
    await tester.tap(find.text('Album').last);
    await tester.pumpAndSettle();
    // The menu stays open for more changes; "Album artist" is still on.
    expect(find.byType(CheckboxMenuButton), findsNWidgets(7));
    expect(_fields(h), isNot(contains(SearchField.album)));
    expect(find.byType(SongTile), findsNothing);
    expect(find.byType(AlbumListTile), findsOneWidget);

    await tester.tap(find.text('Album artist'));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumListTile), findsNothing);
    expect(find.text('No results'), findsOneWidget);

    await tester.tap(find.text('Album').last);
    await tester.pumpAndSettle();
    expect(_fields(h), contains(SearchField.album));
    expect(find.byType(SongTile), findsNWidgets(2));
    expect(find.byType(AlbumListTile), findsOneWidget);
  });

  testWidgets('the last field cannot be turned off', (tester) async {
    final h = LibraryHarness(
      overrides: [
        searchPrefsProvider.overrideWith(
          () => _StoredFields({SearchField.title}),
        ),
      ],
    );
    await openSearch(tester, h, 'lac');
    await _openMenu(tester);

    expect(_checkbox(tester, 'Title').onChanged, isNull);
    expect(_checkbox(tester, 'Artist').onChanged, isNotNull);
    await tester.tap(find.text('Title').last);
    await tester.pumpAndSettle();
    expect(_fields(h), {SearchField.title});
  });

  testWidgets('a stored choice applies when the page opens', (tester) async {
    final h = LibraryHarness(
      overrides: [
        searchPrefsProvider.overrideWith(
          () => _StoredFields({SearchField.artist}),
        ),
      ],
    );
    await openSearch(tester, h, 'tung');

    expect(find.byType(SongTile), findsNWidgets(2));
    expect(find.text('Search fields (filtered)'), findsOneWidget);
    // Album artist is off, so albums are not searched; the artist group is.
    expect(find.byType(AlbumListTile), findsNothing);
    expect(find.text('Artists  1', findRichText: true), findsOneWidget);
  });

  testWidgets('file name field finds songs by their file name', (tester) async {
    final h = LibraryHarness(
      overrides: [
        searchPrefsProvider.overrideWith(
          () => _StoredFields({SearchField.title, SearchField.fileName}),
        ),
        searchFileTextIndexProvider.overrideWith(
          (ref) => Stream.value(
            SearchFileTextIndex.buildNow([
              (id: 1, path: '/m/1/zebra crossing.flac', comment: null),
            ]),
          ),
        ),
      ],
    );
    await openSearch(
      tester,
      h,
      'zebra',
      tracks: const [
        TestTrack('Plain Title', path: '/m/1/zebra crossing.flac'),
      ],
    );

    expect(find.text('Plain Title'), findsOneWidget);
  });
}
