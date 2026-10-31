import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/lyrics_translation_button.dart';
import 'package:kanaru/features/player/lyrics/translation/lyrics_translation_labels.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_translation_controller.dart';

const _google = LyricsTranslationService.google;
const _deepl = LyricsTranslationService.deepl;
const _both = {_google, _deepl};

void main() {
  late ProviderContainer container;
  late FakeTranslationController fake;

  TranslationPrefs prefs() => container.read(settingsProvider).translation;

  /// Opens the menu of the button, in `en` unless [locale] says otherwise.
  Future<void> pump(
    WidgetTester tester,
    LyricsTranslationState state, {
    TranslationPrefs settings = const TranslationPrefs(
      noticeAcknowledged: _both,
    ),
    bool followSettings = false,
    Size size = const Size(800, 900),
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    fake = FakeTranslationController(state, followSettings: followSettings);
    container = ProviderContainer(
      overrides: [
        fakeTranslationOverride(fake),
        initialSettingsProvider.overrideWithValue(
          AppSettings(translation: settings),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      translationApp(
        container,
        const LyricsTranslationButton(),
        locale: locale,
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(IconButton));
    // A loading state runs a ring that never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  TranslationReady ready({bool other = false, String? override}) =>
      TranslationReady(
        fakeTranslationInfo(songOverride: override),
        other ? _google : _deepl,
        'ja',
        const [],
        other,
      );

  /// Opens the Service submenu of the open menu.
  Future<void> openServiceSubmenu(WidgetTester tester) async {
    await tester.tap(find.text('Service'));
    await tester.pumpAndSettle();
  }

  Finder serviceRadio(String name) =>
      find.widgetWithText(RadioMenuButton<LyricsTranslationService>, name);

  /// Picks [name] in the Service submenu of the open menu.
  Future<void> pickService(WidgetTester tester, String name) async {
    await openServiceSubmenu(tester);
    await tester.tap(serviceRadio(name));
    await tester.pumpAndSettle();
  }

  testWidgets('items come in order and the first three work while off', (
    tester,
  ) async {
    await pump(tester, TranslationOff(fakeTranslationInfo()));

    final order = [
      'Show translation',
      'Translate to: English',
      'Service',
      'DISPLAY STYLE',
      'Under each line',
      'Replace',
    ].map((text) => tester.getTopLeft(find.text(text)).dy).toList();
    expect(order, orderedEquals([...order]..sort()));
    expect(find.text('T'), findsOneWidget);
    expect(find.text('Translation saved'), findsNothing);
    // The service row shows the selected service; the list is in its submenu.
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('DeepL'), findsNothing);
    for (final text in ['Translate to: English', 'Service']) {
      expect(
        find.ancestor(
          of: find.text(text),
          matching: find.byType(SubmenuButton),
        ),
        findsWidgets,
        reason: text,
      );
    }
    expect(
      find.ancestor(
        of: find.text('Replace'),
        matching: find.byType(SegmentedButton<LyricsTranslationDisplay>),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the switch turns translation on and the menu stays open', (
    tester,
  ) async {
    await pump(tester, TranslationOff(fakeTranslationInfo()));

    await tester.tap(find.text('Show translation'));
    await tester.pumpAndSettle();

    expect(prefs().show, isTrue);
    expect(find.text('Show translation'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(prefs().show, isFalse);
    expect(find.text('Show translation'), findsOneWidget);
  });

  testWidgets('Enter on the open menu flips the switch', (tester) async {
    await pump(tester, TranslationOff(fakeTranslationInfo()));

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(prefs().show, isTrue);
    expect(find.text('Show translation'), findsOneWidget);
  });

  testWidgets('a state that needs the notice shows the switch off', (
    tester,
  ) async {
    await pump(
      tester,
      TranslationNeedsNotice(fakeTranslationInfo(), _google),
      settings: const TranslationPrefs(show: true),
    );

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  group('the language submenu', () {
    testWidgets('picking a language is for this song only', (tester) async {
      await pump(tester, TranslationOff(fakeTranslationInfo()));
      final before = prefs();

      await tester.tap(find.text('Translate to: English'));
      await tester.pumpAndSettle();
      expect(find.text('Default (English)'), findsOneWidget);
      await tester.tap(find.text('Vietnamese'));
      await tester.pumpAndSettle();

      expect(fake.songTargets, ['vi']);
      expect(prefs(), before);
    });

    testWidgets('Default clears the song choice', (tester) async {
      await pump(
        tester,
        TranslationOff(fakeTranslationInfo(songOverride: 'ja')),
      );

      await tester.tap(find.text('Translate to: Japanese'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Default (English)'));
      await tester.pumpAndSettle();

      expect(fake.songTargets, [null]);
      expect(prefs().targetLanguage, isNull);
    });

    testWidgets('the checked item is the song choice, else Default', (
      tester,
    ) async {
      await pump(
        tester,
        TranslationOff(fakeTranslationInfo(songOverride: 'ja')),
      );
      await tester.tap(find.text('Translate to: Japanese'));
      await tester.pumpAndSettle();

      RadioMenuButton<String> radio(String text) =>
          tester.widget<RadioMenuButton<String>>(
            find.widgetWithText(RadioMenuButton<String>, text),
          );
      expect(radio('Japanese').value, radio('Japanese').groupValue);
      expect(
        radio('Default (English)').value,
        isNot(radio('Default (English)').groupValue),
      );
    });

    testWidgets('lists both Chinese scripts and fits a short window', (
      tester,
    ) async {
      await pump(
        tester,
        TranslationOff(fakeTranslationInfo()),
        size: const Size(800, 300),
      );

      await tester.tap(find.text('Translate to: English'));
      await tester.pumpAndSettle();

      expect(find.text('Default (English)'), findsOneWidget);
      await tester.dragFrom(const Offset(500, 150), const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the display style button writes the setting and stays open', (
    tester,
  ) async {
    await pump(tester, TranslationOff(fakeTranslationInfo()));

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(prefs().display, LyricsTranslationDisplay.replace);
    expect(find.text('Show translation'), findsOneWidget);

    await tester.tap(find.text('Under each line'));
    await tester.pumpAndSettle();
    expect(prefs().display, LyricsTranslationDisplay.underLine);
    expect(prefs().show, isFalse);
    expect(prefs().service, _google);
    expect(fake.songTargets, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the selected display style is the selected segment', (
    tester,
  ) async {
    await pump(tester, TranslationOff(fakeTranslationInfo()));

    SegmentedButton<LyricsTranslationDisplay> segmented() =>
        tester.widget(find.byType(SegmentedButton<LyricsTranslationDisplay>));
    expect(segmented().selected, {LyricsTranslationDisplay.underLine});
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(segmented().selected, {LyricsTranslationDisplay.replace});
  });

  group('the service submenu', () {
    testWidgets('lists both services, checks the selected, a pick closes', (
      tester,
    ) async {
      await pump(tester, TranslationOff(fakeTranslationInfo()));

      await openServiceSubmenu(tester);
      expect(serviceRadio('Google'), findsOneWidget);
      expect(serviceRadio('DeepL'), findsOneWidget);
      final google = tester.widget<RadioMenuButton<LyricsTranslationService>>(
        serviceRadio('Google'),
      );
      expect(google.value, google.groupValue);

      await tester.tap(serviceRadio('DeepL'));
      await tester.pumpAndSettle();
      expect(prefs().service, _deepl);
      expect(prefs().show, isFalse);
      expect(fake.songTargets, isEmpty);
      expect(find.text('Show translation'), findsNothing);

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Service'),
            matching: find.byType(SubmenuButton),
          ),
          matching: find.text('DeepL'),
        ),
        findsOneWidget,
      );
    });
  });

  group('the footer', () {
    testWidgets('a saved translation offers Retranslate', (tester) async {
      await pump(tester, ready());

      expect(find.text('Translation saved'), findsOneWidget);
      await tester.tap(find.text('Retranslate'));
      await tester.pumpAndSettle();
      expect(fake.retranslateCalls, 1);
      expect(find.text('Translation saved'), findsOneWidget);
    });

    testWidgets('a translation from the other service says so', (tester) async {
      await pump(tester, ready(other: true));

      expect(find.text('Saved from Google'), findsOneWidget);
      expect(find.text('Retranslate with Google'), findsOneWidget);
    });

    testWidgets('the same language needs no action', (tester) async {
      await pump(
        tester,
        TranslationSameLanguage(fakeTranslationInfo(), _google),
      );

      expect(find.text('Lyrics are already in English'), findsOneWidget);
      expect(find.text('Retranslate'), findsNothing);
    });

    testWidgets('the Vietnamese sentence uses a lowercase language name', (
      tester,
    ) async {
      await pump(
        tester,
        TranslationSameLanguage(
          fakeTranslationInfo(defaultCode: 'vi'),
          _google,
        ),
        locale: const Locale('vi'),
      );

      expect(find.text('Lời bài hát đã là tiếng Việt'), findsOneWidget);
    });

    testWidgets('loading disables Retranslate', (tester) async {
      await pump(tester, TranslationLoading(fakeTranslationInfo(), _google));

      expect(find.text('Translating…'), findsOneWidget);
      final item = tester.widget<MenuItemButton>(
        find.widgetWithText(MenuItemButton, 'Retranslate'),
      );
      expect(item.onPressed, isNull);
    });

    testWidgets('a failure shows its reason and Retry', (tester) async {
      await pump(
        tester,
        TranslationFailed(
          fakeTranslationInfo(),
          _deepl,
          TranslationFailureKind.badKey,
        ),
      );

      expect(
        find.text('DeepL rejected the API key. Check it in Settings.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(fake.retryCalls, 1);
    });

    test('every failure kind has its own sentence in both languages', () {
      for (final locale in const [Locale('en'), Locale('vi')]) {
        final l10n = lookupAppLocalizations(locale);
        final sentences = {
          for (final kind in TranslationFailureKind.values)
            translationFailureMessage(l10n, kind),
        };
        expect(sentences.length, TranslationFailureKind.values.length);
        expect(sentences, isNot(contains('')));
      }
    });
  });

  testWidgets('an open menu follows the state without reopening', (
    tester,
  ) async {
    await pump(
      tester,
      ready(),
      followSettings: true,
      settings: const TranslationPrefs(show: true, noticeAcknowledged: _both),
    );
    expect(find.text('Translation saved'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.tap(find.text('Show translation'));
    await tester.pumpAndSettle();

    expect(find.text('Translation saved'), findsNothing);
    expect(find.text('Show translation'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.text('Show translation'));
    await tester.pumpAndSettle();
    expect(find.text('Translation saved'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  group('the network notice', () {
    final off = TranslationOff(fakeTranslationInfo());

    testWidgets('the first switch-on asks; Cancel changes nothing', (
      tester,
    ) async {
      await pump(tester, off, settings: const TranslationPrefs());

      await tester.tap(find.text('Show translation'));
      await tester.pumpAndSettle();
      expect(find.text('Lyrics will be sent to Google'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(prefs().show, isFalse);
      expect(prefs().noticeAcknowledged, isEmpty);
    });

    testWidgets('Continue accepts and turns it on; the second time is silent', (
      tester,
    ) async {
      await pump(tester, off, settings: const TranslationPrefs());

      await tester.tap(find.text('Show translation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(prefs().show, isTrue);
      expect(prefs().noticeAcknowledged, {_google});

      await tester.tap(find.text('Show translation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show translation'));
      await tester.pumpAndSettle();
      expect(find.textContaining('will be sent'), findsNothing);
      expect(prefs().show, isTrue);
    });

    testWidgets('switching to DeepL while on asks once; Cancel keeps Google', (
      tester,
    ) async {
      await pump(
        tester,
        ready(),
        settings: const TranslationPrefs(
          show: true,
          noticeAcknowledged: {_google},
        ),
      );

      await pickService(tester, 'DeepL');
      expect(find.text('Lyrics will be sent to DeepL'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(prefs().service, _google);
      expect(prefs().show, isTrue);
      expect(prefs().noticeAcknowledged, {_google});

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      await pickService(tester, 'DeepL');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(prefs().service, _deepl);
      expect(prefs().noticeAcknowledged, _both);
      expect(prefs().show, isTrue);
    });

    testWidgets('choosing a service while off asks nothing', (tester) async {
      await pump(tester, off, settings: const TranslationPrefs());

      await pickService(tester, 'DeepL');

      expect(find.textContaining('will be sent'), findsNothing);
      expect(prefs().service, _deepl);
      expect(prefs().show, isFalse);
      expect(prefs().noticeAcknowledged, isEmpty);
    });
  });

  for (final (locale, switchText, language, service) in [
    (const Locale('vi'), 'Hiện bản dịch', 'Dịch sang: Tiếng Việt', 'Dịch vụ'),
    (
      const Locale('en'),
      'Show translation',
      'Translate to: Vietnamese',
      'Service',
    ),
  ]) {
    testWidgets('the menu is translated: ${locale.languageCode}', (
      tester,
    ) async {
      await pump(
        tester,
        TranslationOff(fakeTranslationInfo(defaultCode: 'vi')),
        locale: locale,
      );
      expect(find.text(switchText), findsOneWidget);
      expect(find.text(language), findsOneWidget);
      expect(find.text(service), findsOneWidget);
    });
  }
}
