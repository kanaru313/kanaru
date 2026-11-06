import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' hide Track;
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/lyric_translation_queries.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_config_values_provider.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_ai_tune.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/lyrics_translation_modal.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_action_bar.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_ai_tune_modal.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_ai_tune_row.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/shared/widgets/selection_row.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../lyrics_sources/lyrics_sources_harness.dart';
import 'translation_modal_harness.dart';

const _model = PluginConfigField(
  key: 'model',
  title: 'Model',
  mode: PluginConfigMode.select,
  selectFormat: PluginSelectFormat.single,
  defaultValue: 'flash',
  options: [
    PluginConfigOption(value: 'flash', title: 'Flash'),
    PluginConfigOption(value: 'pro', title: 'Pro'),
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
    PluginConfigOption(value: 'natural', title: 'Natural'),
  ],
);
const _note = PluginConfigField(
  key: 'customInstruction',
  title: 'Instruction',
  mode: PluginConfigMode.input,
  inputFormat: PluginInputFormat.text,
);
const _config = [_model, _style, _note];

final _onPrefs = TranslationPrefs(
  show: true,
  service: testTranslatePlugin,
  noticeAcknowledged: {testTranslatePlugin},
);

final _tune = aiTuneOf(PluginKind.aiTranslate, _config)!;

/// The snapshot a job saves when it runs with [stored] and [songNote].
String _snapshot({Map<String, Object?> stored = const {}, String? songNote}) =>
    encodeAiSnapshot(_tune, stored, songNote);

TranslationReady _ready({
  String? settingsJson,
  bool fromOtherService = false,
  bool refreshing = false,
}) => TranslationReady(
  fakeTranslationInfo(),
  testTranslatePlugin,
  'ja',
  const ['The last kiss', 'Tasted like cigarettes'],
  fromOtherService,
  refreshing: refreshing,
  settingsJson: settingsJson,
);

/// A widget test that lets the tree go before it ends: drift closes its query
/// streams on a timer once nothing listens.
void retranslateTest(
  String name,
  Future<void> Function(WidgetTester tester) body,
) => testWidgets(name, (tester) async {
  await body(tester);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 10));
});

class _Rig {
  _Rig(this.h, this.plugins, this.db);

  final TranslationModalHarness h;
  final FakePlugins plugins;
  final LibraryDatabase db;

  /// What the song's note held the moment `retranslate()` was called.
  Future<String?>? noteAtRetranslate;
  int configWritesAtRetranslate = -1;
}

