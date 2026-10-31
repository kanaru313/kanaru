import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_rows.dart';
import 'package:kanaru/core/player/playing_track_path.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/song_modal/song_modal_data.dart';
import 'package:kanaru/shared/song_modal/song_modal_extras.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_route.dart';
import 'package:kanaru/shared/widgets/song_row_view.dart';
import 'package:kanaru/shared/widgets/song_tile.dart';
import 'package:material_ui/material_ui.dart';

import 'song_modal_test_support.dart';

const _song = TrackListItem(id: 1, path: '/m/1.flac', title: 'one');

class _Probe {
  int built = 0;
  int ran = 0;
  String? note;
  bool destructive = false;
}

Future<void> _pump(WidgetTester tester, _Probe probe) {
  // Tall enough for every row of the modal.
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    ProviderScope(
      overrides: [playingTrackPathProvider.overrideWithValue(null)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              SongTile(
                song: _song,
                onTap: () {},
                onQueueAction: (_) {},
                modalExtras: () {
                  probe.built++;
                  return SongModalExtras(
                    headerNote: probe.note,
                    actions: [
                      ContextModalAction(
                        id: 'extra',
                        icon: AppIcons.remove,
                        label: 'Extra action',
                        destructive: probe.destructive,
                        onTap: songModalCloseThen(() => probe.ran++),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _expectExtraFirst(WidgetTester tester) async {
  final extra = tester.getTopLeft(modalAction('extra')).dy;
  final artist = tester.getTopLeft(modalAction('artist')).dy;
  expect(extra, lessThan(artist));
}

void main() {
  testWidgets('builder runs once per open, not while the row builds', (
    tester,
  ) async {
    final probe = _Probe();
    await _pump(tester, probe);
    expect(probe.built, 0);
    // A hover and a new frame rebuild the row's widgets.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(SongTile)));
    await tester.pump();
    await _pump(tester, probe);
    await tester.pump();
    expect(probe.built, 0);

    await openSongModal(tester, find.byType(SongTile));
    expect(probe.built, 1);
    await _expectExtraFirst(tester);
  });

  testWidgets('the ⋮ button opens the modal with the extras', (tester) async {
    final probe = _Probe();
    await _pump(tester, probe);

    await tester.tap(find.byTooltip('More options'));
    await settleSongModal(tester);

    expect(probe.built, 1);
    await _expectExtraFirst(tester);
  });

  testWidgets('a long press opens the modal with the extras', (tester) async {
    final probe = _Probe();
    await _pump(tester, probe);

    await tester.longPress(find.byType(SongTile));
    await settleSongModal(tester);

    expect(probe.built, 1);
    await _expectExtraFirst(tester);
  });

  for (final shift in [false, true]) {
    testWidgets(
      '${shift ? 'Shift+F10' : 'the Menu key'} opens the modal with the extras',
      (tester) async {
        final probe = _Probe();
        await _pump(tester, probe);
        // The row's own ink well is the focusable under the key handler.
        final rowInk = find.descendant(
          of: find.byType(SongRowView),
          matching: find.byType(InkWell),
        );
        final inside = find.descendant(
          of: find
              .descendant(of: rowInk.first, matching: find.byType(Focus))
              .first,
          matching: find.byType(Semantics),
        );
        Focus.of(tester.element(inside.first)).requestFocus();
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, isNotNull);

        if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(
          shift ? LogicalKeyboardKey.f10 : LogicalKeyboardKey.contextMenu,
        );
        if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await settleSongModal(tester);

        expect(probe.built, 1);
        await _expectExtraFirst(tester);
      },
    );
  }

  testWidgets('tapping an extra closes the modal, then runs it', (
    tester,
  ) async {
    final probe = _Probe();
    await _pump(tester, probe);
    await openSongModal(tester, find.byType(SongTile));

    await tapModalAction(tester, 'Extra action');

    expect(probe.ran, 1);
    expect(find.text('Extra action'), findsNothing);
  });

  testWidgets('header note shows only when given', (tester) async {
    final probe = _Probe()..note = '12 listens';
    await _pump(tester, probe);
    await openSongModal(tester, find.byType(SongTile));
    expect(find.text('12 listens'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleSongModal(tester);
    probe.note = null;
    await openSongModal(tester, find.byType(SongTile));
    expect(find.text('12 listens'), findsNothing);
  });

  testWidgets('a destructive extra draws label and icon in the error color', (
    tester,
  ) async {
    final probe = _Probe()..destructive = true;
    await _pump(tester, probe);
    await openSongModal(tester, find.byType(SongTile));
    final error = Theme.of(tester.element(modalAction('extra')))
        .colorScheme
        .error;

    final label = tester.widget<Text>(
      find.descendant(
        of: modalAction('extra'),
        matching: find.text('Extra action'),
      ),
    );
    final icon = tester.widget<Icon>(
      find.descendant(
        of: modalAction('extra'),
        matching: find.byIcon(AppIcons.remove),
      ),
    );
    final labelColor =
        label.style?.color ??
        DefaultTextStyle.of(tester.element(find.text('Extra action')))
            .style
            .color;
    expect(labelColor, error);
    expect(icon.color, error);
  });
}
