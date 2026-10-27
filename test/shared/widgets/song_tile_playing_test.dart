import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_rows.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/playing_track_path.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/favorite_button.dart';
import 'package:kanaru/shared/widgets/song_card.dart';
import 'package:kanaru/shared/widgets/song_tile.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

const _coverKey =
    'ab/abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789.jpg';

const _a = TrackListItem(
  id: 1,
  path: '/music/a.flac',
  title: 'Song A',
  artist: 'Artist A',
  album: 'Album A',
  durationMs: 61000,
);
const _b = TrackListItem(
  id: 2,
  path: '/music/b.flac',
  title: 'Song B',
  artist: 'Artist B',
  album: 'Album B',
  durationMs: 61000,
);

Widget _host(List<Widget> rows) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Column(children: rows)),
);

Widget _bare(
  String? playingPath,
  List<Widget> rows, {
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: [
    playingTrackPathProvider.overrideWithValue(playingPath),
    ...overrides,
  ],
  child: _host(rows),
);

Finder _tile(TrackListItem song) =>
    find.ancestor(of: find.text(song.title), matching: find.byType(SongTile));

Finder _in(Finder tile, Finder what) =>
    find.descendant(of: tile, matching: what);

Finder _equalizer(Finder tile) =>
    _in(tile, find.byIcon(AppIcons.equalizerRounded));

/// The row's own Material: the first one under the tile.
Material _rowMaterial(WidgetTester tester, Finder tile) =>
    tester.widget<Material>(_in(tile, find.byType(Material)).first);

Color? _textColor(WidgetTester tester, Finder tile, String text) =>
    tester.widget<Text>(_in(tile, find.text(text))).style?.color;

void main() {
  testWidgets('a row that is not playing keeps its plain look', (tester) async {
    await tester.pumpWidget(
      _bare('/music/other.flac', [
        SongTile(song: _a, onTap: () {}),
        SongTile(song: _b, onTap: () {}),
      ]),
    );
    final scheme = Theme.of(tester.element(find.byType(Scaffold))).colorScheme;
    for (final song in [_a, _b]) {
      final tile = _tile(song);
      expect(_equalizer(tile), findsNothing);
      expect(_rowMaterial(tester, tile).color, songCardColor(scheme));
      expect(_textColor(tester, tile, song.title), scheme.onSurface);
    }
  });

  testWidgets('the playing row is filled and its texts follow', (tester) async {
    await tester.pumpWidget(
      _bare(_a.path, [
        SongTile(song: _a, onTap: () {}, number: '3'),
        SongTile(song: _b, onTap: () {}),
      ]),
    );
    final scheme = Theme.of(tester.element(find.byType(Scaffold))).colorScheme;
    final a = _tile(_a);
    expect(_rowMaterial(tester, a).color, scheme.primaryContainer);
    expect(_textColor(tester, a, 'Song A'), scheme.onPrimaryContainer);
    expect(_textColor(tester, a, 'Artist A'), scheme.onPrimaryContainer);
    expect(_textColor(tester, a, 'Album A'), scheme.onPrimaryContainer);
    expect(_textColor(tester, a, '1:01'), scheme.onPrimaryContainer);
    expect(_textColor(tester, a, '3'), scheme.onPrimaryContainer);

    // Without a cover the placeholder is the equalizer: no note under it.
    expect(_equalizer(a), findsOneWidget);
    expect(_in(a, find.byIcon(AppIcons.musicNoteOutlined)), findsNothing);
    final icon = tester.widget<Icon>(_equalizer(a));
    expect(icon.color, scheme.onPrimaryContainer);

    final b = _tile(_b);
    expect(_equalizer(b), findsNothing);
    expect(_rowMaterial(tester, b).color, songCardColor(scheme));
  });

  testWidgets('highlightPlaying false keeps the playing track plain', (
    tester,
  ) async {
    await tester.pumpWidget(
      _bare(_a.path, [
        SongTile(song: _a, onTap: () {}, highlightPlaying: false),
      ]),
    );
    final scheme = Theme.of(tester.element(find.byType(Scaffold))).colorScheme;
    final a = _tile(_a);
    expect(_equalizer(a), findsNothing);
    expect(_rowMaterial(tester, a).color, songCardColor(scheme));
  });

  testWidgets('a real cover gets a scrim and a white equalizer', (
    tester,
  ) async {
    const withCover = TrackListItem(
      id: 3,
      path: '/music/c.flac',
      title: 'Song C',
      coverKey: _coverKey,
    );
    await tester.pumpWidget(
      _bare(
        withCover.path,
        [SongTile(song: withCover, onTap: () {})],
        overrides: [
          coverCacheDirectoryProvider.overrideWithValue('/cache/covers/512'),
        ],
      ),
    );
    final scheme = Theme.of(tester.element(find.byType(Scaffold))).colorScheme;
    final tile = _tile(withCover);
    final scrims = tester
        .widgetList<ColoredBox>(_in(tile, find.byType(ColoredBox)))
        .where((c) => c.color.toARGB32() == _scrim(scheme).toARGB32());
    expect(scrims, hasLength(1));
    final icon = tester.widget<Icon>(_equalizer(tile));
    expect(icon.color, Colors.white);
    expect(_equalizer(tile), findsOneWidget);
  });

  testWidgets('playing and plain rows have the same height', (tester) async {
    await tester.pumpWidget(
      _bare(_a.path, [
        SongTile(song: _a, onTap: () {}),
        SongTile(song: _b, onTap: () {}),
      ]),
    );
    expect(tester.getSize(_tile(_a)), tester.getSize(_tile(_b)));
  });

  testWidgets('ink is painted by the row Material', (tester) async {
    await tester.pumpWidget(_bare(_a.path, [SongTile(song: _a, onTap: () {})]));
    final tile = _tile(_a);
    final inkWell = _in(tile, find.byType(InkWell)).first;
    final above = Material.of(tester.element(tile));
    final rowMaterial = tester.renderObject(
      _in(tile, find.byType(Material)).first,
    );
    final host = Material.of(tester.element(inkWell));
    expect(host, isNot(same(above)));
    // The ink host sits inside the row Material's render subtree.
    // The controller is a render object (a private render class).
    RenderObject? node = host as RenderObject;
    while (node != null && !identical(node, rowMaterial)) {
      node = node.parent;
    }
    expect(node, isNotNull);
  });

  testWidgets('the unliked heart follows the row fill, others keep theirs', (
    tester,
  ) async {
    await tester.pumpWidget(
      _bare(_a.path, [
        SongTile(song: _a, onTap: () {}),
        SongTile(song: _b, onTap: () {}),
      ]),
    );
    final scheme = Theme.of(tester.element(find.byType(Scaffold))).colorScheme;
    Color? heart(TrackListItem s) => tester
        .widget<Icon>(
          _in(_tile(s), find.byIcon(AppIcons.favoriteBorderRounded)),
        )
        .color;
    expect(heart(_a), scheme.onPrimaryContainer);
    expect(heart(_b), isNull);
  });

  group('with the real player', () {
    late ProviderContainer container;
    late FakeAudioBackend backend;

    PlayerService player() => container.read(playerServiceProvider.notifier);

    Future<void> pumpRow(WidgetTester tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      backend = FakeAudioBackend();
      container = ProviderContainer(
        overrides: [audioBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _host([SongTile(song: _a, onTap: () {})]),
        ),
      );
    }

    Color? fill(WidgetTester tester) => _rowMaterial(tester, _tile(_a)).color;

    Color primaryContainer(WidgetTester tester) =>
        Theme.of(tester.element(find.byType(Scaffold)))
            .colorScheme
            .primaryContainer;

    testWidgets('a flip keeps the row elements and states', (tester) async {
      await pumpRow(tester);
      expect(
        fill(tester),
        songCardColor(
          Theme.of(tester.element(find.byType(Scaffold))).colorScheme,
        ),
      );
      final inkWell = tester.element(
        _in(_tile(_a), find.byType(InkWell)).first,
      );
      final heart = tester.state(find.byType(FavoriteButton));

      await player().openTracks(const [
        Track(uri: '/music/a.flac', title: 'a'),
      ]);
      await tester.pumpAndSettle();

      expect(fill(tester), primaryContainer(tester));
      expect(
        tester.element(_in(_tile(_a), find.byType(InkWell)).first),
        same(inkWell),
      );
      expect(tester.state(find.byType(FavoriteButton)), same(heart));
    });

    testWidgets('a paused track keeps the highlight', (tester) async {
      await pumpRow(tester);
      await player().openTracks(const [
        Track(uri: '/music/a.flac', title: 'a'),
      ]);
      await tester.pumpAndSettle();
      expect(container.read(playerServiceProvider).playing, isTrue);

      await player().pause();
      await tester.pumpAndSettle();

      expect(container.read(playerServiceProvider).playing, isFalse);
      expect(fill(tester), primaryContainer(tester));
      expect(_equalizer(_tile(_a)), findsOneWidget);
    });

    testWidgets('a file uri matches the library path', (tester) async {
      await pumpRow(tester);
      await player().openTracks(const [
        Track(uri: 'file:///music/a.flac', title: 'a'),
      ]);
      await tester.pumpAndSettle();
      expect(fill(tester), primaryContainer(tester));
    });
  });
}

/// The scrim color the cover mark is drawn with.
Color _scrim(ColorScheme scheme) => scheme.scrim.withValues(alpha: 0.45);
