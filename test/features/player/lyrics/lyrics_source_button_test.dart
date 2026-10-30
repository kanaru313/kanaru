import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' hide Track;
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics/online/lrc_sidecar_writer.dart';
import 'package:kanaru/core/lyrics/online/lyrics_choice.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_source_names.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_actions.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_resolution_provider.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/core/lyrics/playing_local_lyrics_provider.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/lyrics/source/lyrics_source_button.dart';
import 'package:kanaru/features/player/now_playing/now_playing_header_pill.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/online/fake_lyrics_provider.dart';
import '../../../core/player/fake_audio_backend.dart';
import 'fake_playing_lyrics_resolution.dart';

const _uri = '/m/song.flac';
const _song = Track(
  uri: _uri,
  title: 'Song',
  artist: 'Artist',
  duration: Duration(seconds: 200),
);
const _other = Track(
  uri: '/m/other.flac',
  title: 'Other',
  artist: 'Artist',
  duration: Duration(seconds: 200),
);

Lyrics _lyrics({
  bool synced = true,
  LyricsSource source = LyricsSource.sidecar,
}) => Lyrics(
  lines: const [LyricLine(Duration.zero, 'words')],
  synced: synced,
  source: source,
);

OnlineLyricsOrigin _origin({required bool pinned, String remoteId = '1'}) =>
    OnlineLyricsOrigin(providerId: 'fake', remoteId: remoteId, pinned: pinned);

/// Records what the menu asks the actions to do instead of doing it.
class _RecordingActions extends OnlineLyricsActions {
  _RecordingActions(super.ref, this.log);

  final List<String> log;

  @override
  Future<void> choose(LyricsTarget target, LyricsChoice choice) async =>
      log.add('choose ${choice.name} ${target.trackKey}');

  @override
  Future<void> keep(LyricsTarget target, OnlineLyricsOrigin origin) async =>
      log.add('keep ${origin.remoteId} ${target.trackKey}');

  @override
  Future<void> reject(
    LyricsTarget target,
    OnlineLyricsOrigin origin,
    Lyrics shown,
  ) async => log.add('reject ${origin.remoteId} ${target.trackKey}');

  @override
  Future<void> retry(LyricsTarget target) async =>
      log.add('retry ${target.trackKey}');

  @override
  Future<LyricsSaveOutcome> save(
    LyricsTarget target,
    OnlineLyricsOrigin origin, {
    bool replace = false,
  }) async {
    log.add('save ${origin.remoteId} ${target.trackKey}');
    return (result: LrcWriteResult.written, kept: null);
  }
}

/// A mockup state: the resolution and the menu it must show, top to bottom.
/// `✓` marks the checked row, `(off)` a disabled one.
typedef _State = ({
  String name,
  LyricsSourceResolution Function() resolution,
  String label,
  List<String> menu,
});

