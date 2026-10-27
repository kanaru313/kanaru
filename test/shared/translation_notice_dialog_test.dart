import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/translation_language_name.dart';
import 'package:kanaru/shared/translation_notice_dialog.dart';
import 'package:kanaru/core/lyrics_translation/translation_language.dart';
import 'package:material_ui/material_ui.dart';

const _google = LyricsTranslationService.google;
const _deepl = LyricsTranslationService.deepl;

void main() {
  late ProviderContainer container;
  bool? answer;

  TranslationPrefs prefs() => container.read(settingsProvider).translation;

  /// A button that runs [action] with its own context and ref.
  Future<void> pump(
    WidgetTester tester,
    Future<void> Function(BuildContext, WidgetRef) action, {
    Set<LyricsTranslationService> acknowledged = const {},
    Locale locale = const Locale('en'),
    Widget Function(Future<void> Function(BuildContext, WidgetRef))? home,
  }) async {
    answer = null;
    container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(
          AppSettings(
            translation: TranslationPrefs(noticeAcknowledged: acknowledged),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home:
              home?.call(action) ??
              Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => action(context, ref),
                  child: const Text('go'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  Future<void> confirm(BuildContext c, WidgetRef r) async =>
      answer = await confirmTranslationNotice(c, r, _google);

  testWidgets('an accepted service answers true without a dialog', (
    tester,
  ) async {
    await pump(tester, confirm, acknowledged: {_google});

    expect(answer, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a new service asks; Cancel answers false and saves nothing', (
    tester,
  ) async {
    await pump(tester, confirm);

    expect(find.text('Lyrics will be sent to Google'), findsOneWidget);
    expect(
      find.textContaining('The text of this song\'s lyrics is sent to Google'),
      findsOneWidget,
    );
    expect(find.textContaining('unofficial'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(answer, isFalse);
    expect(prefs().noticeAcknowledged, isEmpty);
    expect(prefs().show, isFalse);
  });

  testWidgets('Continue answers true but writes nothing itself', (
    tester,
  ) async {
    await pump(tester, confirm);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(answer, isTrue);
    expect(prefs().noticeAcknowledged, isEmpty);
  });

  testWidgets('dismissing the dialog counts as Cancel', (tester) async {
    await pump(tester, confirm);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(answer, isFalse);
  });

  testWidgets('DeepL has no unofficial line', (tester) async {
    await pump(
      tester,
      (c, r) async => answer = await confirmTranslationNotice(c, r, _deepl),
    );

    expect(find.text('Lyrics will be sent to DeepL'), findsOneWidget);
    expect(find.textContaining('unofficial'), findsNothing);
  });

  testWidgets('the dialog is in Vietnamese for the vi locale', (tester) async {
    await pump(tester, confirm, locale: const Locale('vi'));

    expect(find.text('Lời bài hát sẽ được gửi tới Google'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsOneWidget);
  });

  group('enabling with the notice', () {
    Future<void> enable(BuildContext c, WidgetRef r) =>
        enableTranslationWithNotice(c, r, _deepl);

    testWidgets('Continue selects the service, accepts it and shows', (
      tester,
    ) async {
      await pump(tester, enable);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(prefs().show, isTrue);
      expect(prefs().service, _deepl);
      expect(prefs().noticeAcknowledged, {_deepl});
    });

    testWidgets('Cancel leaves the settings as they were', (tester) async {
      await pump(tester, enable);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(prefs().show, isFalse);
      expect(prefs().service, _google);
      expect(prefs().noticeAcknowledged, isEmpty);
    });

    testWidgets('an accepted service turns on at once', (tester) async {
      await pump(tester, enable, acknowledged: {_deepl});

      expect(find.byType(AlertDialog), findsNothing);
      expect(prefs().show, isTrue);
      expect(prefs().service, _deepl);
    });
  });

  testWidgets('Continue still applies after the caller left the tree', (
    tester,
  ) async {
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    await pump(
      tester,
      (c, r) => enableTranslationWithNotice(c, r, _deepl),
      home: (action) => ValueListenableBuilder<bool>(
        valueListenable: shown,
        builder: (context, visible, _) => visible
            ? Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => action(context, ref),
                  child: const Text('go'),
                ),
              )
            : const SizedBox(),
      ),
    );
    shown.value = false;
    await tester.pump();
    expect(find.text('go'), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(prefs().show, isTrue);
    expect(prefs().service, _deepl);
    expect(prefs().noticeAcknowledged, {_deepl});
  });

  group('language names', () {
    test('every language has a name in both app languages', () {
      for (final locale in const [Locale('en'), Locale('vi')]) {
        final l10n = lookupAppLocalizations(locale);
        final names = {
          for (final language in translationLanguages)
            translationLanguageName(l10n, language),
        };
        expect(names.length, translationLanguages.length);
        for (final name in names) {
          expect(name, isNotEmpty);
          expect(name, isNot(name.toUpperCase()), reason: name);
        }
      }
    });

    test('the Chinese scripts are told apart', () {
      final en = lookupAppLocalizations(const Locale('en'));
      expect(
        translationLanguageName(en, translationLanguageFor('zh-Hans')!),
        'Chinese (Simplified)',
      );
      expect(
        translationLanguageName(en, translationLanguageFor('zh-Hant')!),
        'Chinese (Traditional)',
      );
    });
  });
}
