import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/library/albums/album_track_tile.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/widgets/cover_art.dart';
import 'package:material_ui/material_ui.dart';

const _coverKey =
    'ab/abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789.jpg';

const _track = BrowseTrack(
  id: 1,
  path: '/music/a.flac',
  title: 'Song',
  trackNo: 7,
  coverKey: _coverKey,
);

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, {required bool numbers}) async {
    container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(
          AppSettings(display: DisplayPrefs(trackNumbersInAlbum: numbers)),
        ),
        coverCacheDirectoryProvider.overrideWithValue('/cache/covers/512'),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AlbumTrackTile(
              track: _track,
              albumArtist: null,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('track numbers on show the number', (tester) async {
    await pump(tester, numbers: true);
    expect(find.text('7'), findsOneWidget);
    expect(find.byType(CoverArt), findsNothing);
  });

  testWidgets('track numbers off show the song cover instead', (tester) async {
    await pump(tester, numbers: false);
    expect(find.text('7'), findsNothing);
    final cover = tester.widget<CoverArt>(find.byType(CoverArt));
    expect(cover.path, '/cache/covers/512/$_coverKey');
  });

  testWidgets('a song without a cover shows the placeholder', (tester) async {
    container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(
          const AppSettings(display: DisplayPrefs(trackNumbersInAlbum: false)),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: AlbumTrackTile(
              track: _track,
              albumArtist: null,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(tester.widget<CoverArt>(find.byType(CoverArt)).path, isNull);
  });

  testWidgets('changing the setting switches the leading at once', (
    tester,
  ) async {
    await pump(tester, numbers: true);
    container
        .read(settingsProvider.notifier)
        .setDisplay(const DisplayPrefs(trackNumbersInAlbum: false));
    await tester.pump();
    expect(find.text('7'), findsNothing);
    expect(find.byType(CoverArt), findsOneWidget);
  });
}
