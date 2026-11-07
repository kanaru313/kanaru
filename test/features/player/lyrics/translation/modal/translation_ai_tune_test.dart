import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' hide Track;
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/lyric_translation_queries.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_config_values_provider.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/queue_translation_choice.dart';
import 'package:kanaru/core/lyrics_translation/translation_clock.dart';
import 'package:kanaru/core/lyrics_translation/translation_jobs.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/lyrics_translation_modal.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_ai_badge.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_ai_tune_modal.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/shared/translation_plugin_routes.dart';
import 'package:kanaru/shared/widgets/selection_row.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../lyrics_sources/lyrics_sources_harness.dart';
import 'translation_modal_harness.dart';

const _model = PluginConfigField(
  key: 'model',
  title: 'Model',
  mode: PluginConfigMode.select,
  selectFormat: PluginSelectFormat.single,
  custom: true,
  defaultValue: 'flash',
  options: [
    PluginConfigOption(value: 'flash', title: 'Flash', subtitle: 'Fast'),
    PluginConfigOption(value: 'pro', title: 'Pro', subtitle: 'Careful'),
  ],
);
const _style = PluginConfigField(
  key: 'style',
  title: 'Style',
  mode: PluginConfigMode.select,
  selectFormat: PluginSelectFormat.single,
  defaultValue: 'literal',
  options: [
    PluginConfigOption(value: 'literal', title: 'Literal'),
    PluginConfigOption(value: 'poetic', title: 'Poetic'),
  ],
);
const _note = PluginConfigField(
  key: 'customInstruction',
  title: 'Instruction',
  mode: PluginConfigMode.input,
  inputFormat: PluginInputFormat.text,
);
const _thinking = PluginConfigField(
  key: 'thinking',
  title: 'Thinking budget',
  mode: PluginConfigMode.toggle,
);
const _useSong = PluginConfigField(
  key: 'useSongContext',
  title: 'Use song context',
  mode: PluginConfigMode.toggle,
);
const _config = [_model, _style, _note, _thinking, _useSong];

final _onPrefs = TranslationPrefs(
  show: true,
  service: testTranslatePlugin,
  noticeAcknowledged: {testTranslatePlugin},
);

class _RecordingJobs extends TranslationJobs {
  final cleared = <TranslationServiceId>[];

  @override
  void clearFailures(TranslationServiceId service) => cleared.add(service);
}

/// A widget test that lets the tree go before it ends: drift closes its query
/// streams on a timer once nothing listens.
void tuneTest(String name, Future<void> Function(WidgetTester tester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });

Future<void> openTuneModal(WidgetTester tester) async {
  await tester.tap(find.text('AI tuning'));
  await settleModal(tester);
}

class _Rig {
  _Rig(this.h, this.plugins, this.jobs, this.runner, this.db);

  final TranslationModalHarness h;
  final FakePlugins plugins;
  final _RecordingJobs jobs;
  final FakePluginRunner runner;
  final LibraryDatabase db;
}

