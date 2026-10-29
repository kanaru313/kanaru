import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/counting_http_client.dart';
import '../../core/lyrics/online/fake_lyrics_provider.dart';
import '../../core/lyrics/online/lookup_test_harness.dart';

/// A song with no tags: only the file name, which is never searched for.
final _untagged = LyricsTarget.fromFields(
  uri: '/music/track_01.mp3',
  title: 'track_01',
  duration: const Duration(seconds: 200),
);

void main() {
  late FakeLyricsProvider fake;
  late CountingHttpClient client;

  Future<void> open(
    WidgetTester tester,
    LyricsTarget target, {
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    fake = FakeLyricsProvider()..searchResult = [fakeCandidate()];
    client = CountingHttpClient();
    final h = await createHarness([
      LyricsProviderRegistration(fake),
    ], client: client);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showLyricsPicker(
                navigator: Navigator.of(context),
                container: h.container,
                target: target,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    // The consent check and the dialog route resolve on microtasks.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Finder searchButton() =>
      find.widgetWithText(FilledButton, 'Search', skipOffstage: false);

  testWidgets('an untagged song starts with an empty field and a note', (
    tester,
  ) async {
    await open(tester, _untagged);

    expect(
      find.text('Type the artist and title, then press Search'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
    expect(tester.widget<FilledButton>(searchButton()).onPressed, isNull);
    expect(find.textContaining('track_01', skipOffstage: false), findsNothing);

    // Fake time: nothing is sent while the user has not searched.
    await tester.pump(const Duration(seconds: 5));
    expect(fake.searchCalls, 0);
    expect(client.opened, 0);
  });

  testWidgets('a placeholder artist is not prefilled or searched', (
    tester,
  ) async {
    await open(
      tester,
      LyricsTarget.fromFields(
        uri: '/music/track_01.mp3',
        title: 'track_01',
        artist: 'Unknown Artist',
        duration: const Duration(seconds: 200),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
    await tester.pump(const Duration(seconds: 5));
    expect(fake.searchCalls, 0);
    expect(client.opened, 0);
  });

  testWidgets('an artist-only song is prefilled and waits for Search', (
    tester,
  ) async {
    await open(
      tester,
      LyricsTarget.fromFields(
        uri: '/music/track_01.mp3',
        title: 'track_01',
        artist: 'Real Artist',
        duration: const Duration(seconds: 200),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Real Artist');
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(fake.searchCalls, 0);
    expect(client.opened, 0);

    await tester.tap(searchButton());
    for (var i = 0; i < 100 && fake.searchCalls == 0; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
    expect(fake.searchCalls, 1);
  });

  testWidgets('a tagged song searches when the dialog opens', (tester) async {
    await open(tester, fakeTarget);
    for (var i = 0; i < 100 && fake.searchCalls == 0; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
    expect(fake.searchCalls, 1);
  });

  testWidgets('typed text enables Search and searches', (tester) async {
    await open(tester, _untagged);

    await tester.enterText(find.byType(TextField), 'Artist Song');
    await tester.pump();
    expect(tester.widget<FilledButton>(searchButton()).onPressed, isNotNull);
    await tester.tap(searchButton());
    for (var i = 0; i < 100 && fake.searchCalls == 0; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
    await tester.pump(const Duration(seconds: 1));

    expect(fake.searchCalls, 1);
    expect(find.text('Synced'), findsOneWidget);
    expect(
      find.text('Type the artist and title, then press Search'),
      findsNothing,
    );
  });

  testWidgets('a 160-character title at text scale 2 does not overflow', (
    tester,
  ) async {
    final long = LyricsTarget.fromFields(
      uri: '/music/long.mp3',
      title: List.filled(32, 'abcd').join(' ').padRight(160, 'x'),
      artist: 'Artist',
      duration: const Duration(seconds: 200),
    );
    await open(tester, long, textScale: 2);

    expect(tester.takeException(), isNull);
    final song = tester.widget<Text>(find.textContaining('Song: '));
    expect(song.maxLines, 2);
    expect(song.overflow, TextOverflow.ellipsis);
  });
}
