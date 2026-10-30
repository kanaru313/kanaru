import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/online_lyrics_notice_dialog.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late ProviderContainer container;
  bool? answer;

  OnlineLyricsPrefs currentPrefs() =>
      container.read(settingsProvider).onlineLyrics;

  /// A button that runs [action] with the navigator and container only.
  Future<void> pump(
    WidgetTester tester, {
    bool auto = false,
    OnlineLyricsPrefs prefs = const OnlineLyricsPrefs(),
    Locale locale = const Locale('en'),
    bool unmountCaller = false,
  }) async {
    answer = null;
    container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(
          AppSettings(onlineLyrics: prefs),
        ),
      ],
    );
    addTearDown(container.dispose);
    final showCaller = ValueNotifier(true);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ValueListenableBuilder<bool>(
          valueListenable: showCaller,
          builder: (context, visible, _) => visible
              ? TextButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final future = confirmOnlineLyricsNotice(
                      navigator,
                      container,
                      auto: auto,
                    );
                    if (unmountCaller) showCaller.value = false;
                    answer = await future;
                  },
                  child: const Text('go'),
                )
              : const SizedBox(),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('an accepted manual consent answers true without a dialog', (
    tester,
  ) async {
    await pump(tester, prefs: const OnlineLyricsPrefs(manualConsent: true));

    expect(answer, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'an automatic consent kept with the switch off turns it on, no dialog',
    (tester) async {
      await pump(
        tester,
        auto: true,
        prefs: const OnlineLyricsPrefs(manualConsent: true, autoConsent: true),
      );

      expect(answer, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(currentPrefs().autoFetch, isTrue);
    },
  );

  testWidgets('manual consent does not satisfy the auto notice', (
    tester,
  ) async {
    await pump(
      tester,
      auto: true,
      prefs: const OnlineLyricsPrefs(manualConsent: true),
    );

    expect(answer, isNull);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('Cancel answers false and writes nothing', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(answer, isFalse);
    expect(currentPrefs(), const OnlineLyricsPrefs());
  });

  testWidgets('dismissing counts as Cancel', (tester) async {
    await pump(tester, auto: true);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(answer, isFalse);
    expect(currentPrefs(), const OnlineLyricsPrefs());
  });

  testWidgets('manual texts and Search accept the manual consent only', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Search lyrics online?'), findsOneWidget);
    expect(
      find.text(
        'Kanaru sends the song title, artist, album and length to the '
        'sources you have turned on. No file names, paths or device '
        'details.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Settings'), findsNothing);
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(answer, isTrue);
    expect(currentPrefs().manualConsent, isTrue);
    expect(currentPrefs().autoConsent, isFalse);
    expect(currentPrefs().autoFetch, isFalse);
  });

  testWidgets('auto texts and Turn on enable auto in one write', (
    tester,
  ) async {
    await pump(tester, auto: true);

    expect(find.text('Find lyrics online automatically?'), findsOneWidget);
    expect(find.textContaining('sources you have turned on'), findsOneWidget);
    expect(
      find.text('You can turn it off in Settings › Lyrics.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();

    expect(answer, isTrue);
    expect(currentPrefs().autoFetch, isTrue);
    expect(currentPrefs().manualConsent, isTrue);
    expect(currentPrefs().autoConsent, isTrue);
  });

  testWidgets('Continue still writes when the caller left meanwhile', (
    tester,
  ) async {
    await pump(tester, auto: true, unmountCaller: true);
    expect(find.text('go'), findsNothing);

    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();

    expect(answer, isTrue);
    expect(currentPrefs().autoFetch, isTrue);
  });

  testWidgets('the dialog is in Vietnamese for the vi locale', (tester) async {
    await pump(tester, auto: true, locale: const Locale('vi'));

    expect(find.text('Tự động tìm lời online?'), findsOneWidget);
    expect(find.text('Bật'), findsOneWidget);
  });
}
