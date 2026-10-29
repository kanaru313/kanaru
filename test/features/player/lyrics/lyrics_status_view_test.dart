import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' hide Track;
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status_provider.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/lyrics_view.dart';
import 'package:kanaru/features/player/lyrics/translation/lyrics_translation_placeholder.dart';
import 'package:kanaru/features/player/now_playing/now_playing_overlay.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_view_mode.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/online/fake_lyrics_provider.dart';
import '../../../core/lyrics/online/status_test_rig.dart';
import '../../../core/player/fake_audio_backend.dart';
import '../fake_translation_controller.dart';
import 'fake_playing_lyrics_status.dart';

const _uri = '/m/song.flac';
const _song = Track(uri: _uri, title: 'Song', artist: 'Artist');
const _origin = OnlineLyricsOrigin(
  providerId: 'fake',
  remoteId: '1',
  pinned: false,
  durationDelta: Duration(seconds: 2),
);

void main() {
  late ProviderContainer container;
  late FakePlayingLyricsStatus status;

  Widget app({Locale locale = const Locale('en')}) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
      // Cupertino has no Vietnamese, so the default list would complain.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: LyricsView()),
    ),
  );

  /// The view over a hand-moved status; a library only when [library].
  Future<void> pumpStatus(
    WidgetTester tester,
    PlayingLyricsStatus? initial, {
    Track track = _song,
    bool library = true,
    bool autoOn = false,
    Size size = const Size(800, 700),
    bool reduceMotion = false,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (reduceMotion) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }
    final registration = LyricsProviderRegistration(FakeLyricsProvider());
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    status = FakePlayingLyricsStatus(initial);
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        playingLyricsStatusProvider.overrideWith(() => status),
        lyricsProvidersProvider.overrideWithValue([registration]),
        libraryDatabaseProvider.overrideWithValue(library ? db : null),
        initialSettingsProvider.overrideWithValue(
          AppSettings(
            onlineLyrics: OnlineLyricsPrefs(
              autoFetch: autoOn,
              noticeAcknowledged: {if (autoOn) registration.autoConsentKey},
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(playerServiceProvider.notifier).openTracks([track]);
    await tester.pumpWidget(app(locale: locale));
    // A search pulses forever: step instead of settling.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// A test over [pumpStatus]; unmounts at the end so the library streams
  /// the view's providers opened can close their timers.
  void statusTest(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) async {
        await body(tester);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });

  final findOnline = find.text('Find lyrics online…');
  final findAuto = find.text('Find lyrics automatically');

  group('what each status shows', () {
    statusTest('reading shows nothing', (tester) async {
      await pumpStatus(tester, const LyricsReading(_uri));
      expect(find.byType(Text), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    statusTest('a status of another song shows nothing', (tester) async {
      await pumpStatus(
        tester,
        const LyricsNone('/m/other.flac', LyricsNoneReason.noLyrics),
      );
      expect(find.text('No lyrics for this song'), findsNothing);
    });

    statusTest('searching: one pulsing bar and the provider', (tester) async {
      await pumpStatus(tester, const LyricsSearching(_uri, 'fake'));
      expect(find.text('Searching Fake…'), findsOneWidget);
      expect(find.byType(LyricsTranslationPlaceholder), findsOneWidget);
      expect(tester.hasRunningAnimations, isTrue);
    });

    statusTest('searching with reduced motion: the bar is still', (
      tester,
    ) async {
      await pumpStatus(
        tester,
        const LyricsSearching(_uri, 'fake'),
        reduceMotion: true,
      );
      expect(find.byType(LyricsTranslationPlaceholder), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    statusTest('found local lyrics have no credit', (tester) async {
      await pumpStatus(tester, LyricsFound(_uri, fakeSyncedLyrics()));
      expect(find.text('First words'), findsOneWidget);
      expect(find.textContaining('Lyrics from'), findsNothing);
    });

    statusTest('found online lyrics: credit, "not synced" for plain', (
      tester,
    ) async {
      await pumpStatus(
        tester,
        LyricsFound(_uri, fakeSyncedLyrics(), origin: _origin),
      );
      expect(find.text('Lyrics from Fake'), findsOneWidget);

      status.emit(LyricsFound(_uri, fakePlainLyrics(), origin: _origin));
      await tester.pump();
      expect(find.text('Lyrics from Fake · not synced'), findsOneWidget);
    });

    statusTest('the credit is plain text without a menu', (tester) async {
      await pumpStatus(
        tester,
        LyricsFound(_uri, fakeSyncedLyrics(), origin: _origin),
      );
      await tester.tap(find.text('Lyrics from Fake'));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(find.byType(MenuAnchor), findsNothing);
    });

    statusTest('no lyrics: both buttons; auto hidden once on', (tester) async {
      await pumpStatus(
        tester,
        const LyricsNone(_uri, LyricsNoneReason.noLyrics),
      );
      expect(find.text('No lyrics for this song'), findsOneWidget);
      expect(findOnline, findsOneWidget);
      expect(findAuto, findsOneWidget);
    });

    statusTest('no lyrics with automatic lookup on: only Find online', (
      tester,
    ) async {
      await pumpStatus(
        tester,
        const LyricsNone(_uri, LyricsNoneReason.noLyrics),
        autoOn: true,
      );
      expect(findOnline, findsOneWidget);
      expect(findAuto, findsNothing);
    });

    statusTest('no buttons for a stream or without a library', (tester) async {
      await pumpStatus(
        tester,
        const LyricsNone('http://x/y.mp3', LyricsNoneReason.noLyrics),
        track: const Track(uri: 'http://x/y.mp3', title: 'Stream'),
      );
      expect(find.text('No lyrics for this song'), findsOneWidget);
      expect(findOnline, findsNothing);
      expect(findAuto, findsNothing);

      await pumpStatus(
        tester,
        const LyricsNone(_uri, LyricsNoneReason.noLyrics),
        library: false,
      );
      expect(find.text('No lyrics for this song'), findsOneWidget);
      expect(findOnline, findsNothing);
      expect(findAuto, findsNothing);
    });

    statusTest('not found names the provider and offers a manual search', (
      tester,
    ) async {
      await pumpStatus(
        tester,
        const LyricsNone(_uri, LyricsNoneReason.notFound),
      );
      expect(find.text('No lyrics found on Fake'), findsOneWidget);
      expect(find.text('Search manually…'), findsOneWidget);
    });

    statusTest('error: banner with Retry above the plain empty state', (
      tester,
    ) async {
      await pumpStatus(tester, const LyricsNone(_uri, LyricsNoneReason.error));
      expect(find.text("Couldn't reach Fake"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('No lyrics for this song'), findsOneWidget);
      expect(findOnline, findsOneWidget);
      expect(findAuto, findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        tester.getTopLeft(find.text("Couldn't reach Fake")).dy,
        lessThan(tester.getTopLeft(find.text('No lyrics for this song')).dy),
      );
    });

    statusTest('error after a busy answer says the service is busy', (
      tester,
    ) async {
      await pumpStatus(
        tester,
        const LyricsNone(
          _uri,
          LyricsNoneReason.error,
          failure: LyricsFetchKind.rateLimited,
        ),
      );
      expect(find.text('Fake is busy. Try again in a moment.'), findsOneWidget);
      expect(find.text("Couldn't reach Fake"), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    });

    statusTest('error after a network failure keeps "Couldn\'t reach"', (
      tester,
    ) async {
      await pumpStatus(
        tester,
        const LyricsNone(
          _uri,
          LyricsNoneReason.error,
          failure: LyricsFetchKind.network,
        ),
      );
      expect(find.text("Couldn't reach Fake"), findsOneWidget);
      expect(find.textContaining('busy'), findsNothing);
    });

    statusTest('off and paused show no buttons', (tester) async {
      await pumpStatus(tester, const LyricsNone(_uri, LyricsNoneReason.off));
      expect(findOnline, findsNothing);
      status.emit(
        LyricsNone(
          _uri,
          LyricsNoneReason.paused,
          resumeAt: DateTime(2026, 10, 29, 14, 5),
        ),
      );
      await tester.pump();
      expect(findOnline, findsNothing);
    });

    statusTest('instrumental: the title and the credit', (tester) async {
      await pumpStatus(
        tester,
        const LyricsNone(_uri, LyricsNoneReason.instrumental, origin: _origin),
      );
      expect(find.text('Instrumental'), findsOneWidget);
      expect(find.text('Lyrics from Fake'), findsOneWidget);
    });

    statusTest('Vietnamese strings', (tester) async {
      await pumpStatus(
        tester,
        const LyricsSearching(_uri, 'fake'),
        locale: const Locale('vi'),
      );
      expect(find.text('Đang tìm trên Fake…'), findsOneWidget);
      status.emit(const LyricsNone(_uri, LyricsNoneReason.error));
      await tester.pump();
      expect(find.text('Không kết nối được Fake'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    for (final size in const [Size(720, 400), Size(400, 800)]) {
      statusTest('every state fits $size', (tester) async {
        final states = <PlayingLyricsStatus>[
          const LyricsSearching(_uri, 'fake'),
          const LyricsNone(_uri, LyricsNoneReason.noLyrics),
          const LyricsNone(_uri, LyricsNoneReason.notFound),
          const LyricsNone(_uri, LyricsNoneReason.error),
          const LyricsNone(_uri, LyricsNoneReason.off),
          LyricsNone(
            _uri,
            LyricsNoneReason.paused,
            resumeAt: DateTime(2026, 10, 29, 14, 5),
          ),
          const LyricsNone(
            _uri,
            LyricsNoneReason.instrumental,
            origin: _origin,
          ),
          LyricsFound(_uri, fakeSyncedLyrics(), origin: _origin),
          LyricsFound(_uri, fakePlainLyrics(), origin: _origin),
        ];
        await pumpStatus(tester, states.first, size: size);
        for (final next in states) {
          status.emit(next);
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull, reason: '$next');
        }
      });
    }
  });

  /// Now Playing over a hand-moved status, wide.
  Future<void> pumpOverlay(
    WidgetTester tester,
    PlayingLyricsStatus initial, {
    List<Override> overrides = const [],
    AppSettings settings = const AppSettings(),
    Size size = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    status = FakePlayingLyricsStatus(initial);
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        playingLyricsStatusProvider.overrideWith(() => status),
        initialSettingsProvider.overrideWithValue(settings),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    await container.read(playerServiceProvider.notifier).openTracks([_song]);
    container.read(nowPlayingOpenProvider.notifier).open();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const NowPlayingOverlay(behind: SizedBox.expand()),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('T while searching', () {
    testWidgets('asks nothing and turns nothing on', (tester) async {
      await pumpOverlay(tester, const LyricsSearching(_uri, 'fake'));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Lyrics will be sent to Google'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(container.read(settingsProvider).translation.show, isFalse);
    });
  });

  group('source credit is shown in Now Playing', () {
    for (final (name, size, mode) in [
      ('Split', const Size(1280, 800), NowPlayingViewMode.split),
      ('Lyrics only', const Size(1280, 800), NowPlayingViewMode.lyricsOnly),
      ('narrow', const Size(400, 800), NowPlayingViewMode.split),
    ]) {
      for (final synced in [true, false]) {
        testWidgets('$name, ${synced ? 'synced' : 'plain'} lyrics', (
          tester,
        ) async {
          await pumpOverlay(
            tester,
            LyricsFound(
              _uri,
              synced ? fakeSyncedLyrics() : fakePlainLyrics(),
              origin: _origin,
            ),
            size: size,
            overrides: [
              lyricsProvidersProvider.overrideWithValue([
                LyricsProviderRegistration(FakeLyricsProvider()),
              ]),
            ],
          );
          container.read(nowPlayingViewModeProvider.notifier).choose(mode);
          await tester.pumpAndSettle();
          if (size.width < 720) {
            await tester.tap(find.byTooltip('Lyrics'));
            await tester.pumpAndSettle();
          }
          expect(
            find.text(
              synced ? 'Lyrics from Fake' : 'Lyrics from Fake · not synced',
            ),
            findsOneWidget,
          );
        });
      }
    }
  });

  group('source credit with a translation on', () {
    testWidgets('the credit is plain; the header pill opens its menu', (
      tester,
    ) async {
      final fake = FakeTranslationController(
        TranslationReady(
          fakeTranslationInfo(),
          LyricsTranslationService.google,
          'ja',
          const ['Dòng một', 'Dòng hai'],
          false,
        ),
      );
      await pumpOverlay(
        tester,
        LyricsFound(_uri, fakeSyncedLyrics(), origin: _origin),
        overrides: [
          fakeTranslationOverride(fake),
          lyricsProvidersProvider.overrideWithValue([
            LyricsProviderRegistration(FakeLyricsProvider()),
          ]),
        ],
        settings: const AppSettings(
          translation: TranslationPrefs(
            show: true,
            noticeAcknowledged: {LyricsTranslationService.google},
          ),
        ),
      );
      expect(find.text('Dòng một'), findsOneWidget);

      await tester.tap(find.text('Lyrics from Fake'));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(find.text('Show translation'), findsNothing);

      await tester.tap(find.text('Google · English'));
      await tester.pumpAndSettle();
      expect(find.text('Show translation'), findsOneWidget);
    });
  });

  group('actions on the real status', () {
    late StatusRig rig;
    final trackKey = LyricsTarget.fromTrack(fakeSong('/m/a.flac')).trackKey;

    /// Real time for the database and the lookups, then the fake clock.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    /// The view over the real status of the song at `/m/a.flac`; [prepare]
    /// scripts the rig before the song plays.
    Future<void> pumpRig(
      WidgetTester tester, {
      bool autoFetch = true,
      bool autoConsent = true,
      bool manualConsent = true,
      void Function(StatusRig rig)? prepare,
    }) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      rig = await createStatusRig(
        autoFetch: autoFetch,
        autoConsent: autoConsent,
        manualConsent: manualConsent,
      );
      container = rig.container;
      prepare?.call(rig);
      await rig.play([fakeSong('/m/a.flac')]);
      await tester.pumpWidget(app());
      await settle(tester);
    }

    testWidgets('Retry looks the song up again', (tester) async {
      await pumpRig(
        tester,
        prepare: (rig) => rig.fake.lookupResult = const LyricsFetchException(
          LyricsFetchKind.server,
        ),
      );
      expect(find.text("Couldn't reach Fake"), findsOneWidget);
      expect(rig.fake.lookupCalls, 1);

      rig.fake.lookupResult = fakeCandidate();
      await tester.tap(find.text('Retry'));
      await settle(tester);

      expect(rig.fake.lookupCalls, 2);
      expect(find.text("Couldn't reach Fake"), findsNothing);
      expect(find.text('Lyrics from Fake'), findsOneWidget);
    });

    testWidgets(
      'picked lyrics over embedded ones show their credit and send nothing',
      (tester) async {
        await pumpRig(
          tester,
          prepare: (rig) {
            rig.sidecar.byPath['/m/a.flac'] = '[00:00.00]Own words';
            rig.fake.lookupResult = fakeCandidate();
          },
        );
        expect(find.text('Own words'), findsOneWidget);
        expect(find.textContaining('Lyrics from'), findsNothing);

        await tester.runAsync(
          () => rig.h.db.pinLyrics(
            LyricsPinsCompanion.insert(
              trackKey: trackKey,
              pinnedAt: 1,
              mode: const Value('online'),
              providerId: const Value('fake'),
              remoteId: const Value('p'),
              syncedText: const Value('[00:00.00]Picked words'),
            ),
          ),
        );
        await settle(tester);
        expect(find.text('Picked words'), findsOneWidget);
        expect(find.text('Lyrics from Fake'), findsOneWidget);
        expect(rig.requests, 0);
      },
    );

    testWidgets('Find lyrics online with consent declined sends nothing', (
      tester,
    ) async {
      await pumpRig(tester, autoFetch: false, manualConsent: false);
      expect(find.text('No lyrics for this song'), findsOneWidget);

      await tester.tap(findOnline);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(rig.requests, 0);
      expect(
        rig.h.container.read(settingsProvider).onlineLyrics.autoFetch,
        false,
      );
    });

    testWidgets('Find lyrics automatically asks, then turns lookup on', (
      tester,
    ) async {
      await pumpRig(tester, autoFetch: false, autoConsent: false);
      expect(rig.requests, 0);

      await tester.tap(findAuto);
      await tester.pumpAndSettle();
      expect(find.text('Find lyrics online automatically?'), findsOneWidget);
      await tester.tap(find.text('Turn on'));
      await settle(tester);

      expect(
        rig.h.container.read(settingsProvider).onlineLyrics.autoFetch,
        true,
      );
      expect(findAuto, findsNothing);
    });
  });
}
