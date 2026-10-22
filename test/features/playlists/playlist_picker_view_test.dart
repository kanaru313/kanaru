import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_rows.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/add_to_playlist/playlist_picker_view.dart';
import 'package:material_ui/material_ui.dart';

PlaylistSummary playlist(int id, String name, int count) =>
    PlaylistSummary(id: id, name: name, createdAt: id, entryCount: count);

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<PlaylistSummary> playlists, {
    VoidCallback? onCreate,
    ValueChanged<PlaylistSummary>? onPick,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PlaylistPickerView(
          playlists: playlists,
          onCreate: onCreate ?? () {},
          onPick: onPick ?? (_) {},
        ),
      ),
    ),
  );

  testWidgets('lists the new row, then playlists in the given order', (
    tester,
  ) async {
    await pump(tester, [playlist(2, 'Gym', 3), playlist(1, 'Chill', 1)]);

    expect(find.text('New playlist…'), findsOneWidget);
    expect(find.text('3 songs'), findsOneWidget);
    expect(find.text('1 song'), findsOneWidget);
    expect(find.text('No playlists yet'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Gym')).dy,
      lessThan(tester.getTopLeft(find.text('Chill')).dy),
    );
    expect(
      tester.getTopLeft(find.text('New playlist…')).dy,
      lessThan(tester.getTopLeft(find.text('Gym')).dy),
    );
  });

  testWidgets('tapping a playlist or the new row calls back', (tester) async {
    final picked = <PlaylistSummary>[];
    var created = 0;
    final gym = playlist(2, 'Gym', 3);
    await pump(tester, [gym], onCreate: () => created++, onPick: picked.add);

    await tester.tap(find.text('Gym'));
    await tester.tap(find.text('New playlist…'));

    expect(picked, [gym]);
    expect(created, 1);
  });

  testWidgets('with no playlists only the new row and a hint show', (
    tester,
  ) async {
    await pump(tester, const []);

    expect(find.text('New playlist…'), findsOneWidget);
    expect(find.text('No playlists yet'), findsOneWidget);
    expect(find.byIcon(Icons.queue_music), findsNothing);
  });
}
