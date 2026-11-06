import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/lyrics_translation_button.dart';
import 'package:kanaru/features/player/lyrics/translation/lyrics_translation_pill.dart';

import '../../core/lyrics_translation/fake_plugin_runner.dart';
import 'fake_translation_controller.dart';

final _testPlugin = testTranslatePlugin;
final _info = fakeTranslationInfo();

void main() {
  late ProviderContainer container;
  late FakeTranslationController fake;
  var menuEvents = <bool>[];

  Future<void> pump(
    WidgetTester tester,
    LyricsTranslationState state, {
    bool enabled = true,
    double? maxLabelWidth,
    TranslationPrefs? settings,
    List<Override>? pluginOverrides,
  }) async {
    menuEvents = [];
    container = ProviderContainer(
      overrides: [
        fakeTranslationOverride(fake = FakeTranslationController(state)),
        ...(pluginOverrides ?? translatePluginOverrides()),
        initialSettingsProvider.overrideWithValue(
          AppSettings(
            translation:
                settings ??
                TranslationPrefs(
                  service: _testPlugin,
                  noticeAcknowledged: {_testPlugin},
                ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      translationApp(
        container,
        LyricsTranslationButton(
          enabled: enabled,
          maxLabelWidth: maxLabelWidth,
          onMenuChanged: menuEvents.add,
        ),
      ),
    );
    // A running ring never settles, so only the first frame is waited for.
    await tester.pump(const Duration(milliseconds: 50));
  }

  IconButton button(WidgetTester tester) =>
      tester.widget<IconButton>(find.byType(IconButton));

  final ring = find.byType(CircularProgressIndicator);
  final dot = find.byKey(const ValueKey('translationFailedDot'));

  testWidgets('off: a plain icon with no ring and no dot', (tester) async {
    await pump(tester, TranslationOff(_info));

    expect(find.byTooltip('Lyrics translation'), findsOneWidget);
    expect(button(tester).isSelected, isFalse);
    expect(button(tester).style, isNull);
    expect(ring, findsNothing);
    expect(dot, findsNothing);
  });

  testWidgets('on: primary icon on a raised background', (tester) async {
    await pump(
      tester,
      TranslationReady(_info, _testPlugin, 'ja', const [], false),
    );

    final style = button(tester).style!;
    final scheme = Theme.of(tester.element(find.byType(IconButton)))
        .colorScheme;
    expect(
      find.byTooltip('Translated by Test Translate · English'),
      findsOneWidget,
    );
    expect(button(tester).isSelected, isTrue);
    expect(style.backgroundColor!.resolve({}), scheme.surfaceContainerHighest);
    expect(style.foregroundColor!.resolve({}), scheme.primary);
    expect(ring, findsNothing);
    expect(dot, findsNothing);
  });

  testWidgets('loading: a progress ring around the icon', (tester) async {
    await pump(tester, TranslationLoading(_info, _testPlugin));

    expect(find.byTooltip('Lyrics translation: translating'), findsOneWidget);
    expect(ring, findsOneWidget);
    expect(dot, findsNothing);
    expect(button(tester).isSelected, isTrue);
  });

  testWidgets('failed: an error-colour dot at the corner', (tester) async {
    await pump(
      tester,
      TranslationFailed(_info, _testPlugin, TranslationFailureKind.network),
    );

    final scheme = Theme.of(tester.element(find.byType(IconButton)))
        .colorScheme;
    final decoration =
        tester.widget<Container>(dot).decoration! as BoxDecoration;
    expect(find.byTooltip('Lyrics translation: failed'), findsOneWidget);
    expect(decoration.color, scheme.error);
    expect(tester.getSize(dot), const Size(8, 8));
    expect(ring, findsNothing);
  });

  testWidgets('needing the notice looks off', (tester) async {
    await pump(tester, TranslationNeedsNotice(_info, _testPlugin));

    expect(find.byTooltip('Lyrics translation'), findsOneWidget);
    expect(button(tester).isSelected, isFalse);
  });

  testWidgets('a press opens the menu and changes no setting', (tester) async {
    await pump(tester, TranslationOff(_info));
    final before = container.read(settingsProvider);

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(find.text('Show translation'), findsOneWidget);
    expect(container.read(settingsProvider), before);
    expect(container.read(settingsProvider).translation.show, isFalse);
  });

  testWidgets(
    '0 plugins and no service: a tap shows the snackbar and keeps the menu closed',
    (tester) async {
      await pump(
        tester,
        TranslationOff(_info),
        settings: const TranslationPrefs(),
        pluginOverrides: translatePluginOverrides(records: const []),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(
        find.text('Install a translation plugin to translate lyrics'),
        findsOneWidget,
      );
      expect(find.text('Open plugin store'), findsOneWidget);
      expect(find.text('Show translation'), findsNothing);
      expect(menuEvents, isEmpty);
    },
  );

  testWidgets(
    'plugins installed and no service: a tap opens the menu with the service submenu open',
    (tester) async {
      await pump(
        tester,
        TranslationOff(_info),
        settings: const TranslationPrefs(),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.text('Show translation'), findsOneWidget);
      expect(
        find.widgetWithText(MenuItemButton, 'Test Translate'),
        findsOneWidget,
      );
      expect(menuEvents, [true]);
    },
  );

  testWidgets('reports the menu opening and closing', (tester) async {
    await pump(tester, TranslationOff(_info));

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(menuEvents, [true]);

    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(menuEvents, [true, false]);
    expect(find.text('Show translation'), findsNothing);
  });

  testWidgets('leaving the tree with the menu open reports closed', (
    tester,
  ) async {
    await pump(tester, TranslationOff(_info));
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());

    expect(menuEvents, [true, false]);
  });

  testWidgets('is disabled for a song without lyrics', (tester) async {
    await pump(tester, TranslationOff(_info), enabled: false);

    expect(button(tester).onPressed, isNull);
    await tester.tap(find.byType(IconButton), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Show translation'), findsNothing);
    expect(menuEvents, isEmpty);
  });

  testWidgets('is disabled while the translation is unavailable', (
    tester,
  ) async {
    await pump(tester, const TranslationUnavailable());

    expect(button(tester).onPressed, isNull);
  });

  testWidgets('an open menu closes when the translation becomes unavailable', (
    tester,
  ) async {
    await pump(tester, TranslationOff(_info));
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(menuEvents, [true]);

    fake.emit(const TranslationUnavailable());
    await tester.pumpAndSettle();

    expect(find.text('Show translation'), findsNothing);
    expect(menuEvents, [true, false]);
  });

  group('pill', () {
    TranslationReady ready([TranslationServiceId? service]) =>
        TranslationReady(_info, service ?? _testPlugin, 'ja', const [], false);

    testWidgets('ready with room: service and language, credit tooltip', (
      tester,
    ) async {
      await pump(tester, ready(), maxLabelWidth: 120);

      expect(find.text('Test Translate · English'), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
      expect(
        find.byTooltip('Translated by Test Translate · English'),
        findsOneWidget,
      );
    });

    testWidgets('disabled pill does not force the primary icon colour', (
      tester,
    ) async {
      await pump(tester, ready(), maxLabelWidth: 120, enabled: false);

      final scheme = Theme.of(
        tester.element(find.text('Test Translate · English')),
      ).colorScheme;
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(LyricsTranslationPill),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.color, isNull);
      expect(icon.color, isNot(scheme.primary));
    });

    testWidgets('pressing the pill opens the menu', (tester) async {
      await pump(tester, ready(), maxLabelWidth: 120);

      await tester.tap(find.text('Test Translate · English'));
      await tester.pumpAndSettle();

      expect(find.text('Show translation'), findsOneWidget);
      expect(menuEvents, [true]);
    });

    testWidgets('a long label shrinks with an ellipsis to its room', (
      tester,
    ) async {
      await pump(tester, ready(), maxLabelWidth: 64);

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.text('Test Translate · English')).width,
        lessThanOrEqualTo(64),
      );
    });

    testWidgets('less room than the minimum keeps the icon', (tester) async {
      await pump(tester, ready(), maxLabelWidth: 63);

      expect(find.byType(IconButton), findsOneWidget);
      expect(find.text('Test Translate · English'), findsNothing);
      expect(
        find.byTooltip('Translated by Test Translate · English'),
        findsOneWidget,
      );
    });

    testWidgets('no room given keeps the icon', (tester) async {
      await pump(tester, ready());

      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('off stays an icon even with room', (tester) async {
      await pump(tester, TranslationOff(_info), maxLabelWidth: 200);

      expect(find.byType(IconButton), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('failed stays an icon with its dot even with room', (
      tester,
    ) async {
      await pump(
        tester,
        TranslationFailed(_info, _testPlugin, TranslationFailureKind.network),
        maxLabelWidth: 200,
      );

      expect(find.byType(IconButton), findsOneWidget);
      expect(dot, findsOneWidget);
    });

    testWidgets('same language: active icon with the note as tooltip', (
      tester,
    ) async {
      await pump(
        tester,
        TranslationSameLanguage(_info, _testPlugin),
        maxLabelWidth: 200,
      );

      expect(find.byType(IconButton), findsOneWidget);
      expect(button(tester).isSelected, isTrue);
      expect(find.byTooltip('Lyrics are already in English'), findsOneWidget);
    });

    testWidgets('an open menu survives the loading to ready switch', (
      tester,
    ) async {
      await pump(
        tester,
        TranslationLoading(_info, _testPlugin),
        maxLabelWidth: 120,
      );
      await tester.tap(find.byType(IconButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Show translation'), findsOneWidget);

      fake.emit(ready());
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Test Translate · English'), findsOneWidget);
      expect(find.text('Show translation'), findsOneWidget);
      expect(menuEvents, [true]);
    });
  });
}
