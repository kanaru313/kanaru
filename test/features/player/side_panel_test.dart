import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/embedded_lyrics_reader.dart';
import 'package:kanaru/core/lyrics/lrc_sidecar_reader.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/lyrics/synced_lyrics_view.dart';
import 'package:kanaru/features/player/queue/queue_panel.dart';
import 'package:kanaru/features/player/side_panel/player_side_panel.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/in_page_filter_registry.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/fake_lyrics_readers.dart';
import '../../core/player/fake_audio_backend.dart';

const _sung = Track(uri: '/m/sung.flac', title: 'Sung', artist: 'A');
const _silent = Track(uri: '/m/silent.flac', title: 'Silent', artist: 'B');
const _alsoSung = Track(uri: '/m/also.flac', title: 'Also sung', artist: 'C');

void main() {
  late FakeLrcSidecarReader sidecar;
  late ProviderContainer container;

  PlayerService player() => container.read(playerServiceProvider.notifier);

  Future<void> pump(
    WidgetTester tester, {
    SidePanelTab tab = SidePanelTab.queue,
    Widget? home,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    sidecar = FakeLrcSidecarReader()
      ..byPath['/m/sung.flac'] = '[00:00.00]First words\n[00:05.00]More words'
      ..byPath['/m/also.flac'] = '[00:00.00]Other words\n[00:05.00]More';
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        embeddedLyricsReaderProvider.overrideWithValue(
          FakeEmbeddedLyricsReader(),
        ),
        lrcSidecarReaderProvider.overrideWithValue(sidecar),
        initialSettingsProvider.overrideWithValue(
          AppSettings(
            display: DisplayPrefs(sidePanelOpen: true, sidePanelTab: tab),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await player().openTracks([_sung, _silent, _alsoSung]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: home ?? const SizedBox(width: 360, child: PlayerSidePanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('tabs', () {
    testWidgets('open on the remembered tab', (tester) async {
      await pump(tester, tab: SidePanelTab.lyrics);
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
      expect(find.byType(QueuePanel), findsNothing);
    });

    testWidgets('the queue tab has no title row of its own', (tester) async {
      await pump(tester);
      // Only the tab says "Now playing".
      expect(find.text('Now playing'), findsOneWidget);
      expect(find.byType(QueuePanel), findsOneWidget);
    });
  });

  group('lyrics tab', () {
    testWidgets('shows the lyrics of the playing track', (tester) async {
      await pump(tester, tab: SidePanelTab.lyrics);
      expect(find.byType(SyncedLyricsView), findsOneWidget);
      expect(find.text('This song has no lyrics'), findsNothing);
    });

    testWidgets('says so for a track without lyrics', (tester) async {
      await pump(tester, tab: SidePanelTab.lyrics);
      await player().next();
      await tester.pumpAndSettle();
      expect(find.text('This song has no lyrics'), findsOneWidget);
      expect(find.byType(SyncedLyricsView), findsNothing);
    });

    testWidgets('shows no sentence while the next track loads', (tester) async {
      await pump(tester, tab: SidePanelTab.lyrics);
      await player().next();
      await tester.pumpAndSettle();
      expect(find.text('This song has no lyrics'), findsOneWidget);

      final gate = sidecar.gates['/m/also.flac'] = Completer<void>();
      await player().next();
      await tester.pump();
      expect(find.text('This song has no lyrics'), findsNothing);
      expect(find.byType(SyncedLyricsView), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SyncedLyricsView), findsOneWidget);
    });

    testWidgets('reads no lyrics while the queue tab shows', (tester) async {
      await pump(tester);
      expect(sidecar.reads, isEmpty);

      await tester.tap(find.text('Lyrics'));
      await tester.pumpAndSettle();
      expect(sidecar.reads, isNotEmpty);
    });
  });

  group('queue filter shortcut', () {
    var active = false;

    Future<void> pumpDocked(WidgetTester tester) async {
      active = false;
      await pump(
        tester,
        home: SizedBox(
          width: 360,
          child: QueuePanel(docked: true, isActive: () => active),
        ),
      );
    }

    testWidgets('is reachable only while the panel is the active place', (
      tester,
    ) async {
      await pumpDocked(tester);
      final registry = InPageFilterRegistry.instance;

      expect(registry.openTop(), isFalse);
      active = true;
      expect(registry.openTop(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('has no title row', (tester) async {
      await pumpDocked(tester);
      expect(find.text('Now playing'), findsNothing);
    });
  });

  testWidgets('a pointer press after the panel is gone raises nothing', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(100, 100));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
