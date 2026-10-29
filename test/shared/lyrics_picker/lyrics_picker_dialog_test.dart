import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lrc_sidecar_writer.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_dialog.dart';

import '../../core/lyrics/online/counting_http_client.dart';
import '../../core/lyrics/online/fake_lyrics_provider.dart';
import '../../core/lyrics/online/lookup_test_harness.dart';
import '../../core/lyrics/online/status_test_rig.dart';

/// Answers a search only when a test completes it.
class _HeldProvider extends FakeLyricsProvider {
  final pending = <Completer<List<LyricsCandidate>>>[];

  @override
  Future<List<LyricsCandidate>> search(LyricsQuery query, LyricsHttp http) {
    searchCalls++;
    final c = Completer<List<LyricsCandidate>>();
    pending.add(c);
    return c.future;
  }
}

void main() {
  late FakeLyricsProvider fake;
  late FakeLrcSidecarWriter writer;
  late CountingHttpClient client;
  late LyricsHarness h;

  final synced = fakeCandidate(remoteId: 'good');
  final farPlain = fakeCandidate(
    remoteId: 'far',
    title: 'Song (live)',
    duration: const Duration(seconds: 230),
    body: const LyricsBody(plain: 'plain one\nplain two'),
  );
  final instrumental = fakeCandidate(
    remoteId: 'inst',
    body: const LyricsBody(instrumental: true),
  );
  final noBody = fakeCandidate(remoteId: 'nobody', body: null);

  /// The database answers in real time, so wait for it between frames.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      // A search nobody answers keeps its progress indicator spinning.
      if (fake is _HeldProvider) {
        await tester.pump(const Duration(milliseconds: 100));
      } else {
        await tester.pumpAndSettle();
      }
    }
  }

  Future<void> open(
    WidgetTester tester, {
    bool manualConsent = true,
    bool writeLrc = false,
    List<LyricsCandidate>? found,
    Size window = const Size(1280, 900),
    FakeLyricsProvider? provider,
  }) async {
    tester.view
      ..physicalSize = window
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    fake =
        provider ??
        (FakeLyricsProvider()
          ..searchResult = found ?? [synced, farPlain, instrumental, noBody]);
    writer = FakeLrcSidecarWriter();
    client = CountingHttpClient();
    h = await createHarness(
      [LyricsProviderRegistration(fake)],
      client: client,
      manualConsent: manualConsent,
      writeLrc: writeLrc,
      overrides: [lrcSidecarWriterProvider.overrideWithValue(writer)],
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showLyricsPicker(
                navigator: Navigator.of(context),
                container: h.container,
                target: fakeTarget,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await settle(tester);
  }

  Future<LyricsPinRow?> pin(WidgetTester tester) async {
    final row = await tester.runAsync<LyricsPinRow?>(
      () => h.db.watchLyricsPin(fakeTarget.trackKey).first,
    );
    return row;
  }

  Finder inDialog(String text) =>
      find.descendant(of: find.byType(Dialog), matching: find.text(text));

  testWidgets('Cancel on the notice opens no dialog and sends nothing', (
    tester,
  ) async {
    await open(tester, manualConsent: false);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(find.byType(LyricsPickerDialog), findsNothing);
    expect(fake.searchCalls, 0);
    expect(client.opened, 0);
  });

  testWidgets('Continue on the notice opens the dialog and searches', (
    tester,
  ) async {
    await open(tester, manualConsent: false);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Search'),
      ),
    );
    await settle(tester);

    expect(find.byType(LyricsPickerDialog), findsOneWidget);
    expect(fake.searchCalls, 1);
  });

  testWidgets('shows the prefilled query, badges and a warned length', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Choose lyrics'), findsOneWidget);
    expect(find.text('Song: Song · Artist · 3:20'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Artist Song'), findsOneWidget);
    expect(inDialog('Synced'), findsOneWidget);
    expect(inDialog('Plain'), findsOneWidget);
    expect(inDialog('Instrumental'), findsOneWidget);
    expect(inDialog('Good match'), findsNWidgets(2));
    expect(find.text('±30s'), findsOneWidget);
    expect(
      find.text(
        'Results from fake.example · the lyrics you pick are pinned to this '
        'song',
      ),
      findsOneWidget,
    );

    // The warned row is still selectable and previews without timestamps.
    await tester.tap(find.text('Song (live)'));
    await settle(tester);
    expect(find.text('plain two'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Use these lyrics'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('a result without lyrics cannot be used', (tester) async {
    await open(tester, found: [noBody]);

    await tester.tap(find.text('Song'));
    await settle(tester);

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Use these lyrics'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('synced lyrics preview without time tags', (tester) async {
    await open(tester);

    expect(find.text('hello'), findsOneWidget);
    expect(find.textContaining('[00:01'), findsNothing);
  });

  testWidgets('Use these lyrics pins the lyrics and says so', (tester) async {
    await open(tester);

    await tester.tap(find.text('Use these lyrics'));
    await settle(tester);

    expect(find.byType(LyricsPickerDialog), findsNothing);
    expect(find.text('Lyrics pinned to this song'), findsOneWidget);
    final row = await pin(tester);
    expect(row!.remoteId, 'good');
    expect(row.syncedText, '[00:01.00] hello');
    expect(writer.writes, isEmpty);
  });

  testWidgets('with .lrc saving on, the file is written after the pin', (
    tester,
  ) async {
    await open(tester, writeLrc: true);
    LyricsPinRow? pinAtWrite;
    writer.onWrite = () async {
      pinAtWrite = await h.db.watchLyricsPin(fakeTarget.trackKey).first;
    };

    await tester.tap(find.text('Use these lyrics'));
    await settle(tester);

    expect(writer.writes.single.$1, fakeTarget.path);
    expect(pinAtWrite, isNotNull);
    expect(find.text('Lyrics pinned to this song'), findsOneWidget);
    expect(find.text('Saved as .lrc'), findsOneWidget);
  });

  testWidgets('a song outside the library keeps the pin and says so', (
    tester,
  ) async {
    await open(tester, writeLrc: true);
    writer.result = LrcWriteResult.outsideLibrary;

    await tester.tap(find.text('Use these lyrics'));
    await settle(tester);

    expect(
      find.text('Not saved as .lrc: the song is outside your library folders'),
      findsOneWidget,
    );
    expect((await pin(tester))!.remoteId, 'good');
  });

  testWidgets('an empty search says nothing was found', (tester) async {
    await open(tester, found: const []);

    expect(find.text('No lyrics found. Try other words.'), findsOneWidget);
  });

  testWidgets('a failed search shows the error and Retry searches again', (
    tester,
  ) async {
    await open(tester, found: const []);
    fake.searchResult = const LyricsFetchException(LyricsFetchKind.network);
    await tester.tap(find.text('Search'));
    await settle(tester);
    expect(find.text("Couldn't reach Fake"), findsOneWidget);

    fake.searchResult = [synced];
    await tester.tap(find.text('Retry'));
    await settle(tester);

    expect(find.text("Couldn't reach Fake"), findsNothing);
    expect(inDialog('Synced'), findsOneWidget);
  });

  testWidgets('Escape during a search closes cleanly and pins nothing', (
    tester,
  ) async {
    final held = _HeldProvider();
    await open(tester, provider: held);
    expect(find.byType(LyricsPickerDialog), findsOneWidget);
    expect(held.pending, hasLength(1));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byType(LyricsPickerDialog), findsNothing);
    held.pending.single.complete([synced]);
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(await pin(tester), isNull);
  });

  testWidgets('a small window scrolls instead of overflowing', (tester) async {
    await open(tester, window: const Size(500, 360));

    expect(find.byType(LyricsPickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}
