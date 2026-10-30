import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_dialog.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/fake_lyrics_provider.dart';
import '../../core/lyrics/online/lookup_test_harness.dart';

void main() {
  testWidgets('two enabled sources ask for consent once, then open', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await createHarness([
      LyricsProviderRegistration(FakeLyricsProvider(id: 'one')),
      LyricsProviderRegistration(FakeLyricsProvider(id: 'two')),
    ], manualConsent: false);
    final target = LyricsTarget.fromFields(
      uri: '/music/a.mp3',
      title: 'Song',
      artist: 'Artist',
      duration: const Duration(seconds: 200),
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
                target: target,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Search lyrics online?'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Search lyrics online?'), findsNothing);
    expect(find.byType(LyricsPickerDialog), findsOneWidget);
    expect(
      h.container.read(settingsProvider).onlineLyrics.manualConsent,
      isTrue,
    );
  });
}
