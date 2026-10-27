import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/widgets/library_row.dart';
import 'package:kanaru/shared/widgets/song_card.dart';
import 'package:kanaru/shared/widgets/song_row_view.dart';
import 'package:kanaru/shared/widgets/song_tile_cover.dart';
import 'package:material_ui/material_ui.dart';

/// Pumps [child] with no ProviderScope: the view reads no providers.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  Locale locale = const Locale('en'),
}) => tester.pumpWidget(
  MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
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
);

void main() {
  testWidgets('shows three lines, the duration and the heart slot', (
    tester,
  ) async {
    await _pump(
      tester,
      const SongRowView(
        title: 'Title',
        artist: 'Artist',
        detail: 'Album • 2000',
        duration: Duration(minutes: 1, seconds: 1),
        heart: SizedBox(key: Key('heart'), width: 28, height: 28),
      ),
    );

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Artist'), findsOneWidget);
    expect(find.text('Album • 2000'), findsOneWidget);
    expect(find.text('1:01'), findsOneWidget);
    final duration = tester.getRect(find.text('1:01'));
    final heart = tester.getRect(find.byKey(const Key('heart')));
    expect(heart.top, greaterThanOrEqualTo(duration.bottom));
  });

  testWidgets('the playing row has the container fill and its text colors', (
    tester,
  ) async {
    await _pump(
      tester,
      const SongRowView(title: 'Title', artist: 'Artist', playing: true),
    );
    final colors = Theme.of(tester.element(find.byType(SongRowView)))
        .colorScheme;

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(SongRowView),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, songCardColor(colors, playing: true));
    expect(material.color, colors.primaryContainer);
    expect(
      tester.widget<Text>(find.text('Title')).style!.color,
      colors.onPrimaryContainer,
    );
    expect(
      tester.widget<SongTileCover>(find.byType(SongTileCover)).playing,
      isTrue,
    );
  });

  testWidgets('the overlay is painted over the row and costs no room', (
    tester,
  ) async {
    await _pump(tester, const SongRowView(title: 'Title'));
    final plain = tester.getSize(find.byType(SongRowView));

    await _pump(
      tester,
      const SongRowView(
        title: 'Title',
        overlay: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(key: Key('mark'), width: 3, height: 40),
        ),
      ),
    );

    expect(tester.getSize(find.byType(SongRowView)), plain);
    expect(find.byKey(const Key('mark')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('mark'))).dx -
          tester.getTopLeft(find.byType(SongRowView)).dx,
      songCardInset,
    );
  });

  testWidgets('the semantics hint is read with the row', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      SongRowView(title: 'Title', semanticsHint: 'Play next', onTap: () {}),
    );

    expect(find.semantics.byHint('Play next'), findsOneWidget);
    final node = find.semantics.byHint('Play next').evaluate().single;
    expect(node.getSemanticsData().label, contains('Title'));
    handle.dispose();
  });

  testWidgets('a smaller horizontal padding moves the cover left', (
    tester,
  ) async {
    await _pump(tester, const SongRowView(title: 'Title'));
    final wide = tester.getTopLeft(find.byType(SongTileCover)).dx;
    await _pump(
      tester,
      const SongRowView(title: 'Title', horizontalPadding: 16),
    );

    expect(wide - tester.getTopLeft(find.byType(SongTileCover)).dx, 16);
  });

  for (final (name, title, scale, locale) in [
    ('1.0', 'Title', 1.0, const Locale('en')),
    ('1.25', 'Title', 1.25, const Locale('en')),
    ('1.5', 'Title', 1.5, const Locale('en')),
    ('2.0', 'Title', 2.0, const Locale('en')),
    ('CJK title', '漢字テスト', 1.0, const Locale('en')),
    ('CJK title at 1.25', '漢字テスト', 1.25, const Locale('en')),
    ('vi locale', 'Tiêu đề', 1.0, const Locale('vi')),
  ]) {
    testWidgets('height equals songCardExtent: $name', (tester) async {
      await _pump(
        tester,
        SongRowView(title: title, artist: 'Artist', detail: 'Album • 2000'),
        scale: scale,
        locale: locale,
      );
      final theme = Theme.of(tester.element(find.byType(SongRowView)));

      expect(
        tester.getSize(find.byType(SongRowView)).height,
        closeTo(songCardExtent(theme, TextScaler.linear(scale)), 0.01),
      );
      expect(
        tester.getSize(find.byType(LibraryRowLayout)).height,
        closeTo(libraryRowExtent(theme, TextScaler.linear(scale)), 0.01),
      );
    });
  }

  testWidgets('the extent is the 88 px card slot at the default scale', (
    tester,
  ) async {
    await _pump(tester, const SongRowView(title: 'Title'));
    final theme = Theme.of(tester.element(find.byType(SongRowView)));

    expect(libraryRowExtent(theme, TextScaler.noScaling), closeTo(80, 0.01));
    expect(songCardExtent(theme, TextScaler.noScaling), closeTo(88, 0.01));
  });

  testWidgets('the badge sits above the duration; no badge keeps the column', (
    tester,
  ) async {
    const duration = Duration(minutes: 1, seconds: 1);
    await _pump(
      tester,
      const SongRowView(
        title: 'Title',
        duration: duration,
        badge: Text('12 listens', key: Key('badge')),
      ),
    );
    expect(
      tester.getBottomLeft(find.byKey(const Key('badge'))).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.text('1:01')).dy),
    );

    await _pump(tester, const SongRowView(title: 'Title', duration: duration));
    final column = tester.widget<Column>(
      find.ancestor(of: find.text('1:01'), matching: find.byType(Column)).first,
    );
    expect(column.children, hasLength(1));
  });
}
