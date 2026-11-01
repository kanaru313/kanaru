import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/translation_language_name.dart';
import 'package:kanaru/shared/translation_notice_dialog.dart';
import 'package:kanaru/core/lyrics_translation/translation_language.dart';
import 'package:material_ui/material_ui.dart';

import '../core/lyrics_translation/fake_plugin_runner.dart';

const _google = TranslationServiceId.google;

void main() {
  late ProviderContainer container;
  bool? answer;

  TranslationPrefs prefs() => container.read(settingsProvider).translation;

  /// A button that runs [action] with its own context and ref.
  Future<void> pump(
    WidgetTester tester,
    Future<void> Function(BuildContext, WidgetRef) action, {
    Set<TranslationServiceId> acknowledged = const {},
    Locale locale = const Locale('en'),
    Widget Function(Future<void> Function(BuildContext, WidgetRef))? home,
    List<Override> overrides = const [],
  }) async {
    answer = null;
    container = ProviderContainer(
      overrides: [
        ...overrides,
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

  group('a plugin service', () {
    const id = 'plugin-abc123def456';
    final plugin = TranslationServiceId.tryParse(id)!;
    Future<void> confirmPlugin(BuildContext c, WidgetRef r) async =>
        answer = await confirmTranslationNotice(c, r, plugin);

    List<Override> records(String name) => [
      lyricsPluginRecordsProvider.overrideWithValue([
        translateRecord(
          id,
          name: name,
          hosts: const ['a.example', 'b.example'],
        ),
      ]),
    ];

    testWidgets('names the plugin and lists its hosts', (tester) async {
      await pump(tester, confirmPlugin, overrides: records('Gemini'));

      expect(
        find.text('Lyrics will be sent to the plugin Gemini'),
        findsOneWidget,
      );
      expect(find.textContaining('song title and artist'), findsOneWidget);
      expect(find.textContaining('does not control'), findsOneWidget);
      expect(find.text('a.example'), findsOneWidget);
      expect(find.text('b.example'), findsOneWidget);
      expect(find.textContaining('unofficial'), findsNothing);
    });

    testWidgets('a plugin named Google is not shown as Google', (tester) async {
      await pump(tester, confirmPlugin, overrides: records('Google'));

      expect(
        find.text('Lyrics will be sent to the plugin Google (plugin)'),
        findsOneWidget,
      );
      expect(find.textContaining('unofficial'), findsNothing);
    });

    testWidgets('accepting Google does not accept the plugin', (tester) async {
      await pump(
        tester,
        confirmPlugin,
        acknowledged: {_google},
        overrides: records('Gemini'),
      );

      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

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

  testWidgets('the dialog is in Vietnamese for the vi locale', (tester) async {
    await pump(tester, confirm, locale: const Locale('vi'));

    expect(find.text('Lời bài hát sẽ được gửi tới Google'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsOneWidget);
  });

  group('enabling with the notice', () {
    Future<void> enable(BuildContext c, WidgetRef r) =>
        enableTranslationWithNotice(c, r, _google);

    testWidgets('Continue selects the service, accepts it and shows', (
      tester,
    ) async {
      await pump(tester, enable);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(prefs().show, isTrue);
      expect(prefs().service, _google);
      expect(prefs().noticeAcknowledged, {_google});
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
      await pump(tester, enable, acknowledged: {_google});

      expect(find.byType(AlertDialog), findsNothing);
      expect(prefs().show, isTrue);
      expect(prefs().service, _google);
    });
  });

  testWidgets('Continue still applies after the caller left the tree', (
    tester,
  ) async {
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    await pump(
      tester,
      (c, r) => enableTranslationWithNotice(c, r, _google),
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
    expect(prefs().service, _google);
    expect(prefs().noticeAcknowledged, {_google});
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