void main() {
  Future<_Rig> pump(
    WidgetTester tester, {
    PluginKind kind = PluginKind.aiTranslate,
    List<PluginConfigField> config = _config,
    Map<String, Object?> stored = const {},
    FakePlugins? plugins,
    LyricsTranslationState? state,
    TranslationPrefs? settings,
    bool openTune = true,
    List<Override> extra = const [],
    Locale locale = const Locale('en'),
  }) async {
    final fake = (plugins ?? FakePlugins())..stored = stored;
    final jobs = _RecordingJobs();
    final runner = FakePluginRunner();
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(db.close));
    final h = await pumpTranslationModal(
      tester,
      state: state,
      settings: settings ?? _onPrefs,
      locale: locale,
      pluginOverrides: translatePluginOverrides(
        records: [
          translateRecord(
            testTranslatePluginId,
            name: 'Test AI',
            kind: kind,
            config: config,
          ),
        ],
        runner: runner,
      ),
      overrides: [
        lyricsPluginsControllerProvider.overrideWithValue(fake),
        pluginStoredConfigProvider.overrideWith(
          (ref, id) => fake.storedStream(id),
        ),
        translationJobsProvider.overrideWith(() => jobs),
        libraryDatabaseProvider.overrideWithValue(db),
        ...extra,
      ],
    );
    final rig = _Rig(h, fake, jobs, runner, db);
    await tester.pump(const Duration(milliseconds: 50));
    if (openTune) await openTuneModal(tester);
    return rig;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await settleModal(tester);
  }

  /// Text inside the tune modal only (the row under the service has the same
  /// style title).
  Finder inTune(String text) => find.descendant(
    of: find.byType(TranslationAiTuneModal),
    matching: find.text(text),
  );

  /// Chooses a scope segment of the open tune modal.
  Future<void> pickScope(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<TranslationScope>),
        matching: find.text(label),
      ),
    );
    await settleModal(tester);
  }

  Future<void> tapRow(WidgetTester tester, String title) async {
    await tester.tap(find.widgetWithText(SelectionRow, title));
    await settleModal(tester);
  }

  Future<String?> savedNote(WidgetTester tester, _Rig rig, String hash) =>
      tester.runAsync<String?>(() => rig.db.songTranslationInstruction(hash));

  group('the row and the badge', () {
    tuneTest('an ai-translate service has the badge and the tune row', (
      tester,
    ) async {
      await pump(tester, openTune: false);
      expect(find.byType(TranslationAiBadge), findsOneWidget);
      expect(find.text('AI tuning'), findsOneWidget);
      // Nothing stored: the subtitle is the title of the default style.
      expect(find.text('Literal'), findsOneWidget);
    });

    tuneTest('the subtitle follows the stored style', (tester) async {
      await pump(tester, stored: {'style': 'poetic'}, openTune: false);
      expect(find.text('Poetic'), findsOneWidget);
    });

    tuneTest('a style the plugin dropped reads as no longer supported', (
      tester,
    ) async {
      await pump(tester, stored: {'style': 'gone'}, openTune: false);
      expect(find.text('gone (no longer supported)'), findsOneWidget);
    });

    tuneTest('the service picker tags the AI service', (tester) async {
      await pump(tester, openTune: false);
      await tester.tap(find.text('Test AI'));
      await settleModal(tester);
      expect(
        find.descendant(
          of: find.widgetWithText(SelectionRow, 'Test AI'),
          matching: find.byType(TranslationAiBadge),
        ),
        findsOneWidget,
      );
    });

    tuneTest('a translate service has neither the badge nor the row', (
      tester,
    ) async {
      await pump(tester, kind: PluginKind.translate, openTune: false);
      expect(find.text('Test AI'), findsOneWidget);
      expect(find.byType(TranslationAiBadge), findsNothing);
      expect(find.text('AI tuning'), findsNothing);
    });

    tuneTest('an ai-translate service missing a field has no row', (
      tester,
    ) async {
      await pump(tester, config: [_model, _style], openTune: false);
      expect(find.byType(TranslationAiBadge), findsOneWidget);
      expect(find.text('AI tuning'), findsNothing);
    });

    tuneTest('the row hides with the section when translation is off', (
      tester,
    ) async {
      await pump(
        tester,
        settings: TranslationPrefs(
          service: testTranslatePlugin,
          noticeAcknowledged: {testTranslatePlugin},
        ),
        openTune: false,
      );
      expect(find.text('AI tuning'), findsNothing);
    });

    tuneTest('the Vietnamese row and modal read in Vietnamese', (tester) async {
      await pump(tester, locale: const Locale('vi'), openTune: false);
      await tapText(tester, 'Tinh chỉnh AI');
      expect(find.text('Phong cách'), findsOneWidget);
      expect(find.text('Lời dặn cho bài này'), findsOneWidget);
      expect(find.text('Xong'), findsOneWidget);
    });
  });

  group('the child modal', () {
    tuneTest('holds only the model, the style and the song note', (
      tester,
    ) async {
      await pump(tester, stored: {'customInstruction': 'shared text'});
      expect(find.text('Model'), findsOneWidget);
      expect(find.text('Style'), findsOneWidget);
      expect(find.text('Note for this song'), findsOneWidget);
      expect(find.text('Thinking budget'), findsNothing);
      expect(find.text('Use song context'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(TranslationAiTuneModal),
          matching: find.byType(Switch),
        ),
        findsNothing,
      );
      // One text box: the song's note, never the shared instruction.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('shared text'), findsNothing);
      expect(
        find.text('Set by the plugin Test AI. Saved for this plugin.'),
        findsOneWidget,
      );
    });

    tuneTest('Done closes only the child modal', (tester) async {
      await pump(tester);
      await tapText(tester, 'Done');
      expect(find.byType(TranslationAiTuneModal), findsNothing);
      expect(find.byType(LyricsTranslationModal), findsOneWidget);
    });

    tuneTest('a model box shows title, subtitle and a check', (tester) async {
      await pump(tester);
      expect(find.text('Flash'), findsOneWidget);
      expect(find.text('Fast'), findsOneWidget);
    });

    tuneTest('picking a model writes it to the plugin config', (tester) async {
      final r = await pump(tester);
      await pickScope(tester, 'All songs');
      await tapText(tester, 'Flash');
      await tapRow(tester, 'Pro');
      await tester.pump(const Duration(milliseconds: 100));
      expect(r.plugins.configWrites, [(testTranslatePluginId, 'model', 'pro')]);
      expect(find.text('Pro'), findsOneWidget);
      // A saved pick does not make failed translations start over.
      expect(r.jobs.cleared, isEmpty);
    });

    tuneTest('a refused pick goes back and shows the reason', (tester) async {
      final plugins = FakePlugins()..configResult = PluginConfigWrite.tooLarge;
      await pump(tester, plugins: plugins);
      await pickScope(tester, 'All songs');
      await tapText(tester, 'Flash');
      await tapRow(tester, 'Pro');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Flash'), findsOneWidget);
      expect(
        find.text("The plugin's settings are too large to save."),
        findsOneWidget,
      );
    });

    tuneTest('a saved model the plugin dropped reads as no longer '
        'supported', (tester) async {
      await pump(tester, stored: {'model': 'retired'});
      expect(find.text('retired (no longer supported)'), findsOneWidget);
    });

    tuneTest('a value written from Settings shows at once', (tester) async {
      final r = await pump(tester);
      expect(find.text('Literal'), findsWidgets);
      r.plugins.emitStored({'style': 'poetic'});
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Poetic'), findsWidgets);
    });

    tuneTest('a long list is searched by title and subtitle', (tester) async {
      final many = _model.withOptions([
        for (var i = 1; i <= 9; i++)
          PluginConfigOption(
            value: 'm$i',
            title: 'Model $i',
            subtitle: i == 7 ? 'special tier' : null,
          ),
      ]);
      await pump(
        tester,
        config: [many, _style, _note],
        stored: {'model': 'm1'},
      );
      await tapText(tester, 'Model 1');
      await tester.enterText(find.byType(TextField).last, 'special');
      await tester.pump();
      expect(find.widgetWithText(SelectionRow, 'Model 7'), findsOneWidget);
      expect(find.widgetWithText(SelectionRow, 'Model 2'), findsNothing);
    });

    tuneTest('a model the user added is tagged, can be picked and has no '
        'add or delete', (tester) async {
      final r = await pump(
        tester,
        stored: {
          'model.custom': [
            {'value': 'my-model', 'subtitle': 'Mine'},
          ],
        },
      );
      await pickScope(tester, 'All songs');
      await tapText(tester, 'Flash');
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Add model…'), findsNothing);
      expect(find.byTooltip('Remove model'), findsNothing);
      await tapRow(tester, 'my-model');
      await tester.pump(const Duration(milliseconds: 100));
      expect(r.plugins.configWrites, [
        (testTranslatePluginId, 'model', 'my-model'),
      ]);
    });

    tuneTest('without a model the box is replaced by a way to the '
        'plugin settings', (tester) async {
      final r = await pump(
        tester,
        config: [_model.withOptions(const []), _style, _note],
      );
      expect(find.text('No models yet'), findsOneWidget);
      expect(find.text('Style'), findsOneWidget);
      await tapText(tester, 'Open plugin settings');
      expect(find.byType(TranslationAiTuneModal), findsNothing);
      expect(find.byType(LyricsTranslationModal), findsNothing);
      expect(r.h.container.read(nowPlayingOpenProvider), isFalse);
      expect(r.h.visitedRoutes, [
        translationPluginRoute(testTranslatePluginId),
      ]);
    });
  });

  group('failed translations', () {
    tuneTest('a pick or a note on a failed song sends nothing', (tester) async {
      final r = await pump(
        tester,
        state: TranslationFailed(
          fakeTranslationInfo(),
          testTranslatePlugin,
          TranslationFailureKind.network,
        ),
      );
      await pickScope(tester, 'All songs');
      await tapText(tester, 'Flash');
      await tapRow(tester, 'Pro');
      await tester.enterText(find.byType(TextField), 'dark mood');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(seconds: 1));
      expect(r.plugins.configWrites, isNotEmpty);
      expect(r.jobs.cleared, isEmpty);
      expect(r.runner.calls, isEmpty);
      expect(r.h.fake.retranslateCalls, 0);
      expect(r.h.fake.retryCalls, 0);
    });
  });

  group('the note for this song', () {
    tuneTest('is always there, empty at first', (tester) async {
      await pump(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
    });

    tuneTest('Enter saves it for the song that was playing at opening', (
      tester,
    ) async {
      final r = await pump(tester);
      await tester.enterText(find.byType(TextField), 'sad and slow');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 100));
      expect(await savedNote(tester, r, 'hash'), 'sad and slow');
      // Another song has no note.
      expect(await savedNote(tester, r, 'other'), isNull);
    });

    tuneTest('leaving the box saves it', (tester) async {
      final r = await pump(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'blur me');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 100));
      expect(await savedNote(tester, r, 'hash'), 'blur me');
    });

    tuneTest('a note written elsewhere shows while the box is idle', (
      tester,
    ) async {
      final r = await pump(tester);
      await tester.runAsync(
        () => r.db.setSongTranslationInstruction('hash', 'kept'),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('kept'), findsOneWidget);
    });

    Future<void> settleClose(WidgetTester tester) async {
      await settleModal(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }

    tuneTest('when the song changes the unsaved note and pick go to the old '
        'song and nothing is translated again', (tester) async {
      final r = await pump(tester);
      await pickScope(tester, 'All songs');
      await tapText(tester, 'Flash');
      await tapRow(tester, 'Pro');
      await tester.enterText(find.byType(TextField), 'for the old song');
      // The note was never left; the next song arrives with no gap between.
      r.h.fake.emit(TranslationOff(fakeTranslationInfo(hash: 'next')));
      await settleClose(tester);

      expect(find.byType(TranslationAiTuneModal), findsNothing);
      expect(find.byType(LyricsTranslationModal), findsNothing);
      expect(await savedNote(tester, r, 'hash'), 'for the old song');
      expect(await savedNote(tester, r, 'next'), isNull);
      expect(r.plugins.configWrites, [(testTranslatePluginId, 'model', 'pro')]);
      expect(r.h.fake.retranslateCalls, 0);
      expect(r.runner.calls, isEmpty);
    });

    tuneTest('a pick still being saved when the track goes is saved', (
      tester,
    ) async {
      final plugins = FakePlugins()..configGate = Completer<void>();
      final r = await pump(tester, plugins: plugins);
      await pickScope(tester, 'All songs');
      await tapText(tester, 'Flash');
      await tapRow(tester, 'Pro');
      r.h.fake.emit(const TranslationUnavailable());
      await settleClose(tester);
      plugins.configGate!.complete();
      await settleClose(tester);

      expect(find.byType(TranslationAiTuneModal), findsNothing);
      expect(plugins.configWrites, [(testTranslatePluginId, 'model', 'pro')]);
      expect(r.runner.calls, isEmpty);
    });

    for (final (name, close) in <(String, Future<void> Function(WidgetTester))>[
      ('the close button', (t) => t.tap(find.byTooltip('Close').last)),
      ('the scrim', (t) => t.tapAt(const Offset(5, 5))),
      ('Escape', (t) => t.sendKeyEvent(LogicalKeyboardKey.escape)),
    ]) {
      tuneTest('closing with $name saves the unsaved note', (tester) async {
        final r = await pump(tester);
        await tester.enterText(find.byType(TextField), 'kept on close');
        await close(tester);
        await settleClose(tester);

        expect(find.byType(TranslationAiTuneModal), findsNothing);
        expect(await savedNote(tester, r, 'hash'), 'kept on close');
      });
    }

    tuneTest('text typed while a save runs is saved when the box closes', (
      tester,
    ) async {
      final r = await pump(tester);
      await tester.enterText(find.byType(TextField), 'one');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.enterText(find.byType(TextField), 'one two');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleClose(tester);

      expect(await savedNote(tester, r, 'hash'), 'one two');
    });
  });

  group('where a pick goes', () {
    const now = 7000;
    final clock = translationClockProvider.overrideWithValue(() => now);

    Future<List<SongTranslationOverride>> songRows(
      WidgetTester tester,
      _Rig r,
    ) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      return (await tester.runAsync(
        () => r.db.watchSongTranslationOverrides().first,
      ))!;
    }

    tuneTest('opens on This song, with the three segments', (tester) async {
      await pump(tester, extra: [clock]);
      final seg = tester.widget<SegmentedButton<TranslationScope>>(
        find.byType(SegmentedButton<TranslationScope>),
      );
      expect(seg.selected, {TranslationScope.song});
      expect(seg.segments.map((s) => s.value), [
        TranslationScope.song,
        TranslationScope.queue,
        TranslationScope.all,
      ]);
    });

    tuneTest('This song stores the service, model, style and time for the '
        'song only', (tester) async {
      final r = await pump(tester, extra: [clock]);
      await tapText(tester, 'Flash');
      await tapRow(tester, 'Pro');
      await tester.pump(const Duration(milliseconds: 100));

      final rows = await songRows(tester, r);
      expect(rows, hasLength(1));
      expect(rows.single.hash, 'hash');
      expect(rows.single.service, testTranslatePluginId);
      expect(jsonDecode(rows.single.tuneJson!), {
        'model': 'pro',
        'style': 'literal',
      });
      expect(rows.single.chosenAt, now);
      expect(r.plugins.configWrites, isEmpty);
      expect(r.h.prefs.allChosenAt, isNull);
      expect(find.text('Pro'), findsOneWidget);
    });

    tuneTest('a second pick keeps the first one in the song tune', (
      tester,
    ) async {
      final r = await pump(tester, extra: [clock]);
      await tapText(tester, 'Flash');
      await tapRow(tester, 'Pro');
      await tester.pump(const Duration(milliseconds: 100));
      await songRows(tester, r);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(inTune('Literal'));
      await settleModal(tester);
      await tapRow(tester, 'Poetic');
      await tester.pump(const Duration(milliseconds: 100));

      final rows = await songRows(tester, r);
      expect(jsonDecode(rows.single.tuneJson!), {
        'model': 'pro',
        'style': 'poetic',
      });
    });

    tuneTest('two picks in a row, the first still being written, store both '
        'keys', (tester) async {
      final r = await pump(tester, extra: [clock]);
      await tapText(tester, 'Flash');
      await tapRow(tester, 'Pro');
      // No wait for the database between the two picks.
      await tester.tap(inTune('Literal'));
      await settleModal(tester);
      await tapRow(tester, 'Poetic');

      final rows = await songRows(tester, r);
      expect(jsonDecode(rows.single.tuneJson!), {
        'model': 'pro',
        'style': 'poetic',
      });
    });

    tuneTest('a model picked for all songs after one for this song is not '
        'undone by the next song pick', (tester) async {
      final r = await pump(
        tester,
        stored: {
          'model.custom': [
            {'value': 'mine'},
          ],
        },
        extra: [clock],
      );
      await tapText(tester, 'Flash');
      await tapRow(tester, 'Pro');
      await songRows(tester, r);
      await tester.pump(const Duration(milliseconds: 100));
      await pickScope(tester, 'All songs');
      await tester.tap(inTune('Flash'));
      await settleModal(tester);
      await tapRow(tester, 'mine');
      await tester.pump(const Duration(milliseconds: 100));
      await pickScope(tester, 'This song');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(inTune('Literal'));
      await settleModal(tester);
      await tapRow(tester, 'Poetic');

      final rows = await songRows(tester, r);
      expect(jsonDecode(rows.single.tuneJson!), {
        'model': 'mine',
        'style': 'poetic',
      });
    });

    tuneTest('two queue picks in a row store both keys', (tester) async {
      final r = await pump(tester, extra: [clock]);
      await pickScope(tester, 'Queue');
      await tapText(tester, 'Flash');
      await tapRow(tester, 'Pro');
      await tester.tap(inTune('Literal'));
      await settleModal(tester);
      await tapRow(tester, 'Poetic');
      expect(r.h.container.read(queueTranslationChoiceProvider)?.tune, {
        'model': 'pro',
        'style': 'poetic',
      });
    });

    tuneTest('when the song changes a pick for this song stays with the song '
        'the modal opened on', (tester) async {
      final r = await pump(tester, extra: [clock]);
      await tapText(tester, 'Flash');
      await tapRow(tester, 'Pro');
      r.h.fake.emit(TranslationOff(fakeTranslationInfo(hash: 'next')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final rows = await songRows(tester, r);
      expect(rows.map((row) => row.hash), ['hash']);
      expect(jsonDecode(rows.single.tuneJson!)['model'], 'pro');
    });

    tuneTest('when the song changes a queue pick still goes to the queue', (
      tester,
    ) async {
      final r = await pump(tester, extra: [clock]);
      await pickScope(tester, 'Queue');
      await tapText(tester, 'Flash');
      await tapRow(tester, 'Pro');
      r.h.fake.emit(TranslationOff(fakeTranslationInfo(hash: 'next')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        r.h.container.read(queueTranslationChoiceProvider)?.tune['model'],
        'pro',
      );
      expect(await songRows(tester, r), isEmpty);
    });

    tuneTest('a pick for all songs left unsaved when the modal closes still '
        'makes the plugin the default', (tester) async {
      final plugins = FakePlugins()..configGate = Completer<void>();
      final r = await pump(
        tester,
        plugins: plugins,
        settings: _onPrefs.copyWith(allChosenAt: 1),
        extra: [clock],
      );
      await pickScope(tester, 'All songs');
      await tapText(tester, 'Flash');
      await tapRow(tester, 'Pro');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleModal(tester);
      plugins.configGate!.complete();
      await tester.pump(const Duration(milliseconds: 100));
      expect(r.h.prefs.allChosenAt, now);
    });

    tuneTest('Queue stores the tune in the session choice only', (
      tester,
    ) async {
      final r = await pump(tester, extra: [clock]);
      await pickScope(tester, 'Queue');
      await tapText(tester, 'Flash');
      await tapRow(tester, 'Pro');
      await tester.pump(const Duration(milliseconds: 100));

      final choice = r.h.container.read(queueTranslationChoiceProvider);
      expect(choice?.service, testTranslatePlugin);
      expect(choice?.tune, {'model': 'pro', 'style': 'literal'});
      expect(choice?.chosenAt, now);
      expect(await songRows(tester, r), isEmpty);
      expect(r.plugins.configWrites, isEmpty);
    });

    tuneTest('All songs writes the shared config and makes the plugin the '
        'default', (tester) async {
      final r = await pump(
        tester,
        settings: _onPrefs.copyWith(allChosenAt: 1),
        extra: [clock],
      );
      await pickScope(tester, 'All songs');
      await tapText(tester, 'Flash');
      await tapRow(tester, 'Pro');
      await tester.pump(const Duration(milliseconds: 100));

      expect(r.plugins.configWrites, [(testTranslatePluginId, 'model', 'pro')]);
      expect(r.h.prefs.service, testTranslatePlugin);
      expect(r.h.prefs.allChosenAt, now);
      expect(await songRows(tester, r), isEmpty);
      expect(r.h.container.read(queueTranslationChoiceProvider), isNull);
    });

    tuneTest('a refused shared config leaves the default stamp alone', (
      tester,
    ) async {
      final plugins = FakePlugins()..configResult = PluginConfigWrite.tooLarge;
      final r = await pump(
        tester,
        plugins: plugins,
        settings: _onPrefs.copyWith(allChosenAt: 1),
        extra: [clock],
      );
      await pickScope(tester, 'All songs');
      await tapText(tester, 'Flash');
      await tapRow(tester, 'Pro');
      await tester.pump(const Duration(milliseconds: 100));
      expect(r.h.prefs.allChosenAt, 1);
    });

    tuneTest('the box shows the song tune, and the shared config under All '
        'songs', (tester) async {
      final r = await pump(
        tester,
        openTune: false,
        stored: {'model': 'flash'},
        extra: [clock],
      );
      await tester.runAsync(
        () => r.db.setSongTranslationTune(
          'hash',
          service: testTranslatePluginId,
          tune: {'model': 'pro', 'style': 'poetic'},
          chosenAt: 10,
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await openTuneModal(tester);
      expect(inTune('Pro'), findsOneWidget);
      expect(inTune('Poetic'), findsOneWidget);

      await pickScope(tester, 'All songs');
      expect(inTune('Flash'), findsOneWidget);
      expect(inTune('Literal'), findsOneWidget);
    });

    tuneTest('using the default again leaves the shared config in the box', (
      tester,
    ) async {
      final r = await pump(
        tester,
        openTune: false,
        stored: {'model': 'flash'},
        extra: [clock],
      );
      await tester.runAsync(
        () => r.db.setSongTranslationTune(
          'hash',
          service: testTranslatePluginId,
          tune: {'model': 'pro', 'style': 'poetic'},
          chosenAt: 10,
        ),
      );
      // The "Use the default for this song" row stores this.
      await tester.runAsync(
        () => r.db.setSongTranslationService('hash', null, chosenAt: null),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await openTuneModal(tester);
      expect(inTune('Flash'), findsOneWidget);
      expect(inTune('Literal'), findsOneWidget);
      expect(inTune('Pro'), findsNothing);
    });

    tuneTest('the queue segment is locked when the queue is empty', (
      tester,
    ) async {
      final r = await pump(tester, openTune: false, extra: [clock]);
      await r.h.container.read(playerServiceProvider.notifier).removeTrack(0);
      await tester.pump(const Duration(milliseconds: 100));
      await openTuneModal(tester);
      final seg = tester.widget<SegmentedButton<TranslationScope>>(
        find.byType(SegmentedButton<TranslationScope>),
      );
      expect(
        seg.segments
            .firstWhere((s) => s.value == TranslationScope.queue)
            .enabled,
        isFalse,
      );
    });

    tuneTest('the note stays on the song whatever the segment', (tester) async {
      final r = await pump(tester, extra: [clock]);
      await pickScope(tester, 'All songs');
      await tester.enterText(find.byType(TextField), 'for the song');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 100));
      expect(await savedNote(tester, r, 'hash'), 'for the song');
      expect(r.plugins.configWrites, isEmpty);
      expect(await songRows(tester, r), isEmpty);
    });

    tuneTest('a failed song write goes back and shows the reason', (
      tester,
    ) async {
      final r = await pump(tester, extra: [clock]);
      await tester.runAsync(r.db.close);
      await tapText(tester, 'Flash');
      await tapRow(tester, 'Pro');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Flash'), findsOneWidget);
      expect(find.text('Could not save the setting'), findsWidgets);
    });
  });
}
