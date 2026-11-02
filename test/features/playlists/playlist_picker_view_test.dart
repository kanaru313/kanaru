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
    Set<int> ticked = const {},
    List<PendingPlaylist> pending = const [],
    Map<int, int> overlaps = const {},
    VoidCallback? onCreate,
    ValueChanged<PlaylistSummary>? onToggle,
    ValueChanged<int>? onTogglePending,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PlaylistPickerView(
          playlists: playlists,
          ticked: ticked,
          pending: pending,
          overlaps: overlaps,
          onCreate: onCreate ?? () {},
          onToggle: onToggle ?? (_) {},
          onTogglePending: onTogglePending ?? (_) {},
          onSubmit: () {},
        ),
      ),
    ),
  );

  testWidgets('lists the new row, pending rows, then playlists in order', (
    tester,
  ) async {
    await pump(
      tester,
      [playlist(2, 'Gym', 3), playlist(1, 'Chill', 1)],
      pending: [(name: 'Fresh', on: true)],
    );

    expect(find.text('3 songs'), findsOneWidget);
    expect(find.text('1 song'), findsOneWidget);
    expect(find.text('Created when you press Add'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('New playlist…'), lessThan(top('Fresh')));
    expect(top('Fresh'), lessThan(top('Gym')));
    expect(top('Gym'), lessThan(top('Chill')));
  });

  testWidgets('tapping rows calls back; ticks and overlaps are shown', (
    tester,
  ) async {
    final toggled = <PlaylistSummary>[];
    final pendingToggled = <int>[];
    var created = 0;
    final gym = playlist(2, 'Gym', 3);
    await pump(
      tester,
      [gym],
      ticked: {2},
      overlaps: {2: 2},
      pending: [(name: 'Fresh', on: false)],
      onCreate: () => created++,
      onToggle: toggled.add,
      onTogglePending: pendingToggled.add,
    );

    expect(find.text('3 songs · has 2 of them'), findsOneWidget);
    final boxes = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .map((t) => t.value);
    expect(boxes, [false, true]);
    await tester.tap(find.text('Gym'));
    await tester.tap(find.text('Fresh'));
    await tester.tap(find.text('New playlist…'));

    expect(toggled, [gym]);
    expect(pendingToggled, [0]);
    expect(created, 1);
  });

  testWidgets('with no playlists only the new row and a hint show', (
    tester,
  ) async {
    await pump(tester, const []);

    expect(find.text('New playlist…'), findsOneWidget);
    expect(find.text('No playlists yet'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
  });

  testWidgets(
    'rows are keyed; inserting pending preserves playlist checkbox state',
    (tester) async {
      final rock = playlist(42, 'Rock', 5);

      await pump(tester, [rock], ticked: const {});
      final rockFinder = find.byKey(const ValueKey(42));
      expect(rockFinder, findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.descendant(
                of: rockFinder,
                matching: find.byType(CheckboxListTile),
              ),
            )
            .value,
        isFalse,
      );

      await pump(
        tester,
        [rock],
        ticked: const {},
        pending: [(name: 'Chill', on: true)],
      );

      final pendingFinder = find.byKey(const ValueKey('pending-0'));
      expect(pendingFinder, findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.descendant(
                of: pendingFinder,
                matching: find.byType(CheckboxListTile),
              ),
            )
            .value,
        isTrue,
      );

      expect(rockFinder, findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.descendant(
                of: rockFinder,
                matching: find.byType(CheckboxListTile),
              ),
            )
            .value,
        isFalse,
      );
    },
  );
}

