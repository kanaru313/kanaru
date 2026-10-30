import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lrclib_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/online_lyrics_notice_dialog.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final lrclib = LyricsProviderRegistration(LrclibProvider());
  late ProviderContainer container;
  bool? answer;

  OnlineLyricsPrefs prefs() => container.read(settingsProvider).onlineLyrics;

  /// A button that runs [action] with the navigator and container only.
  Future<void> pump(
    WidgetTester tester, {
    bool auto = false,
    Set<String> acknowledged = const {},
    Locale locale = const Locale('en'),
    bool unmountCaller = false,
  }) async {
    answer = null;
    container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(
          AppSettings(
            onlineLyrics: OnlineLyricsPrefs(noticeAcknowledged: acknowledged),
          ),
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
                      lrclib,
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

  testWidgets('an accepted key answers true without a dialog', (tester) async {
    await pump(tester, acknowledged: {lrclib.consentKey});

    expect(answer, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('an auto key kept with the switch off turns it on, no dialog', (
    tester,
  ) async {
    await pump(
      tester,
      auto: true,
      acknowledged: {lrclib.consentKey, lrclib.autoConsentKey},
    );

    expect(answer, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
    expect(prefs().autoFetch, isTrue);
  });

  testWidgets('manual consent does not satisfy the auto notice', (
    tester,
  ) async {
    await pump(tester, auto: true, acknowledged: {lrclib.consentKey});

    expect(answer, isNull);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('Cancel answers false and writes nothing', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(answer, isFalse);
    expect(prefs(), const OnlineLyricsPrefs());
  });

  testWidgets('dismissing counts as Cancel', (tester) async {
    await pump(tester, auto: true);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(answer, isFalse);
    expect(prefs(), const OnlineLyricsPrefs());
  });

  testWidgets('manual texts and Search accept the manual key only', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Search lyrics on LRCLIB?'), findsOneWidget);
    expect(
      find.text(
        'Kanaru sends the song title, artist and length to '
        'lrclib.net, never the album. No file names, paths or device '
        'details.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Settings'), findsNothing);
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(answer, isTrue);
    expect(prefs().noticeAcknowledged, {lrclib.consentKey});
    expect(prefs().autoFetch, isFalse);
  });

  testWidgets('auto texts and Turn on enable auto in one write', (
    tester,
  ) async {
    await pump(tester, auto: true);

    expect(find.text('Find lyrics online automatically?'), findsOneWidget);
    expect(find.textContaining('lrclib.net'), findsOneWidget);
    expect(
      find.text('You can turn it off in Settings › Lyrics.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();

    expect(answer, isTrue);
    expect(prefs().autoFetch, isTrue);
    expect(prefs().noticeAcknowledged, {
      lrclib.consentKey,
      lrclib.autoConsentKey,
    });
  });

  testWidgets('Continue still writes when the caller left meanwhile', (
    tester,
  ) async {
    await pump(tester, auto: true, unmountCaller: true);
    expect(find.text('go'), findsNothing);

    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();

    expect(answer, isTrue);
    expect(prefs().autoFetch, isTrue);
  });

  testWidgets('the dialog is in Vietnamese for the vi locale', (tester) async {
    await pump(tester, auto: true, locale: const Locale('vi'));

    expect(find.text('Tự động tìm lời online?'), findsOneWidget);
    expect(find.text('Bật'), findsOneWidget);
  });
}
