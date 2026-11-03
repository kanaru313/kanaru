import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_rows.dart';
import 'package:kanaru/features/playlists/playlist_modal/playlist_description_box.dart';
import 'package:kanaru/features/playlists/playlist_modal/playlist_modal_header.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

final _created = DateTime(2024, 3, 5).millisecondsSinceEpoch;

PlaylistSummary _playlist({
  String name = 'Road trip',
  int count = 12,
  bool favorites = false,
  String description = '',
}) => PlaylistSummary(
  id: 4,
  name: name,
  createdAt: _created,
  entryCount: count,
  isFavorites: favorites,
  description: description,
);

Future<void> _pump(
  WidgetTester tester,
  PlaylistSummary playlist, {
  VoidCallback? onTap,
  bool showCoverButton = false,
  double width = 420,
}) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: PlaylistModalHeader(
              playlist: playlist,
              coverKeys: const [],
              onTap: onTap,
              showCoverButton: showCoverButton,
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'shows the name and "N songs • Created <date>" without a length',
    (tester) async {
      await _pump(tester, _playlist());
      expect(find.text('Road trip'), findsOneWidget);
      expect(find.text('12 songs • Created Mar 5, 2024'), findsOneWidget);
      expect(find.textContaining(' min'), findsNothing);
    },
  );

  testWidgets('one song reads "1 song"', (tester) async {
    await _pump(tester, _playlist(count: 1));
    expect(find.text('1 song • Created Mar 5, 2024'), findsOneWidget);
  });

  testWidgets('Favorites shows its localized name and no creation date', (
    tester,
  ) async {
    await _pump(tester, _playlist(name: 'stored', favorites: true, count: 3));
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('3 songs'), findsOneWidget);
    expect(find.textContaining('Created'), findsNothing);
  });

  testWidgets('no description box content when the description is empty', (
    tester,
  ) async {
    await _pump(tester, _playlist());
    expect(
      find.byKey(const ValueKey('playlist-description-text')),
      findsNothing,
    );
  });

  testWidgets('a long description is two lines tall and scrolls inside', (
    tester,
  ) async {
    final text = List.filled(30, 'Songs for the long drive north').join(' ');
    await _pump(tester, _playlist(description: text));
    final box = find.byType(PlaylistDescriptionBox);
    final style = Theme.of(tester.element(box)).textTheme.bodySmall!;
    final line = style.fontSize! * (style.height ?? 1.3);
    expect(tester.getSize(box).height, lessThanOrEqualTo(line * 2 + 0.5));
    expect(find.byType(Scrollbar), findsNothing);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: box, matching: find.byType(Scrollable)),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await tester.drag(box, const Offset(0, -40));
    await tester.pump();
    expect(scrollable.position.pixels, greaterThan(0));
  });

  testWidgets('a short description shows whole', (tester) async {
    await _pump(tester, _playlist(description: 'Short'));
    expect(find.text('Short'), findsOneWidget);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(PlaylistDescriptionBox),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, 0);
  });

  testWidgets(
    'Change playlist cover shows only when asked; it is coming soon',
    (tester) async {
      var taps = 0;
      await _pump(
        tester,
        _playlist(),
        onTap: () => taps++,
        showCoverButton: true,
      );
      await tester.tap(find.byTooltip('Change playlist cover'));
      await tester.pump();
      expect(taps, 0);
      expect(find.textContaining("isn't available yet"), findsOneWidget);
      expect(find.byTooltip('Edit'), findsNothing);
      await _pump(tester, _playlist());
      expect(find.byTooltip('Change playlist cover'), findsNothing);
    },
  );

  testWidgets('a tap on the description calls onTap; a drag does not', (
    tester,
  ) async {
    var taps = 0;
    final text = List.filled(30, 'Songs for the long drive north').join(' ');
    await _pump(tester, _playlist(description: text), onTap: () => taps++);
    final box = find.byType(PlaylistDescriptionBox);
    await tester.drag(box, const Offset(0, -40));
    await tester.pump();
    expect(taps, 0);
    await tester.tap(box);
    expect(taps, 1);
  });

  testWidgets('the header is a tap target only with onTap', (tester) async {
    var taps = 0;
    await _pump(tester, _playlist(), onTap: () => taps++);
    await tester.tap(find.text('Road trip'));
    expect(taps, 1);
    await _pump(tester, _playlist());
    expect(
      find.ancestor(of: find.text('Road trip'), matching: find.byType(InkWell)),
      findsNothing,
    );
  });
}