void main() {
  late FakePlayingLyricsResolution resolution;
  late ProviderContainer container;
  late List<String> log;
  late ValueNotifier<bool Function()?> opener;
  late List<bool> menuEvents;

  final findPill = find.byType(NowPlayingHeaderPill);
  Finder item(String title) => find.widgetWithText(MenuItemButton, title);

  /// The rows of the open menu: title, with `✓ ` when checked and ` (off)`
  /// when disabled.
  List<String> menuRows(WidgetTester tester) => [
    for (final button in tester.widgetList<MenuItemButton>(
      find.byType(MenuItemButton),
    ))
      () {
        final row = find.byWidget(button);
        final title = tester
            .widget<Text>(
              find.descendant(of: row, matching: find.byType(Text)).first,
            )
            .data!;
        // Choice rows are radio rows; the selected one is the choice in effect.
        final radio = find.ancestor(
          of: row,
          matching: find.byType(RadioMenuButton<bool>),
        );
        final checked =
            radio.evaluate().isNotEmpty &&
            tester.widget<RadioMenuButton<bool>>(radio).groupValue == true;
        return '${checked ? '✓ ' : ''}$title'
            '${button.onPressed == null ? ' (off)' : ''}';
      }(),
  ];

  Future<void> pump(
    WidgetTester tester,
    LyricsSourceResolution? initial, {
    Track track = _song,
    bool library = true,
    double? room = 240,
    Lyrics? ownLyrics,
    String? ownUri,
    Locale locale = const Locale('en'),
    double textScale = 1,
    Size size = const Size(900, 700),
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    log = [];
    menuEvents = [];
    opener = ValueNotifier<bool Function()?>(null);
    resolution = FakePlayingLyricsResolution(initial);
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        playingLyricsResolutionProvider.overrideWith(() => resolution),
        playingLocalLyricsProvider.overrideWith(
          (ref) async => ownLyrics == null
              ? null
              : (uri: ownUri ?? track.uri, lyrics: ownLyrics),
        ),
        lyricsProvidersProvider.overrideWithValue([
          LyricsProviderRegistration(FakeLyricsProvider()),
        ]),
        libraryDatabaseProvider.overrideWithValue(library ? db : null),
        onlineLyricsActionsProvider.overrideWith(
          (ref) => _RecordingActions(ref, log),
        ),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    // The real resolution keeps the song's own lyrics alive; here nothing
    // else watches them.
    final keepOwnLyrics = container.listen(
      playingLocalLyricsProvider,
      (_, _) {},
    );
    addTearDown(keepOwnLyrics.close);
    await container.read(playingLocalLyricsProvider.future);
    await container.read(playerServiceProvider.notifier).openTracks([track]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: LyricsSourceButton(
                maxLabelWidth: room,
                menuOpener: opener,
                onMenuChanged: menuEvents.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byType(LyricsSourceButton));
    await tester.pumpAndSettle();
  }

  LyricsSourceResolution found(
    Lyrics lyrics, {
    OnlineLyricsOrigin? origin,
    LyricsChoice chosen = LyricsChoice.auto,
    LyricsChoice effective = LyricsChoice.auto,
    bool hasLocal = false,
    bool pick = false,
  }) => fakeResolution(
    LyricsFound(_uri, lyrics, origin: origin),
    chosen: chosen,
    effective: effective,
    hasLocal: hasLocal,
    pin: pick ? fakePin(lyrics: _lyrics()) : null,
  );

  final states = <_State>[
    (
      name: 'automatic, the song\'s .lrc',
      resolution: () => found(_lyrics(), hasLocal: true),
      label: 'Auto · .lrc file',
      menu: [
        '✓ Automatic',
        'Lyrics in the file',
        'Find lyrics online…',
        'Save lyrics… (off)',
        'Turn lyrics off for this song',
      ],
    ),
    (
      name: 'the chosen online version over the .lrc',
      resolution: () => found(
        _lyrics(),
        origin: _origin(pinned: true, remoteId: '7'),
        chosen: LyricsChoice.online,
        effective: LyricsChoice.online,
        hasLocal: true,
        pick: true,
      ),
      label: 'Fake · Synced',
      menu: [
        'Automatic',
        'Lyrics in the file',
        '✓ Fake · chosen version',
        'Not these lyrics',
        'Find lyrics online…',
        'Save lyrics…',
        'Turn lyrics off for this song',
      ],
    ),
    (
      name: 'the file chosen, the online pick kept',
      resolution: () => found(
        _lyrics(),
        chosen: LyricsChoice.local,
        effective: LyricsChoice.local,
        hasLocal: true,
        pick: true,
      ),
      label: '.lrc file',
      menu: [
        'Automatic',
        '✓ Lyrics in the file',
        'Fake · chosen version',
        'Find lyrics online…',
        'Save lyrics… (off)',
        'Turn lyrics off for this song',
      ],
    ),
    (
      name: 'the file chosen but gone',
      resolution: () => found(
        _lyrics(),
        origin: _origin(pinned: false),
        chosen: LyricsChoice.local,
        pick: true,
      ),
      label: 'Auto · Fake',
      menu: [
        '✓ Automatic',
        'Lyrics in the file (off)',
        'Fake · chosen version',
        'Not these lyrics',
        'Find lyrics online…',
        'Save lyrics…',
        'Turn lyrics off for this song',
      ],
    ),
    (
      name: 'automatic, found online',
      resolution: () => found(_lyrics(), origin: _origin(pinned: false)),
      label: 'Auto · Fake',
      menu: [
        '✓ Automatic',
        'Keep this one',
        'Not these lyrics',
        'Find lyrics online…',
        'Save lyrics…',
        'Turn lyrics off for this song',
      ],
    ),
    (
      name: 'searching',
      resolution: () => fakeResolution(const LyricsSearching(_uri, 'fake')),
      label: 'Searching…',
      menu: [
        '✓ Automatic',
        'Find lyrics online…',
        'Save lyrics… (off)',
        'Turn lyrics off for this song',
      ],
    ),
    (
      name: 'no lyrics',
      resolution: () =>
          fakeResolution(const LyricsNone(_uri, LyricsNoneReason.noLyrics)),
      label: 'No lyrics',
      menu: [
        '✓ Automatic',
        'Find lyrics online…',
        'Save lyrics… (off)',
        'Turn lyrics off for this song',
      ],
    ),
    (
      name: 'lyrics off',
      resolution: () => fakeResolution(
        const LyricsNone(_uri, LyricsNoneReason.off),
        chosen: LyricsChoice.off,
        effective: LyricsChoice.off,
        hasLocal: true,
      ),
      label: 'Lyrics off',
      menu: [
        'Automatic',
        'Lyrics in the file',
        'Find lyrics online…',
        'Save lyrics… (off)',
        '✓ Turn lyrics off for this song',
      ],
    ),
  ];

  group('every state', () {
    for (final state in states) {
      testWidgets(state.name, (tester) async {
        await pump(tester, state.resolution(), ownLyrics: _lyrics());
        expect(find.text(state.label), findsOneWidget);
        await openMenu(tester);
        expect(find.text('Automatic'), findsOneWidget);
        expect(menuRows(tester), state.menu);
      });
    }
  });

  group('the pill', () {
    testWidgets('is quiet while nothing is found, primary once found', (
      tester,
    ) async {
      await pump(tester, fakeResolution(const LyricsSearching(_uri, 'fake')));
      Color? iconColor() => tester
          .widget<Icon>(
            find.descendant(of: findPill, matching: find.byType(Icon)),
          )
          .color;
      expect(iconColor(), isNull);
      resolution.emit(found(_lyrics(), origin: _origin(pinned: false)));
      await tester.pump();
      expect(
        iconColor(),
        Theme.of(tester.element(findPill)).colorScheme.primary,
      );
    });

    for (final room in [null, 63.0]) {
      testWidgets('is the round icon with the label as tooltip at room $room', (
        tester,
      ) async {
        await pump(tester, found(_lyrics(), hasLocal: true), room: room);
        expect(findPill, findsNothing);
        expect(find.text('Auto · .lrc file'), findsNothing);
        expect(find.byTooltip('Lyrics from .lrc file'), findsOneWidget);
        expect(find.byType(IconButton), findsOneWidget);
      });
    }

    testWidgets('grows a label from 64 px of room', (tester) async {
      await pump(tester, found(_lyrics(), hasLocal: true), room: 64);
      expect(findPill, findsOneWidget);
    });

    testWidgets('without lyrics the menu keeps the plain header', (
      tester,
    ) async {
      await pump(
        tester,
        fakeResolution(const LyricsNone(_uri, LyricsNoneReason.noLyrics)),
      );
      await openMenu(tester);
      expect(find.text('Lyrics for this song'), findsOneWidget);
      expect(find.textContaining('Lyrics from'), findsNothing);
    });

    testWidgets('with lyrics the menu header names the source', (tester) async {
      await pump(tester, found(_lyrics(), hasLocal: true));
      await openMenu(tester);
      expect(find.text('Lyrics from .lrc file'), findsOneWidget);
      expect(find.text('Lyrics for this song'), findsNothing);
    });

    testWidgets('names a known source that is not enabled', (tester) async {
      await pump(
        tester,
        found(
          _lyrics(),
          origin: OnlineLyricsOrigin(
            providerId: 'disabled',
            remoteId: '1',
            pinned: true,
          ),
          chosen: LyricsChoice.online,
          effective: LyricsChoice.online,
          pick: true,
        ),
        overrides: [
          lyricsSourceNamesProvider.overrideWithValue({
            'fake': const LyricsSourceName(displayName: 'Fake'),
            'disabled': const LyricsSourceName(displayName: 'Off source'),
          }),
        ],
      );
      expect(find.text('Off source · Synced'), findsOneWidget);
    });

    testWidgets('speaks Vietnamese', (tester) async {
      await pump(
        tester,
        found(
          _lyrics(),
          origin: _origin(pinned: true),
          effective: LyricsChoice.online,
          hasLocal: true,
        ),
        locale: const Locale('vi'),
        ownLyrics: _lyrics(),
      );
      expect(find.text('Fake · Đồng bộ'), findsOneWidget);
      await openMenu(tester);
      expect(find.text('Lời từ Fake · Đồng bộ'), findsOneWidget);
      expect(find.text('Tắt lời cho bài này'), findsOneWidget);
      expect(find.text('Lưu lời…'), findsOneWidget);
    });

    testWidgets('ellipsizes at text scale 2 without overflow', (tester) async {
      await pump(
        tester,
        found(_lyrics(), origin: _origin(pinned: true)),
        textScale: 2,
        room: 100,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(findPill).width, lessThan(260));
    });

    testWidgets('shows nothing while nothing plays', (tester) async {
      await pump(tester, null);
      expect(findPill, findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(opener.value, isNull);
    });
  });

  group('the menu rows', () {
    testWidgets('subtitles name what each choice is', (tester) async {
      await pump(
        tester,
        found(
          _lyrics(),
          origin: _origin(pinned: true, remoteId: '7'),
          chosen: LyricsChoice.online,
          effective: LyricsChoice.online,
          hasLocal: true,
          pick: true,
        ),
        ownLyrics: _lyrics(source: LyricsSource.embedded),
      );
      await openMenu(tester);
      expect(
        find.text(
          'The file or tag first, then Fake · drops the chosen version',
        ),
        findsOneWidget,
      );
      expect(find.text('In the tag'), findsOneWidget);
      expect(find.text('Synced · 4:05'), findsOneWidget);
    });

    testWidgets('automatic names the lyrics in use', (tester) async {
      await pump(tester, found(_lyrics(), origin: _origin(pinned: false)));
      await openMenu(tester);
      expect(find.text('In use: Fake · Synced'), findsOneWidget);
    });

    testWidgets('a missing file says so', (tester) async {
      await pump(
        tester,
        found(
          _lyrics(),
          origin: _origin(pinned: false),
          chosen: LyricsChoice.local,
        ),
      );
      await openMenu(tester);
      expect(find.text('No lyrics found in the file'), findsOneWidget);
    });

    for (final (name, library, track) in [
      ('without a library', false, _song),
      (
        'for a song that is not a file',
        true,
        const Track(uri: 'http://x/y.mp3', title: 'Stream'),
      ),
    ]) {
      testWidgets('choices are disabled and Find online is gone $name', (
        tester,
      ) async {
        await pump(
          tester,
          fakeResolution(
            LyricsFound(track.uri, _lyrics(), origin: _origin(pinned: false)),
            hasLocal: true,
          ),
          library: library,
          track: track,
        );
        await openMenu(tester);
        expect(menuRows(tester), [
          '✓ Automatic (off)',
          'Lyrics in the file (off)',
          'Keep this one (off)',
          'Not these lyrics (off)',
          'Save lyrics… (off)',
          'Turn lyrics off for this song (off)',
        ]);
      });
    }
  });

  group('each row', () {
    for (final (title, expected) in [
      ('Automatic', 'choose auto $_uri'),
      ('Lyrics in the file', 'choose local $_uri'),
      ('Fake · chosen version', 'choose online $_uri'),
      ('Turn lyrics off for this song', 'choose off $_uri'),
      ('Not these lyrics', 'reject 7 $_uri'),
    ]) {
      testWidgets('$title acts on the song', (tester) async {
        await pump(
          tester,
          found(
            _lyrics(),
            origin: _origin(pinned: true, remoteId: '7'),
            chosen: LyricsChoice.online,
            effective: LyricsChoice.online,
            hasLocal: true,
            pick: true,
          ),
          ownLyrics: _lyrics(),
        );
        await openMenu(tester);
        await tester.tap(item(title));
        await tester.pumpAndSettle();
        expect(log, [expected]);
        expect(find.text('Automatic'), findsNothing);
      });
    }

    testWidgets('Keep this one keeps the automatic match', (tester) async {
      await pump(tester, found(_lyrics(), origin: _origin(pinned: false)));
      await openMenu(tester);
      await tester.tap(item('Keep this one'));
      await tester.pumpAndSettle();
      expect(log, ['keep 1 $_uri']);
    });

    testWidgets('Find lyrics online asks for consent first', (tester) async {
      await pump(tester, found(_lyrics(), origin: _origin(pinned: false)));
      await openMenu(tester);
      await tester.tap(item('Find lyrics online…'));
      await tester.pumpAndSettle();
      expect(find.text('Search lyrics on Fake?'), findsOneWidget);
    });

    testWidgets('Save lyrics saves the record on screen', (tester) async {
      await pump(tester, found(_lyrics(), origin: _origin(pinned: false)));
      await openMenu(tester);
      await tester.tap(item('Save lyrics…'));
      await tester.pumpAndSettle();
      expect(find.text('Save lyrics'), findsOneWidget);
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(log, ['save 1 $_uri']);
    });
  });

  group('the snapshot', () {
    testWidgets('a track change closes the open menu', (tester) async {
      await pump(tester, found(_lyrics(), origin: _origin(pinned: false)));
      await openMenu(tester);
      expect(find.text('Automatic'), findsOneWidget);

      await container.read(playerServiceProvider.notifier).openTracks([_other]);
      resolution.emit(
        fakeResolution(
          LyricsFound(
            '/m/other.flac',
            _lyrics(),
            origin: _origin(pinned: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Automatic'), findsNothing);
      expect(menuEvents, [true, false]);
    });

    testWidgets(
      'a dialog open across a track change still saves the old song',
      (tester) async {
        await pump(tester, found(_lyrics(), origin: _origin(pinned: false)));
        await openMenu(tester);
        await tester.tap(item('Save lyrics…'));
        await tester.pumpAndSettle();
        expect(find.text('Save lyrics'), findsOneWidget);

        await container.read(playerServiceProvider.notifier).openTracks([
          _other,
        ]);
        resolution.emit(
          fakeResolution(
            LyricsFound(
              '/m/other.flac',
              _lyrics(),
              origin: _origin(pinned: false, remoteId: '9'),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Save').last);
        await tester.pumpAndSettle();

        expect(log, ['save 1 $_uri']);
      },
    );

    testWidgets('the menu keeps its rows when the source changes under it', (
      tester,
    ) async {
      await pump(tester, found(_lyrics(), origin: _origin(pinned: false)));
      await openMenu(tester);
      final before = menuRows(tester);
      resolution.emit(
        fakeResolution(const LyricsNone(_uri, LyricsNoneReason.noLyrics)),
      );
      await tester.pumpAndSettle();
      expect(menuRows(tester), before);
    });
  });

  group('a song that just changed', () {
    LyricsSourceResolution otherSource() => fakeResolution(
      LyricsFound('/m/other.flac', _lyrics(), origin: _origin(pinned: true)),
      effective: LyricsChoice.online,
      hasLocal: true,
      pin: fakePin(),
    );

    testWidgets('does not take the previous song\'s own lyrics', (
      tester,
    ) async {
      await pump(
        tester,
        otherSource(),
        track: _other,
        ownLyrics: _lyrics(),
        ownUri: _uri,
      );
      await openMenu(tester);
      expect(find.text('Lyrics in the file'), findsOneWidget);
      expect(find.text('.lrc file'), findsNothing);
      expect(find.text('In the tag'), findsNothing);
    });

    testWidgets('acts on the playing song when the library target is stale', (
      tester,
    ) async {
      await pump(
        tester,
        otherSource(),
        track: _other,
        overrides: [
          lyricsTargetProvider.overrideWith(
            (ref) => Stream.value(LyricsTarget.fromTrack(_song)),
          ),
        ],
      );
      await openMenu(tester);
      await tester.tap(item('Turn lyrics off for this song'));
      await tester.pumpAndSettle();
      expect(log, ['choose off /m/other.flac']);
    });

    testWidgets('does not open for a source of another song', (tester) async {
      await pump(tester, found(_lyrics()), track: _other);
      await tester.tap(find.byType(LyricsSourceButton));
      await tester.pumpAndSettle();
      expect(find.text('Automatic'), findsNothing);
      expect(opener.value!(), isFalse);
      expect(find.text('Automatic'), findsNothing);
      // The press left a tooltip timer behind: let it run out.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('opening', () {
    testWidgets('reports to the header and clears the report on removal', (
      tester,
    ) async {
      await pump(tester, found(_lyrics(), origin: _origin(pinned: false)));
      await openMenu(tester);
      expect(menuEvents, [true]);
      await tester.pumpWidget(const SizedBox());
      expect(menuEvents, [true, false]);
    });

    testWidgets('the key callback opens the menu on the first row', (
      tester,
    ) async {
      await pump(tester, found(_lyrics(), origin: _origin(pinned: false)));
      expect(opener.value, isNotNull);
      opener.value!();
      await tester.pumpAndSettle();
      expect(find.text('Automatic'), findsOneWidget);

      FocusNode focusOf(String title) =>
          Focus.of(tester.element(find.text(title)));
      expect(focusOf('Automatic').hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(focusOf('Keep this one').hasPrimaryFocus, isTrue);
    });

    testWidgets('the callback is cleared when the button leaves', (
      tester,
    ) async {
      await pump(tester, found(_lyrics(), origin: _origin(pinned: false)));
      expect(opener.value, isNotNull);
      await tester.pumpWidget(const SizedBox());
      expect(opener.value, isNull);
    });
  });
}
