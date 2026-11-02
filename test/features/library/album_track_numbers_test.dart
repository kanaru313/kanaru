import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/library/albums/album_filtered_tracks.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/cover_art.dart';
import 'package:kanaru/shared/widgets/in_page_search_field.dart';
import 'package:kanaru/shared/widgets/song_tile.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/indexer/fake_tag_reader.dart';
import 'browse_test_data.dart';
import 'library_test_harness.dart';

const _covers = '/cache/covers/512';
final _red = fakeCoverKey('red');

final _location = albumLocation(const AlbumKey('ann', 'blue'));

/// The album page with one track numbered 7 and track numbers [numbers].
Future<LibraryHarness> _open(
  WidgetTester tester, {
  required bool numbers,
  String? coverKey,
}) async {
  final h = LibraryHarness(
    coverCacheDirectory: _covers,
    overrides: [
      initialSettingsProvider.overrideWithValue(
        AppSettings(display: DisplayPrefs(trackNumbersInAlbum: numbers)),
      ),
    ],
  );
  await openWithTracks(tester, h, [
    TestTrack(
      'Song',
      artist: 'Ann',
      album: 'Blue',
      track: 7,
      coverKey: coverKey,
    ),
  ], location: _location);
  return h;
}

Finder _inRow(Finder matching) =>
    find.descendant(of: find.byType(SongTile), matching: matching);

void main() {
  testWidgets('track numbers on show the number before the cover', (
    tester,
  ) async {
    await _open(tester, numbers: true, coverKey: _red);
    expect(_inRow(find.text('7')), findsOneWidget);
    expect(
      tester.getTopLeft(_inRow(find.text('7'))).dx,
      lessThan(tester.getTopLeft(_inRow(find.byType(CoverArt))).dx),
    );
  });

  testWidgets('track numbers off leave only the song cover', (tester) async {
    await _open(tester, numbers: false, coverKey: _red);
    expect(_inRow(find.text('7')), findsNothing);
    final cover = tester.widget<CoverArt>(_inRow(find.byType(CoverArt)));
    expect(cover.path, '$_covers/$_red');
  });

  testWidgets('a song without a cover shows the placeholder', (tester) async {
    await _open(tester, numbers: false);
    final cover = tester.widget<CoverArt>(_inRow(find.byType(CoverArt)));
    expect(cover.path, isNull);
  });

  testWidgets('changing the setting hides the number at once', (tester) async {
    final h = await _open(tester, numbers: true);
    h.container
        .read(settingsProvider.notifier)
        .setDisplay(const DisplayPrefs(trackNumbersInAlbum: false));
    await tester.pump();
    expect(_inRow(find.text('7')), findsNothing);
    expect(_inRow(find.byType(CoverArt)), findsOneWidget);
  });

  testWidgets('a filtered list keeps the track numbers', (tester) async {
    await _open(tester, numbers: true);
    await tester.tap(find.byTooltip('Filter in this page'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(InPageSearchBox),
        matching: find.byType(TextField),
      ),
      'song',
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(SliverAlbumFilteredTracks), findsOneWidget);
    expect(_inRow(find.text('7')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  });
}
