import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_rows.dart';
import 'package:kanaru/core/player/playing_track_path.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/widgets/library_row.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:kanaru/shared/widgets/song_card.dart';
import 'package:kanaru/shared/widgets/song_tile.dart';
import 'package:kanaru/shared/widgets/song_tile_cover.dart';
import 'package:material_ui/material_ui.dart';

const _song = TrackListItem(
  id: 1,
  path: '/music/a.flac',
  title: 'Song A',
  artist: 'Artist A',
  album: 'Album A',
  durationMs: 61000,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  String? playingPath,
  double scale = 1,
  Brightness brightness = Brightness.light,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [playingTrackPathProvider.overrideWithValue(playingPath)],
    child: MaterialApp(
      theme: ThemeData(brightness: brightness, platform: TargetPlatform.linux),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: app!,
      ),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  ),
);

Material _card(WidgetTester tester) => tester.widget<Material>(
  find
      .descendant(of: find.byType(SongTile), matching: find.byType(Material))
      .first,
);

void main() {
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('the slot of a row is songCardExtent tall at scale $scale', (
      tester,
    ) async {
      await _pump(
        tester,
        SongTile(song: _song, onTap: () {}),
        scale: scale,
      );
      final theme = Theme.of(tester.element(find.byType(SongTile)));

      expect(
        tester.getSize(find.byType(SongTile)).height,
        closeTo(songCardExtent(theme, TextScaler.linear(scale)), 0.01),
      );
      final card = tester.getRect(
        find
            .descendant(
              of: find.byType(SongTile),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(
        card.height,
        closeTo(libraryRowExtent(theme, TextScaler.linear(scale)), 0.01),
      );
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('card colour: plain and playing, ${brightness.name}', (
      tester,
    ) async {
      await _pump(
        tester,
        SongTile(song: _song, onTap: () {}),
        brightness: brightness,
      );
      final colors = Theme.of(tester.element(find.byType(SongTile)))
          .colorScheme;
      expect(_card(tester).color, songCardColor(colors));
      expect(_card(tester).color, isNot(colors.primaryContainer));

      await _pump(
        tester,
        SongTile(song: _song, onTap: () {}),
        playingPath: _song.path,
        brightness: brightness,
      );
      expect(_card(tester).color, songCardColor(colors, playing: true));
      expect(_card(tester).color, colors.primaryContainer);
    });
  }

  testWidgets('the card is rounded and its ink follows the shape', (
    tester,
  ) async {
    await _pump(tester, SongTile(song: _song, onTap: () {}));

    expect(_card(tester).shape, songCardShape);
    expect(
      tester
          .widget<InkWell>(
            find
                .descendant(
                  of: find.byType(SongTile),
                  matching: find.byType(InkWell),
                )
                .first,
          )
          .customBorder,
      songCardShape,
    );
  });

  testWidgets('the card sits 16 px from the edge, the cover at 32', (
    tester,
  ) async {
    await _pump(tester, SongTile(song: _song, onTap: () {}));
    final card = find
        .descendant(of: find.byType(SongTile), matching: find.byType(Material))
        .first;

    expect(tester.getTopLeft(card).dx, songCardInset);
    expect(tester.getTopLeft(card).dy, songCardGap / 2);
    expect(tester.getTopLeft(find.byType(SongTileCover)).dx, 32);
  });

  testWidgets('the gap belongs to its row: menu opens, tap does nothing', (
    tester,
  ) async {
    var taps = 0;
    final actions = <QueueAction>[];
    await _pump(
      tester,
      SizedBox(
        width: 600,
        child: SongTile(
          song: _song,
          onTap: () => taps++,
          onQueueAction: actions.add,
        ),
      ),
    );
    final slot = tester.getRect(find.byType(SongTile));
    // Inside the slot, below the card (the lower half of the gap).
    final inGap = Offset(slot.center.dx, slot.bottom - 1);

    await tester.tapAt(inGap);
    await tester.pump();
    expect(taps, 0);

    await tester.tapAt(inGap, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Play next'), findsOneWidget);
    await tester.tap(find.text('Play next'));
    await tester.pumpAndSettle();
    expect(actions, [QueueAction.playNext]);
  });
}
