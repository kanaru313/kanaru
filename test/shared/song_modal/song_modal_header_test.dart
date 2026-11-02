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
}
