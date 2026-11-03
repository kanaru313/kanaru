import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_rows.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/song_modal/song_modal_header.dart';
import 'package:kanaru/shared/widgets/cover_art.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('the cover is 64 px, like the album and playlist modals', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SongModalHeader(
              song: TrackListItem(
                id: 1,
                path: '/m/a.flac',
                title: 'Song',
                artist: 'Ann',
                album: 'Al',
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(CoverArt)), const Size(64, 64));
    expect(find.text('Song'), findsOneWidget);
  });

  group('with onTap', () {
    Future<void> pumpTappable(WidgetTester tester, VoidCallback onTap) =>
        tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SongModalHeader(
                  song: const TrackListItem(
                    id: 1,
                    path: '/m/a.flac',
                    title: 'Song',
                  ),
                  onTap: onTap,
                ),
              ),
            ),
          ),
        );

    testWidgets('a tap calls onTap', (tester) async {
      var taps = 0;
      await pumpTappable(tester, () => taps++);
      await tester.tap(find.text('Song'));
      expect(taps, 1);
    });

    testWidgets('it is a button with the Song info hint', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpTappable(tester, () {});
      final node = tester.getSemantics(
        find.ancestor(of: find.text('Song'), matching: find.byType(InkWell)),
      );
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.hint, 'Song info');
      handle.dispose();
    });

    testWidgets('the ink can take keyboard focus', (tester) async {
      await pumpTappable(tester, () {});
      expect(
        tester.widget<InkWell>(find.byType(InkWell)).canRequestFocus,
        isTrue,
      );
    });
  });
}
