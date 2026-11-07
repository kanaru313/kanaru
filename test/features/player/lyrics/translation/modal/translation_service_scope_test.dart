import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/lyric_translation_queries.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/queue_translation_choice.dart';
import 'package:kanaru/core/lyrics_translation/translation_clock.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope_providers.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart' as player;
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_pickers.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/selection_row.dart';
import 'package:material_ui/material_ui.dart';

import 'translation_modal_harness.dart';

const _id = 'plugin-abc123def456';
const _otherId = 'plugin-111111111111';
const _goneId = 'plugin-999999999999';
const _now = 5000;

void main() {
  final plugin = TranslationServiceId.tryParse(_id)!;
  final other = TranslationServiceId.tryParse(_otherId)!;
  late LibraryDatabase db;
  late ProviderContainer container;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  TranslationPrefs prefs0({
    bool show = true,
    int? allChosenAt,
    TranslationServiceId? service,
  }) => TranslationPrefs(
    show: show,
    service: service ?? plugin,
    allChosenAt: allChosenAt,
    noticeAcknowledged: {plugin},
  );

  Future<void> pump(
    WidgetTester tester, {
    required TranslationPrefs prefs,
    TranslationTargetInfo? info,
    bool queued = true,
  }) async {
    final live = [
      translateRecord(_id, name: 'Gemini'),
      translateRecord(_otherId, name: 'Other'),
    ];
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        libraryDatabaseProvider.overrideWithValue(db),
        lyricsPluginRecordsProvider.overrideWithValue(live),
        translatePluginRecordsProvider.overrideWithValue(AsyncData(live)),
        initialSettingsProvider.overrideWithValue(
          AppSettings(translation: prefs),
        ),
        translationClockProvider.overrideWithValue(() => _now),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => openServicePicker(context, ref, info: info),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    if (queued) {
      await tester.runAsync(
        () => container.read(playerServiceProvider.notifier).openTracks([
          player.Track.fromPath('/music/a.mp3'),
          player.Track.fromPath('/music/b.mp3'),
        ]),
      );
    }
    // Lets the song choices stream deliver its first value.
    final sub = container.listen(songTranslationOverridesProvider, (_, _) {});
    addTearDown(sub.close);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }

  TranslationTargetInfo songInfo({TranslationServiceId? service}) =>
      fakeTranslationInfo(
        hash: 'h1',
        choice: TranslationChoice(
          service: service ?? plugin,
          scope: TranslationScope.all,
          tune: const {},
          defaultService: plugin,
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 400));
  }

  SegmentedButton<TranslationScope> seg(WidgetTester tester) =>
      tester.widget<SegmentedButton<TranslationScope>>(
        find.byType(SegmentedButton<TranslationScope>),
      );

  Future<void> tapRow(WidgetTester tester, String name) async {
    await tester.tap(find.widgetWithText(SelectionRow, name));
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await settle(tester);
  }

  Future<SongTranslationOverride?> rowOf(
    WidgetTester tester,
    String hash,
  ) async {
    final rows = await tester.runAsync(
      () => db.watchSongTranslationOverrides().first,
    );
    for (final r in rows!) {
      if (r.hash == hash) return r;
    }
    return null;
  }

  Future<void> seed(
    WidgetTester tester,
    String hash,
    String service,
    int at,
  ) async {
    await tester.runAsync(
      () => db.setSongTranslationService(hash, service, chosenAt: at),
    );
  }

  testWidgets('every open starts on this song, whatever was picked before', (
    tester,
  ) async {
    await pump(tester, prefs: prefs0(), info: songInfo());
    await open(tester);
    expect(seg(tester).selected, {TranslationScope.song});
    expect(
      find.text(
        'Only the song now playing uses this service (AI tune included).',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('All songs'));
    await tester.pump();
    expect(seg(tester).selected, {TranslationScope.all});
    expect(
      find.text('Changes the default service for every song.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    await open(tester);
    expect(seg(tester).selected, {TranslationScope.song});
  });

  testWidgets('translation off locks this song and selects all songs', (
    tester,
  ) async {
    await pump(tester, prefs: prefs0(show: false), info: songInfo());
    await open(tester);
    expect(seg(tester).selected, {TranslationScope.all});
    final song = seg(tester).segments
        .firstWhere((s) => s.value == TranslationScope.song);
    expect(song.enabled, isFalse);
    expect(
      song.tooltip,
      'Turn translation on to choose a service for this song only.',
    );
  });

  testWidgets('no song locks this song and selects all songs', (tester) async {
    await pump(tester, prefs: prefs0(), info: null);
    await open(tester);
    expect(seg(tester).selected, {TranslationScope.all});
    final song = seg(tester).segments
        .firstWhere((s) => s.value == TranslationScope.song);
    expect(song.enabled, isFalse);
    expect(song.tooltip, isNotNull);
  });

  testWidgets('the check mark is on the song\'s service', (tester) async {
    await pump(
      tester,
      prefs: prefs0(),
      info: songInfo(service: other),
    );
    await open(tester);
    bool checked(String n) => tester
        .widget<SelectionRow>(find.widgetWithText(SelectionRow, n))
        .selected;
    expect(checked('Other'), isTrue);
    expect(checked('Gemini'), isFalse);
  });

  testWidgets('this song + Cancel writes nothing', (tester) async {
    await pump(tester, prefs: prefs0(), info: songInfo());
    await open(tester);
    await tapRow(tester, 'Other');
    expect(find.byType(AlertDialog), findsOneWidget);
    await tapText(tester, 'Cancel');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(SelectionRow, 'Other'), findsOneWidget);
    expect(seg(tester).selected, {TranslationScope.song});
    expect(await rowOf(tester, 'h1'), isNull);
    final p = container.read(settingsProvider).translation;
    expect(p.noticeAcknowledged, {plugin});
    expect(p.allChosenAt, isNull);
  });

  testWidgets('this song + Continue stores service and time only', (
    tester,
  ) async {
    await pump(tester, prefs: prefs0(allChosenAt: 100), info: songInfo());
    await open(tester);
    await tapRow(tester, 'Other');
    await tapText(tester, 'Continue');
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(SelectionRow, 'Other'), findsNothing);
    final row = await rowOf(tester, 'h1');
    expect(row?.service, _otherId);
    expect(row?.chosenAt, _now);
    final p = container.read(settingsProvider).translation;
    expect(p.service, plugin);
    expect(p.allChosenAt, 100);
    expect(p.noticeAcknowledged, {plugin, other});
  });

  testWidgets('all songs + Cancel leaves the default stamp alone', (
    tester,
  ) async {
    await pump(tester, prefs: prefs0(allChosenAt: 100), info: songInfo());
    await open(tester);
    await tester.tap(find.text('All songs'));
    await tester.pump();
    await tapRow(tester, 'Other');
    await tapText(tester, 'Cancel');
    expect(find.widgetWithText(SelectionRow, 'Other'), findsOneWidget);
    expect(seg(tester).selected, {TranslationScope.all});
    final p = container.read(settingsProvider).translation;
    expect(p.service, plugin);
    expect(p.allChosenAt, 100);
  });

  testWidgets('all songs + Continue stamps the default and keeps song rows', (
    tester,
  ) async {
    await pump(tester, prefs: prefs0(allChosenAt: 100), info: songInfo());
    await seed(tester, 'h1', _id, 500);
    await tester.pump();
    expect(
      translationChoiceFor(container.read, 'h1')?.scope,
      TranslationScope.song,
    );
    await open(tester);
    await tester.tap(find.text('All songs'));
    await tester.pump();
    await tapRow(tester, 'Other');
    await tapText(tester, 'Continue');
    final p = container.read(settingsProvider).translation;
    expect(p.service, other);
    expect(p.allChosenAt, _now);
    expect(p.show, isTrue);
    expect((await rowOf(tester, 'h1'))?.service, _id);
    final choice = translationChoiceFor(container.read, 'h1');
    expect(choice?.scope, TranslationScope.all);
    expect(choice?.service, other);
  });

  testWidgets('caption counts only songs that can still win', (tester) async {
    await pump(tester, prefs: prefs0(allChosenAt: 1000), info: songInfo());
    await open(tester);
    await tester.tap(find.text('All songs'));
    await tester.pump();
    expect(find.textContaining('Will also replace'), findsNothing);
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);

    await seed(tester, 'a', _id, 2000);
    await seed(tester, 'b', _otherId, 3000);
    await seed(tester, 'c', _id, 4000);
    await seed(tester, 'old', _id, 900);
    await seed(tester, 'gone', _goneId, 4500);
    await tester.pump();
    await open(tester);
    expect(find.textContaining('Will also replace'), findsNothing);
    await tester.tap(find.text('All songs'));
    await tester.pump();
    expect(
      find.text('Will also replace 3 songs you set individually'),
      findsOneWidget,
    );
  });

  testWidgets('a failed song write shows a snackbar and keeps the service', (
    tester,
  ) async {
    await pump(tester, prefs: prefs0(), info: songInfo());
    await open(tester);
    await tester.tap(find.widgetWithText(SelectionRow, 'Other'));
    await settle(tester);
    // The notice dialog is open; the database goes away before Continue.
    await tester.runAsync(db.close);
    await tapText(tester, 'Continue');
    expect(find.text("Couldn't save the choice for this song"), findsOneWidget);
    expect(translationChoiceFor(container.read, 'h1')?.service, plugin);
  });

  testWidgets('tapping the locked song segment keeps all songs', (
    tester,
  ) async {
    await pump(tester, prefs: prefs0(), info: null);
    await open(tester);
    await tester.tap(find.text('Only this song'));
    await tester.pump();
    expect(seg(tester).selected, {TranslationScope.all});
  });

  testWidgets('an acknowledged service closes the picker with no dialog', (
    tester,
  ) async {
    await pump(
      tester,
      prefs: prefs0(),
      info: songInfo(service: other),
    );
    await open(tester);
    await tapRow(tester, 'Gemini');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(SelectionRow, 'Gemini'), findsNothing);
    expect((await rowOf(tester, 'h1'))?.service, _id);
  });

  testWidgets('Esc closes the notice first, then the picker', (tester) async {
    await pump(tester, prefs: prefs0(), info: songInfo());
    await open(tester);
    await tester.tap(find.widgetWithText(SelectionRow, 'Other'));
    await settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(SelectionRow, 'Other'), findsOneWidget);
    expect(await rowOf(tester, 'h1'), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.widgetWithText(SelectionRow, 'Other'), findsNothing);
    expect(await rowOf(tester, 'h1'), isNull);
  });

  group('queue scope', () {
    ScopedTranslationChoice? queueChoice() =>
        container.read(queueTranslationChoiceProvider);

    Future<void> openQueueScope(WidgetTester tester) async {
      await open(tester);
      await tester.tap(find.text('Queue'));
      await tester.pump();
    }

    testWidgets('sits between this song and all songs', (tester) async {
      await pump(tester, prefs: prefs0(), info: songInfo());
      await open(tester);
      expect(seg(tester).segments.map((s) => s.value), [
        TranslationScope.song,
        TranslationScope.queue,
        TranslationScope.all,
      ]);
      await tester.tap(find.text('Queue'));
      await tester.pump();
      expect(seg(tester).selected, {TranslationScope.queue});
      expect(
        find.text(
          'Songs in the current queue use this service; a new queue goes '
          'back to the default.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Will also replace'), findsNothing);
    });

    testWidgets('is locked while translation is off', (tester) async {
      await pump(tester, prefs: prefs0(show: false), info: songInfo());
      await open(tester);
      final queue = seg(tester).segments
          .firstWhere((s) => s.value == TranslationScope.queue);
      expect(queue.enabled, isFalse);
      expect(
        queue.tooltip,
        'Turn translation on to choose a service for the queue.',
      );
    });

    testWidgets('is locked when the queue is empty', (tester) async {
      await pump(tester, prefs: prefs0(), info: songInfo(), queued: false);
      await open(tester);
      final queue = seg(tester).segments
          .firstWhere((s) => s.value == TranslationScope.queue);
      expect(queue.enabled, isFalse);
      expect(queue.tooltip, 'The queue is empty.');
      expect(seg(tester).selected, {TranslationScope.song});
    });

    testWidgets('is open when no song has lyrics', (tester) async {
      await pump(tester, prefs: prefs0(), info: null);
      await open(tester);
      final queue = seg(tester).segments
          .firstWhere((s) => s.value == TranslationScope.queue);
      expect(queue.enabled, isTrue);
    });

    testWidgets('Cancel writes nothing', (tester) async {
      await pump(tester, prefs: prefs0(), info: songInfo());
      await openQueueScope(tester);
      await tapRow(tester, 'Other');
      await tapText(tester, 'Cancel');
      expect(queueChoice(), isNull);
      expect(container.read(settingsProvider).translation.noticeAcknowledged, {
        plugin,
      });
    });

    testWidgets('Continue stores the service and time for the queue only', (
      tester,
    ) async {
      await pump(tester, prefs: prefs0(allChosenAt: 100), info: songInfo());
      await openQueueScope(tester);
      await tapRow(tester, 'Other');
      await tapText(tester, 'Continue');
      await tester.pump(const Duration(seconds: 1));
      expect(queueChoice()?.service, other);
      expect(queueChoice()?.chosenAt, _now);
      expect(queueChoice()?.tune, isEmpty);
      expect(await rowOf(tester, 'h1'), isNull);
      final p = container.read(settingsProvider).translation;
      expect(p.service, plugin);
      expect(p.allChosenAt, 100);
      expect(p.noticeAcknowledged, {plugin, other});
      expect(
        translationChoiceFor(container.read, 'h1')?.scope,
        TranslationScope.queue,
      );
    });

    testWidgets('an acknowledged service closes the picker with no dialog', (
      tester,
    ) async {
      await pump(
        tester,
        prefs: prefs0(),
        info: songInfo(service: other),
      );
      await openQueueScope(tester);
      await tapRow(tester, 'Gemini');
      expect(find.byType(AlertDialog), findsNothing);
      expect(queueChoice()?.service, plugin);
    });

    testWidgets('all songs mentions the queue only while its choice is newer', (
      tester,
    ) async {
      await pump(tester, prefs: prefs0(allChosenAt: 100), info: songInfo());
      container
          .read(queueTranslationChoiceProvider.notifier)
          .set(other, chosenAt: 200);
      await open(tester);
      await tester.tap(find.text('All songs'));
      await tester.pump();
      expect(
        find.text('Will also replace the current queue\'s choice'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close'));
      await settle(tester);

      container
          .read(queueTranslationChoiceProvider.notifier)
          .set(other, chosenAt: 50);
      await open(tester);
      await tester.tap(find.text('All songs'));
      await tester.pump();
      expect(find.textContaining('Will also replace'), findsNothing);
    });

    testWidgets('the caption counts songs and the queue together', (
      tester,
    ) async {
      await pump(tester, prefs: prefs0(allChosenAt: 100), info: songInfo());
      await seed(tester, 'a', _id, 2000);
      container
          .read(queueTranslationChoiceProvider.notifier)
          .set(other, chosenAt: 200);
      await tester.pump();
      await open(tester);
      await tester.tap(find.text('All songs'));
      await tester.pump();
      expect(
        find.text(
          'Will also replace 1 song you set individually and the current queue\'s choice',
        ),
        findsOneWidget,
      );
    });
  });
}
