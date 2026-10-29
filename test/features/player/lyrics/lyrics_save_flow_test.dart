import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics/online/lrc_sidecar_writer.dart';
import 'package:kanaru/core/lyrics/online/lyrics_choice.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_actions.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/core/lyrics/online/lyrics_source_resolution.dart';
import 'package:kanaru/features/player/lyrics/lyrics_action_runner.dart';
import 'package:kanaru/features/player/lyrics/lyrics_save_flow.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

typedef _Call = ({String trackKey, String remoteId, bool replace});

/// Answers `save` from a script and records what it was asked.
class _FakeActions extends OnlineLyricsActions {
  _FakeActions(super.ref, this.script, this.calls, {this.busy = false});

  final bool busy;

  @override
  bool isSaving(String trackKey) => busy;

  final List<LyricsSaveOutcome> script;
  final List<_Call> calls;

  @override
  Future<LyricsSaveOutcome> save(
    LyricsTarget target,
    OnlineLyricsOrigin origin, {
    bool replace = false,
  }) async {
    calls.add((
      trackKey: target.trackKey,
      remoteId: origin.remoteId,
      replace: replace,
    ));
    return script.removeAt(0);
  }
}

const _origin = OnlineLyricsOrigin(
  providerId: 'fake',
  remoteId: 'rec',
  pinned: false,
);

LyricsSourceResolution _source(String uri) => (
  chosen: LyricsChoice.auto,
  effective: LyricsChoice.auto,
  pin: null,
  hasLocal: false,
  status: LyricsFound(
    uri,
    const Lyrics(
      lines: [LyricLine(Duration.zero, 'words')],
      synced: false,
      source: LyricsSource.sidecar,
    ),
    origin: _origin,
  ),
);

LyricsTarget _target(String path, {String? title = 'Night Song'}) =>
    LyricsTarget.fromFields(uri: path, title: title, artist: 'Someone');

