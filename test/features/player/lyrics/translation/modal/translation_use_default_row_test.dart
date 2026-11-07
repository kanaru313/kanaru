import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/lyric_translation_queries.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/queue_translation_choice.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope_providers.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_service_section.dart';
import 'package:kanaru/shared/widgets/selection_row.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_use_default_row.dart';

import 'translation_modal_harness.dart';

const _otherId = 'plugin-111111111111';
const _songText = 'Use the default for this song';
const _queueText = 'Use the default for the queue';

class _SpyQueueChoice extends QueueTranslationChoice {
  int clears = 0;

  @override
  void clear() {
    clears++;
    super.clear();
  }
}

void main() {
  final other = TranslationServiceId.tryParse(_otherId)!;
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  TranslationPrefs prefs({
    TranslationScopePrecedence precedence =
        TranslationScopePrecedence.replaceAll,
    int? allChosenAt,
  }) => TranslationPrefs(
    show: true,
    service: testTranslatePlugin,
    noticeAcknowledged: {testTranslatePlugin, other},
    allChosenAt: allChosenAt,
    scopePrecedence: precedence,
  );

  LyricsTranslationState stateWith(TranslationScope? scope) => TranslationOff(
    fakeTranslationInfo(
      hash: 'h1',
      choice: scope == null
          ? null
          : TranslationChoice(
              service: other,
              scope: scope,
              tune: const {},
              defaultService: testTranslatePlugin,
            ),
    ),
  );

  Future<TranslationModalHarness> pump(
    WidgetTester tester, {
    required TranslationScope? scope,
    TranslationPrefs? settings,
    bool withDb = true,
    int? songAt,
    int? queueAt,
    List<Override> extra = const [],
  }) async {
    final records = [
      translateRecord(testTranslatePluginId, name: 'Test Translate'),
      translateRecord(_otherId, name: 'Other'),
    ];
    final harness = await pumpTranslationModal(
      tester,
      settings: settings ?? prefs(),
      state: stateWith(scope),
      pluginOverrides: translatePluginOverrides(records: records),
      overrides: [
        if (withDb) libraryDatabaseProvider.overrideWithValue(db),
        ...extra,
      ],
    );
    final c = harness.container;
    if (songAt != null) {
      await tester.runAsync(
        () => db.setSongTranslationService('h1', _otherId, chosenAt: songAt),
      );
    }
    if (queueAt != null) {
      c
          .read(queueTranslationChoiceProvider.notifier)
          .set(other, chosenAt: queueAt);
    }
    final sub = c.listen(songTranslationOverridesProvider, (_, _) {});
    addTearDown(sub.close);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    return harness;
  }

  /// Opens the "Translation service" picker from the modal's service row.
  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.byType(TranslationServiceSection));
    await settleModal(tester);
  }

  Future<List<SongTranslationOverride>> rows(WidgetTester tester) => tester
      .runAsync(() => db.watchSongTranslationOverrides().first)
      .then((r) => r!);

  for (final mode in TranslationScopePrecedence.values) {
    group(mode.name, () {
      testWidgets('song tier: the row sits in the picker, not in the modal', (
        tester,
      ) async {
        await pump(
          tester,
          scope: TranslationScope.song,
          settings: prefs(precedence: mode, allChosenAt: 5),
          songAt: 10,
        );
        expect(find.byType(TranslationUseDefaultRow), findsNothing);
        await openPicker(tester);
        expect(find.text(_songText), findsOneWidget);
        expect(find.text(_queueText), findsNothing);
        expect(find.text("Drops the song's service and tune"), findsOneWidget);
        // After the plugin list, before the plugin store row.
        expect(
          tester.getTopLeft(find.text(_songText)).dy,
          lessThan(
            tester.getTopLeft(find.text('Get more translation plugins')).dy,
          ),
        );
        expect(
          tester.getTopLeft(find.text(_songText)).dy,
          greaterThan(tester.getTopLeft(find.byType(SelectionRow).last).dy),
        );
      });

      testWidgets('queue tier: the row clears the queue choice', (
        tester,
      ) async {
        final harness = await pump(
          tester,
          scope: TranslationScope.queue,
          settings: prefs(precedence: mode, allChosenAt: 5),
          queueAt: 10,
        );
        await openPicker(tester);
        expect(find.text(_queueText), findsOneWidget);
        expect(find.text(_songText), findsNothing);
        // The queue row has no second line.
        expect(find.text("Drops the song's service and tune"), findsNothing);

        await tester.tap(find.text(_queueText));
        await settleModal(tester);
        expect(harness.container.read(queueTranslationChoiceProvider), isNull);
        expect(find.text('Translation service'), findsNothing);
      });

      testWidgets('no row when the default tier decides or nothing is known', (
        tester,
      ) async {
        await pump(
          tester,
          scope: TranslationScope.all,
          settings: prefs(precedence: mode),
          songAt: 10,
        );
        await openPicker(tester);
        expect(find.byType(TranslationUseDefaultRow), findsNothing);
      });
    });
  }

  testWidgets('no row while the choice is still loading', (tester) async {
    await pump(tester, scope: null, songAt: 10);
    await openPicker(tester);
    expect(find.byType(TranslationUseDefaultRow), findsNothing);
  });

  testWidgets('no song row without a library database', (tester) async {
    await pump(tester, scope: TranslationScope.song, withDb: false);
    await openPicker(tester);
    expect(find.byType(TranslationUseDefaultRow), findsNothing);
  });

  testWidgets('song tier: a tap removes the service and tune, not the target', (
    tester,
  ) async {
    await pump(tester, scope: TranslationScope.song, songAt: 10);
    await tester.runAsync(() => db.setSongTranslationTarget('h1', 'vi'));
    await tester.runAsync(
      () => db.setSongTranslationInstruction('h1', 'keep it short'),
    );
    await openPicker(tester);
    await tester.tap(find.text(_songText));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    expect(await rows(tester), isEmpty);
    final target = await tester.runAsync(
      () => db.watchSongTranslationTarget('h1').first,
    );
    expect(target, 'vi');
    final note = await tester.runAsync(
      () => db.songTranslationInstruction('h1'),
    );
    expect(note, 'keep it short');
  });

  testWidgets('song tier: a double tap closes only the picker', (tester) async {
    await pump(tester, scope: TranslationScope.song, songAt: 10);
    await openPicker(tester);
    await tester.tap(find.text(_songText));
    await tester.tap(find.text(_songText), warnIfMissed: false);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await settleModal(tester);
    expect(find.text('Translation service'), findsNothing);
    expect(find.byType(TranslationServiceSection), findsOneWidget);
  });

  testWidgets('queue tier: a tap goes through the notifier that also clears '
      'the saved session extra', (tester) async {
    // Clearing the saved value is the notifier's job (tested with it); the
    // row must call exactly that method.
    final spy = _SpyQueueChoice();
    await pump(
      tester,
      scope: TranslationScope.queue,
      queueAt: 10,
      extra: [queueTranslationChoiceProvider.overrideWith(() => spy)],
    );
    expect(spy.clears, 0);
    await openPicker(tester);
    await tester.tap(find.text(_queueText));
    await tester.pump();
    expect(spy.clears, 1);
  });

  testWidgets(
    'song tier: a failed write shows a message and keeps the choice',
    (tester) async {
      await pump(tester, scope: TranslationScope.song, songAt: 10);
      await tester.runAsync(
        () => db.customStatement('DROP TABLE lyric_translation_prefs'),
      );
      await openPicker(tester);
      await tester.tap(find.text(_songText));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(
        find.text("Couldn't save the choice for this song"),
        findsOneWidget,
      );
    },
  );
}