void main() {
  Future<_Rig> pump(
    WidgetTester tester, {
    required LyricsTranslationState state,
    Map<String, Object?> stored = const {},
    FakePlugins? plugins,
    PluginKind kind = PluginKind.aiTranslate,
    Locale locale = const Locale('en'),
    bool openTune = false,
    String? note,
  }) async {
    final fake = (plugins ?? FakePlugins())..stored = stored;
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(db.close));
    if (note != null) {
      await tester.runAsync(
        () => db.setSongTranslationInstruction('hash', note),
      );
    }
    final h = await pumpTranslationModal(
      tester,
      state: state,
      settings: _onPrefs,
      locale: locale,
      pluginOverrides: translatePluginOverrides(
        records: [
          translateRecord(
            testTranslatePluginId,
            name: 'Test AI',
            kind: kind,
            config: _config,
          ),
        ],
      ),
      overrides: [
        lyricsPluginsControllerProvider.overrideWithValue(fake),
        pluginStoredConfigProvider.overrideWith(
          (ref, id) => fake.storedStream(id),
        ),
        libraryDatabaseProvider.overrideWithValue(db),
      ],
    );
    final rig = _Rig(h, fake, db);
    h.fake.onRetranslate = () {
      rig.configWritesAtRetranslate = fake.configWrites.length;
      rig.noteAtRetranslate = db.songTranslationInstruction('hash');
    };
    await tester.pump(const Duration(milliseconds: 50));
    if (openTune) await openTuneModal(tester);
    return rig;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await settleModal(tester);
  }

  Future<void> pickModel(WidgetTester tester, String from, String to) async {
    await tapText(tester, from);
    await tester.tap(find.widgetWithText(InkWell, to).last);
    await settleModal(tester);
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder changedBar() => find.byType(TranslationActionBar);

  group('the bar of the translation modal', () {
    retranslateTest('a version made with the settings now shows no bar', (
      tester,
    ) async {
      await pump(tester, state: _ready(settingsJson: _snapshot()));
      expect(changedBar(), findsNothing);
      await openTuneModal(tester);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Later'), findsNothing);
    });

    retranslateTest('stored values equal to the defaults are no change', (
      tester,
    ) async {
      await pump(
        tester,
        state: _ready(settingsJson: _snapshot()),
        stored: {'model': 'flash', 'style': 'literal'},
      );
      expect(changedBar(), findsNothing);
    });

    retranslateTest('a different model shows the bar and sends nothing', (
      tester,
    ) async {
      final r = await pump(
        tester,
        state: _ready(settingsJson: _snapshot()),
        stored: {'model': 'pro'},
      );
      expect(
        find.text('Differs from the version shown: Flash → Pro'),
        findsOneWidget,
      );
      expect(find.text('Retranslate'), findsOneWidget);
      expect(r.h.fake.retranslateCalls, 0);
      // The model is in the details, not in the row's subtitle (the style).
      await tester.pump(const Duration(seconds: 1));
      final row = find.byType(TranslationAiTuneRow);
      expect(
        find.descendant(of: row, matching: find.text('Literal')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('Pro')),
        findsNothing,
      );
    });

    retranslateTest('a different style and a different note are listed', (
      tester,
    ) async {
      final r = await pump(
        tester,
        state: _ready(settingsJson: _snapshot()),
        stored: {'style': 'natural', 'customInstruction': 'be kind'},
      );
      expect(
        find.text(
          'Differs from the version shown: Literal → Natural · Changed the '
          'note',
        ),
        findsOneWidget,
      );
      expect(r.h.fake.retranslateCalls, 0);
    });

    retranslateTest('the bar button translates again', (tester) async {
      final r = await pump(
        tester,
        state: _ready(settingsJson: _snapshot()),
        stored: {'model': 'pro'},
      );
      await tapText(tester, 'Retranslate');
      expect(r.h.fake.retranslateCalls, 1);
    });

    retranslateTest('no snapshot means no bar', (tester) async {
      await pump(
        tester,
        state: _ready(),
        stored: {'model': 'pro', 'style': 'natural'},
      );
      expect(changedBar(), findsNothing);
    });

    retranslateTest('a version of another service has its own bar only', (
      tester,
    ) async {
      await pump(
        tester,
        state: _ready(settingsJson: _snapshot(), fromOtherService: true),
        stored: {'model': 'pro'},
      );
      expect(find.textContaining('Differs from'), findsNothing);
      expect(changedBar(), findsOneWidget);
      expect(find.textContaining('Translate with'), findsOneWidget);
    });

    retranslateTest('a retranslation under way shows no changed bar', (
      tester,
    ) async {
      await pump(
        tester,
        state: _ready(settingsJson: _snapshot(), refreshing: true),
        stored: {'model': 'pro'},
      );
      expect(find.textContaining('Differs from'), findsNothing);
      expect(changedBar(), findsNothing);
    });

    retranslateTest('a style the plugin dropped reads as no longer '
        'supported and nothing is translated', (tester) async {
      final r = await pump(
        tester,
        state: _ready(settingsJson: '{"model":"flash","style":"retired"}'),
      );
      expect(
        find.text(
          'Differs from the version shown: retired (no longer supported) → '
          'Literal',
        ),
        findsOneWidget,
      );
      expect(r.h.fake.retranslateCalls, 0);
    });

    retranslateTest('a note saved for another song is no change', (
      tester,
    ) async {
      final r = await pump(tester, state: _ready(settingsJson: _snapshot()));
      await tester.runAsync(
        () => r.db.setSongTranslationInstruction('other', 'elsewhere'),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(changedBar(), findsNothing);
    });

    retranslateTest('a note saved for this song shows the bar', (tester) async {
      final r = await pump(tester, state: _ready(settingsJson: _snapshot()));
      await tester.runAsync(
        () => r.db.setSongTranslationInstruction('hash', 'sad'),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text('Differs from the version shown: Changed the note'),
        findsOneWidget,
      );
    });

    retranslateTest('a song note the version was made with is no change, '
        'also while the note loads', (tester) async {
      await pump(
        tester,
        state: _ready(settingsJson: _snapshot(songNote: 'sad')),
        note: 'sad',
      );
      expect(changedBar(), findsNothing);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(changedBar(), findsNothing);
    });

    retranslateTest('a failed retranslation keeps the changed bar away', (
      tester,
    ) async {
      final state = TranslationReady(
        fakeTranslationInfo(),
        testTranslatePlugin,
        'ja',
        const ['a', 'b'],
        false,
        retranslateFailure: TranslationFailureKind.network,
        settingsJson: _snapshot(),
      );
      await pump(tester, state: state, stored: {'model': 'pro'});
      expect(find.textContaining('Differs from'), findsNothing);
    });

    retranslateTest('Vietnamese bar', (tester) async {
      await pump(
        tester,
        state: _ready(settingsJson: _snapshot()),
        stored: {'model': 'pro'},
        locale: const Locale('vi'),
      );
      expect(find.text('Khác bản đang hiện: Flash → Pro'), findsOneWidget);
      expect(find.text('Dịch lại'), findsWidgets);
    });
  });

  group('the preview card', () {
    retranslateTest('names the style the version was made with', (
      tester,
    ) async {
      await pump(
        tester,
        state: _ready(settingsJson: _snapshot(stored: {'style': 'natural'})),
        stored: {'style': 'natural'},
      );
      expect(find.text('Translated by Test AI · Natural'), findsOneWidget);
    });

    retranslateTest('keeps showing the old style after the setting moves', (
      tester,
    ) async {
      await pump(
        tester,
        state: _ready(settingsJson: _snapshot()),
        stored: {'style': 'natural'},
      );
      expect(find.text('Translated by Test AI · Literal'), findsOneWidget);
    });

    retranslateTest('without a snapshot style it is the plain credit', (
      tester,
    ) async {
      await pump(tester, state: _ready());
      expect(find.text('Translated by Test AI'), findsOneWidget);
    });

    retranslateTest('a plain translate plugin is the plain credit', (
      tester,
    ) async {
      await pump(
        tester,
        state: _ready(settingsJson: _snapshot()),
        kind: PluginKind.translate,
      );
      expect(find.text('Translated by Test AI'), findsOneWidget);
    });

    retranslateTest('Vietnamese credit', (tester) async {
      await pump(
        tester,
        state: _ready(settingsJson: _snapshot()),
        locale: const Locale('vi'),
      );
      expect(find.text('Dịch bởi Test AI · Literal'), findsOneWidget);
    });
  });

  group('the tune modal footer', () {
    retranslateTest('a changed model shows Later and Retranslate', (
      tester,
    ) async {
      final r = await pump(
        tester,
        state: _ready(settingsJson: _snapshot()),
        openTune: true,
      );
      expect(find.text('Done'), findsOneWidget);
      await pickModel(tester, 'Flash', 'Pro');
      expect(r.plugins.configWrites, [(testTranslatePluginId, 'model', 'pro')]);
      expect(find.text('Done'), findsNothing);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Retranslate'), findsWidgets);
    });

    retranslateTest('Later closes, sends nothing, and the parent has the '
        'bar', (tester) async {
      final r = await pump(
        tester,
        state: _ready(settingsJson: _snapshot()),
        openTune: true,
      );
      await pickModel(tester, 'Flash', 'Pro');
      await tapText(tester, 'Later');
      expect(find.byType(TranslationAiTuneModal), findsNothing);
      expect(find.byType(LyricsTranslationModal), findsOneWidget);
      expect(r.h.fake.retranslateCalls, 0);
      expect(
        find.text('Differs from the version shown: Flash → Pro'),
        findsOneWidget,
      );
    });

    retranslateTest('Retranslate closes the modal once and the parent '
        'translates', (tester) async {
      final r = await pump(
        tester,
        state: _ready(settingsJson: _snapshot()),
        openTune: true,
      );
      await pickModel(tester, 'Flash', 'Pro');
      await tester.tap(find.widgetWithText(FilledButton, 'Retranslate').last);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Retranslate').last,
        warnIfMissed: false,
      );
      await settleModal(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(r.h.fake.retranslateCalls, 1);
      expect(find.byType(TranslationAiTuneModal), findsNothing);
      // The pick was saved first; the Now Playing screen stays.
      expect(r.configWritesAtRetranslate, 1);
      expect(r.h.container.read(nowPlayingOpenProvider), isTrue);
    });

    retranslateTest('a note typed and not left still counts and is saved '
        'before the translation', (tester) async {
      final r = await pump(
        tester,
        state: _ready(settingsJson: _snapshot()),
        openTune: true,
      );
      expect(find.text('Done'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'dark mood');
      await tester.pump();
      expect(find.text('Later'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Retranslate').last);
      await settleModal(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(r.h.fake.retranslateCalls, 1);
      expect(await tester.runAsync(() => r.noteAtRetranslate!), 'dark mood');
    });

    retranslateTest('a save refused while Retranslate waits for it keeps the '
        'modal open and translates nothing', (tester) async {
      final plugins = FakePlugins()
        ..configGate = Completer<void>()
        ..configResult = PluginConfigWrite.tooLarge;
      final r = await pump(
        tester,
        state: _ready(settingsJson: _snapshot()),
        plugins: plugins,
        openTune: true,
      );
      await pickModel(tester, 'Flash', 'Pro');
      await tester.tap(find.widgetWithText(FilledButton, 'Retranslate').last);
      await tester.pump();
      plugins.configGate!.complete();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TranslationAiTuneModal), findsOneWidget);
      expect(r.h.fake.retranslateCalls, 0);
      expect(
        find.text("The plugin's settings are too large to save."),
        findsOneWidget,
      );
      // Unlocked again, back on the saved model.
      expect(find.text('Flash'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    retranslateTest('a save that never ends gives up after three seconds', (
      tester,
    ) async {
      final plugins = FakePlugins()..configGate = Completer<void>();
      final r = await pump(
        tester,
        state: _ready(settingsJson: _snapshot()),
        plugins: plugins,
        openTune: true,
      );
      await pickModel(tester, 'Flash', 'Pro');
      await tester.tap(find.widgetWithText(FilledButton, 'Retranslate').last);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      await tester.pump(const Duration(seconds: 4));
      expect(find.byType(TranslationAiTuneModal), findsOneWidget);
      expect(r.h.fake.retranslateCalls, 0);
      expect(find.text('Could not save the setting'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Retranslate').last,
            )
            .onPressed,
        isNotNull,
      );
      plugins.configGate!.complete();
      await tester.pump(const Duration(milliseconds: 100));
    });

    retranslateTest('Escape still closes and saves without translating', (
      tester,
    ) async {
      final r = await pump(
        tester,
        state: _ready(settingsJson: _snapshot()),
        openTune: true,
      );
      await pickModel(tester, 'Flash', 'Pro');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleModal(tester);
      expect(r.h.fake.retranslateCalls, 0);
      expect(find.byType(TranslationAiTuneModal), findsNothing);
    });
    retranslateTest('Escape while the save is held leaves the parent and '
        'translates nothing', (tester) async {
      final plugins = FakePlugins()..configGate = Completer<void>();
      final r = await pump(
        tester,
        state: _ready(settingsJson: _snapshot()),
        plugins: plugins,
        openTune: true,
      );
      await pickModel(tester, 'Flash', 'Pro');
      await tester.tap(find.widgetWithText(FilledButton, 'Retranslate').last);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 20));
      plugins.configGate!.complete();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TranslationAiTuneModal), findsNothing);
      expect(find.byType(LyricsTranslationModal), findsOneWidget);
      expect(r.h.fake.retranslateCalls, 0);
    });

    retranslateTest('no picker opens while the save is held', (tester) async {
      final plugins = FakePlugins()..configGate = Completer<void>();
      await pump(
        tester,
        state: _ready(settingsJson: _snapshot()),
        plugins: plugins,
        openTune: true,
      );
      await pickModel(tester, 'Flash', 'Pro');
      await tester.tap(find.widgetWithText(FilledButton, 'Retranslate').last);
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(TranslationAiTuneModal),
          matching: find.text('Literal'),
        ),
        warnIfMissed: false,
      );
      await settleModal(tester);
      expect(find.widgetWithText(SelectionRow, 'Natural'), findsNothing);
      plugins.configGate!.complete();
      await tester.pump(const Duration(milliseconds: 600));
    });

    retranslateTest('a track change while the save is held leaves Now '
        'Playing open', (tester) async {
      final plugins = FakePlugins()..configGate = Completer<void>();
      final r = await pump(
        tester,
        state: _ready(settingsJson: _snapshot()),
        plugins: plugins,
        openTune: true,
      );
      await pickModel(tester, 'Flash', 'Pro');
      await tester.tap(find.widgetWithText(FilledButton, 'Retranslate').last);
      await tester.pump();
      r.h.fake.emit(TranslationOff(fakeTranslationInfo(hash: 'next')));
      await tester.pump(const Duration(milliseconds: 20));
      plugins.configGate!.complete();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(LyricsTranslationModal), findsNothing);
      expect(r.h.container.read(nowPlayingOpenProvider), isTrue);
      expect(r.h.fake.retranslateCalls, 0);
    });

    retranslateTest('an earlier refused pick, reverted, does not stop '
        'Retranslate when a note is dirty: it uses the saved model', (
      tester,
    ) async {
      final plugins = FakePlugins()..configResult = PluginConfigWrite.tooLarge;
      final r = await pump(
        tester,
        state: _ready(settingsJson: _snapshot()),
        plugins: plugins,
        openTune: true,
      );
      await pickModel(tester, 'Flash', 'Pro');
      await tester.enterText(find.byType(TextField), 'note');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Retranslate').last);
      await settleModal(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(r.h.fake.retranslateCalls, 1);
      expect(plugins.stored['model'], isNull);
      expect(await tester.runAsync(() => r.noteAtRetranslate!), 'note');
    });
  });
}

Future<void> openTuneModal(WidgetTester tester) async {
  await tester.tap(find.text('AI tuning'));
  await settleModal(tester);
}