void main() {
  var calls = <_Call>[];

  Future<void> open(
    WidgetTester tester,
    List<LyricsSaveOutcome> script, {
    String path = '/m/a.flac',
    bool withSource = true,
    bool busy = false,
  }) async {
    calls = [];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineLyricsActionsProvider.overrideWith(
            (ref) => _FakeActions(ref, script, calls, busy: busy),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => runLyricsSave(
                  LyricsActionRunner.snapshot(
                    context,
                    target: _target(path),
                    source: withSource ? _source(path) : null,
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  /// The flow reads real files between frames: each await of one needs the
  /// real event loop and its continuation needs a pump. Polls in real time
  /// until [until] is on screen, at most 5 s.
  Future<void> settleUntil(WidgetTester tester, Finder until) async {
    final end = DateTime.now().add(const Duration(seconds: 5));
    while (until.evaluate().isEmpty) {
      if (DateTime.now().isAfter(end)) {
        fail('not on screen after 5 s: $until');
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> confirmSave(WidgetTester tester, Finder until) async {
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    await settleUntil(tester, until);
  }

  const outcomes = <(LyricsSaveOutcome, String)>[
    (
      (result: LrcWriteResult.written, kept: null),
      'Lyrics saved as a .lrc file',
    ),
    (
      (result: LrcWriteResult.identical, kept: null),
      'The .lrc file already has these lyrics',
    ),
    (
      (result: LrcWriteResult.outsideLibrary, kept: null),
      'Could not save: the song is outside the library folders',
    ),
    (
      (result: LrcWriteResult.failed, kept: null),
      'Could not save the .lrc file (read-only folder, no space or no permission)',
    ),
    (
      (result: LrcWriteResult.trashFailed, kept: null),
      'Could not move the old file to the trash, so nothing was replaced',
    ),
    (
      (result: LrcWriteResult.trashedNotWritten, kept: null),
      'The old file was moved to the trash but the new one could not be written; restore it from the trash if needed',
    ),
    (
      (result: LrcWriteResult.trashTimedOut, kept: null),
      'The trash did not answer in time; the old file may be in the trash and no new file was written',
    ),
    ((result: LrcWriteResult.nothingToWrite, kept: null), 'No lyrics to save'),
    ((result: null, kept: null), 'No lyrics to save'),
  ];

  for (final (outcome, text) in outcomes) {
    testWidgets('${outcome.result} says: $text', (tester) async {
      await open(tester, [outcome]);
      expect(find.text('Save lyrics'), findsOneWidget);

      await confirmSave(tester, find.text(text));

      expect(find.text(text), findsOneWidget);
      expect(calls.single.replace, isFalse);
    });
  }

  testWidgets('a kept choice adds its reason under the success line', (
    tester,
  ) async {
    await open(tester, [
      (result: LrcWriteResult.written, kept: LyricsChoiceKept.tagPreferred),
    ]);
    await confirmSave(tester, find.text('Lyrics saved as a .lrc file'));

    expect(find.text('Lyrics saved as a .lrc file'), findsOneWidget);
    expect(
      find.text(
        'The song still uses the lyrics you chose because lyrics in tags are preferred',
      ),
      findsOneWidget,
    );
  });

  testWidgets('another file being read says so', (tester) async {
    await open(tester, [
      (result: LrcWriteResult.identical, kept: LyricsChoiceKept.otherFile),
    ]);
    await confirmSave(tester, find.textContaining('reads another lyrics file'));

    expect(
      find.text(
        'The song still uses the lyrics you chose because Kanaru reads another lyrics file of the song',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the tag option is shown but disabled', (tester) async {
    await open(tester, []);

    expect(find.text('.lrc file'), findsOneWidget);
    expect(find.text('In the music tags'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    final tile = tester.widget<RadioListTile<String>>(
      find.widgetWithText(RadioListTile<String>, 'In the music tags'),
    );
    expect(tile.enabled, isFalse);
  });

  testWidgets('Cancel saves nothing', (tester) async {
    await open(tester, []);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(calls, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('an existing file is confirmed by name, then replaced', (
    tester,
  ) async {
    await open(tester, [
      (result: LrcWriteResult.exists, kept: null),
      (result: LrcWriteResult.written, kept: null),
    ]);
    await confirmSave(tester, find.textContaining('moved to the trash'));

    expect(find.text('Replace a.lrc of Night Song?'), findsOneWidget);
    expect(find.textContaining('moved to the trash'), findsOneWidget);
    expect(calls, hasLength(1));

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();

    expect(calls.map((c) => c.replace), [false, true]);
    expect(find.text('Lyrics saved as a .lrc file'), findsOneWidget);
  });

  testWidgets('the replace confirm says the same on every disk', (
    tester,
  ) async {
    await open(tester, [(result: LrcWriteResult.exists, kept: null)]);
    await confirmSave(tester, find.textContaining('moved to the trash'));

    expect(find.text('The old file is moved to the trash.'), findsOneWidget);
  });

  testWidgets('a file that appears during the replace has its own line', (
    tester,
  ) async {
    await open(tester, [
      (result: LrcWriteResult.exists, kept: null),
      (result: LrcWriteResult.exists, kept: null),
    ]);
    await confirmSave(tester, find.text('Replace'));
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();

    expect(
      find.text('Another lyrics file just appeared, so nothing was replaced'),
      findsOneWidget,
    );
  });

  testWidgets('both spellings are named when both exist', (tester) async {
    final dir = Directory.systemTemp.createTempSync('kanaru_flow_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/a.lrc').writeAsStringSync('x');
    File('${dir.path}/a.LRC').writeAsStringSync('y');
    await open(tester, [
      (result: LrcWriteResult.exists, kept: null),
    ], path: '${dir.path}/a.flac');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    await settleUntil(
      tester,
      find.text('Replace a.lrc and a.LRC of Night Song?'),
    );

    expect(find.text('Replace a.lrc and a.LRC of Night Song?'), findsOneWidget);
  });

  testWidgets('Cancel on the replace confirm changes nothing', (tester) async {
    await open(tester, [(result: LrcWriteResult.exists, kept: null)]);
    await confirmSave(tester, find.text('Replace'));

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('saves the song of the snapshot, whatever plays now', (
    tester,
  ) async {
    await open(tester, [(result: LrcWriteResult.written, kept: null)]);
    // The playing song may change while the dialog is open; the runner kept
    // the song of the menu.
    await confirmSave(tester, find.byType(SnackBar));

    expect(calls.single.trackKey, '/m/a.flac');
    expect(calls.single.remoteId, 'rec');
  });

  testWidgets('without a record on screen it says there is nothing', (
    tester,
  ) async {
    await open(tester, [], withSource: false);

    expect(find.text('Save lyrics'), findsNothing);
    expect(find.text('No lyrics to save'), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets('nothing opens while a save of the song runs', (tester) async {
    await open(tester, [], busy: true);

    expect(find.text('Save lyrics'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(calls, isEmpty);
  });

  testWidgets('an error while saving shows the generic error line', (
    tester,
  ) async {
    await open(tester, []);
    // An empty script makes the fake throw on save.
    await confirmSave(tester, find.byType(SnackBar));

    expect(find.byType(SnackBar), findsOneWidget);
  });
}
