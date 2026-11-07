import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/playing_track_lyrics_provider.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_jobs.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/lyrics_translation_button.dart';
import 'package:kanaru/features/player/lyrics/translation/lyrics_translation_pill.dart';
import 'package:kanaru/shared/lyrics_plugins/plugin_icon.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics_translation/fake_plugin_runner.dart';
import '../../core/player/fake_audio_backend.dart';
import 'fake_translation_controller.dart';

final _testPlugin = testTranslatePlugin;
const _otherPluginId = 'plugin-111111111111';
final _otherPlugin = TranslationServiceId.tryParse(_otherPluginId)!;
final _info = fakeTranslationInfo();

void main() {
  late ProviderContainer container;
  late FakeTranslationController fake;
  var modalEvents = <bool>[];

  Future<void> pump(
    WidgetTester tester,
    LyricsTranslationState state, {
    bool enabled = true,
    double? maxLabelWidth,
    TranslationPrefs? settings,
    List<Override>? pluginOverrides,
    ValueNotifier<bool Function()?>? modalOpener,
    Widget? beside,
  }) async {
    modalEvents = [];
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        playingTrackLyricsProvider.overrideWithValue(const AsyncData(null)),
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?beside,
            LyricsTranslationButton(
              enabled: enabled,
              maxLabelWidth: maxLabelWidth,
              modalOpener: modalOpener,
              onModalChanged: modalEvents.add,
            ),
          ],
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

  testWidgets(
    'off: a plain icon with no ring, no dot, and shortcut hint in tooltip',
    (tester) async {
      await pump(tester, TranslationOff(_info));

      expect(find.byTooltip(translationButtonTooltipOff), findsOneWidget);
      expect(button(tester).isSelected, isFalse);
      expect(button(tester).style, isNull);
      expect(ring, findsNothing);
      expect(dot, findsNothing);
    },
  );

  testWidgets('on: primary icon on a raised background', (tester) async {
    await pump(
      tester,
      TranslationReady(_info, _testPlugin, 'ja', const [], false),
    );

    final style = button(tester).style!;
    final scheme = Theme.of(tester.element(find.byType(IconButton)))
        .colorScheme;
    expect(
      find.byTooltip(
        translationTooltip('Translated by Test Translate · English'),
      ),
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

    expect(
      find.byTooltip(translationTooltip('Lyrics translation: translating')),
      findsOneWidget,
    );
    expect(ring, findsOneWidget);
    expect(dot, findsNothing);
    expect(button(tester).isSelected, isTrue);
  });

  testWidgets('ready with refreshing: a progress ring around the icon', (
    tester,
  ) async {
    await pump(
      tester,
      TranslationReady(
        _info,
        _testPlugin,
        'ja',
        const [],
        false,
        refreshing: true,
      ),
    );

    expect(ring, findsOneWidget);
    expect(dot, findsNothing);
    expect(button(tester).isSelected, isTrue);
  });

  testWidgets('same language with refreshing: a progress ring', (tester) async {
    await pump(
      tester,
      TranslationSameLanguage(_info, _testPlugin, refreshing: true),
    );

    expect(ring, findsOneWidget);
    expect(dot, findsNothing);
  });

  testWidgets('same language with a retranslate failure: the error dot', (
    tester,
  ) async {
    await pump(
      tester,
      TranslationSameLanguage(
        _info,
        _testPlugin,
        retranslateFailure: TranslationFailureKind.network,
      ),
    );

    expect(dot, findsOneWidget);
    expect(ring, findsNothing);
  });

  testWidgets('same language from another service: tooltip names it', (
    tester,
  ) async {
    await pump(
      tester,
      TranslationSameLanguage(_info, _testPlugin, fromOtherService: true),
    );

    expect(
      find.byTooltip(
        translationTooltip(
          'Lyrics are already in English (per Test Translate)',
        ),
      ),
      findsOneWidget,
    );
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
    expect(
      find.byTooltip(translationTooltip('Lyrics translation: failed')),
      findsOneWidget,
    );
    expect(decoration.color, scheme.error);
    expect(tester.getSize(dot), const Size(8, 8));
    expect(ring, findsNothing);
  });

  testWidgets('needing the notice looks off', (tester) async {
    await pump(tester, TranslationNeedsNotice(_info, _testPlugin));

    expect(find.byTooltip(translationButtonTooltipOff), findsOneWidget);
    expect(button(tester).isSelected, isFalse);
  });

  testWidgets('a primary press opens the modal and changes no setting', (
    tester,
  ) async {
    await pump(tester, TranslationOff(_info));
    final before = container.read(settingsProvider);

    await tester.tap(find.byType(IconButton));
    await settleTranslationModal(tester);

    expect(translationModalFinder, findsOneWidget);
    expect(container.read(settingsProvider), before);
    expect(container.read(settingsProvider).translation.show, isFalse);
  });

  testWidgets(
    '0 plugins and no service: a tap opens the modal with the empty-plugins card and no snackbar',
    (tester) async {
      await pump(
        tester,
        TranslationOff(_info),
        settings: const TranslationPrefs(),
        pluginOverrides: translatePluginOverrides(records: const []),
      );

      await tester.tap(find.byType(IconButton));
      await settleTranslationModal(tester);

      expect(translationModalFinder, findsOneWidget);
      expect(find.text('No translation plugin'), findsOneWidget);
      expect(find.text('Open plugin store'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(modalEvents, [true]);
    },
  );

  testWidgets(
    'plugins installed and no service: a tap opens the modal with Not selected row',
    (tester) async {
      await pump(
        tester,
        TranslationOff(_info),
        settings: const TranslationPrefs(),
      );

      await tester.tap(find.byType(IconButton));
      await settleTranslationModal(tester);

      expect(translationModalFinder, findsOneWidget);
      expect(find.text('Not selected'), findsOneWidget);
      expect(modalEvents, [true]);
    },
  );

  testWidgets('reports the modal opening and closing', (tester) async {
    await pump(tester, TranslationOff(_info));

    await tester.tap(find.byType(IconButton));
    await settleTranslationModal(tester);
    expect(modalEvents, [true]);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(modalEvents, [true, false]);
    expect(translationModalFinder, findsNothing);
  });

  testWidgets('leaving the tree with the modal open reports closed', (
    tester,
  ) async {
    await pump(tester, TranslationOff(_info));
    await tester.tap(find.byType(IconButton));
    await settleTranslationModal(tester);

    await tester.pumpWidget(const SizedBox());

    expect(modalEvents, [true, false]);
  });

  testWidgets('is disabled for a song without lyrics', (tester) async {
    await pump(tester, TranslationOff(_info), enabled: false);

    expect(button(tester).onPressed, isNull);
    await tester.tap(find.byType(IconButton), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(translationModalFinder, findsNothing);
    expect(modalEvents, isEmpty);
  });

  testWidgets('is disabled while the translation is unavailable', (
    tester,
  ) async {
    await pump(tester, const TranslationUnavailable());

    expect(button(tester).onPressed, isNull);
  });

  group('secondary tap', () {
    testWidgets(
      'on icon: asks network notice on first turn-on, then toggles on and off',
      (tester) async {
        await pump(
          tester,
          TranslationOff(_info),
          settings: TranslationPrefs(service: _testPlugin),
        );

        await tester.tap(find.byType(IconButton), buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.text('Lyrics will be sent to the plugin Test Translate'),
          findsOneWidget,
        );
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(container.read(settingsProvider).translation.show, isTrue);
        expect(
          container.read(settingsProvider).translation.noticeAcknowledged,
          {_testPlugin},
        );

        await tester.tap(find.byType(IconButton), buttons: kSecondaryButton);
        await tester.pumpAndSettle();
        expect(container.read(settingsProvider).translation.show, isFalse);

        await tester.tap(find.byType(IconButton), buttons: kSecondaryButton);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(container.read(settingsProvider).translation.show, isTrue);
      },
    );

    testWidgets('on pill: turns translation off', (tester) async {
      await pump(
        tester,
        TranslationReady(_info, _testPlugin, 'ja', const [], false),
        maxLabelWidth: 120,
        settings: TranslationPrefs(
          show: true,
          service: _testPlugin,
          noticeAcknowledged: {_testPlugin},
        ),
      );

      await tester.tap(
        find.byType(LyricsTranslationPill),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).translation.show, isFalse);
    });

    testWidgets('without lyrics: does nothing', (tester) async {
      await pump(tester, TranslationOff(_info), enabled: false);

      await tester.tap(
        find.byType(IconButton),
        buttons: kSecondaryButton,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).translation.show, isFalse);
      expect(translationModalFinder, findsNothing);
      expect(modalEvents, isEmpty);
    });

    testWidgets(
      '0 plugins and no service: opens the modal with empty-plugins card and no snackbar',
      (tester) async {
        await pump(
          tester,
          TranslationOff(_info),
          settings: const TranslationPrefs(),
          pluginOverrides: translatePluginOverrides(records: const []),
        );

        await tester.tap(find.byType(IconButton), buttons: kSecondaryButton);
        await settleTranslationModal(tester);

        expect(translationModalFinder, findsOneWidget);
        expect(find.text('No translation plugin'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect(modalEvents, [true]);
      },
    );

    testWidgets(
      'plugins installed and no service: opens the modal with Not selected row and no snackbar',
      (tester) async {
        await pump(
          tester,
          TranslationOff(_info),
          settings: const TranslationPrefs(),
        );

        await tester.tap(find.byType(IconButton), buttons: kSecondaryButton);
        await settleTranslationModal(tester);

        expect(translationModalFinder, findsOneWidget);
        expect(find.text('Not selected'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect(modalEvents, [true]);
      },
    );
  });

  group('pill', () {
    TranslationReady ready({
      TranslationServiceId? service,
      bool fromOther = false,
      bool refreshing = false,
      String? songOverride,
    }) => TranslationReady(
      fakeTranslationInfo(songOverride: songOverride),
      service ?? _testPlugin,
      'ja',
      const [],
      fromOther,
      refreshing: refreshing,
    );

    testWidgets(
      'ready with room: plugin icon with default fallback, target language only, and credit with hint in tooltip',
      (tester) async {
        await pump(tester, ready(), maxLabelWidth: 120);

        expect(find.text('English'), findsOneWidget);
        expect(find.textContaining('Test Translate'), findsNothing);
        expect(find.byType(IconButton), findsNothing);
        final pluginIcon = tester.widget<PluginIcon>(find.byType(PluginIcon));
        expect(pluginIcon.record?.installId, _testPlugin.value);
        expect(pluginIcon.size, 20);
        expect(
          find.descendant(
            of: find.byType(PluginIcon),
            matching: find.byIcon(pluginDefaultIcon),
          ),
          findsOneWidget,
        );
        expect(
          find.byTooltip(
            translationTooltip('Translated by Test Translate · English'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'showing a translation from another plugin displays that plugin icon',
      (tester) async {
        final records = [
          translateRecord(testTranslatePluginId, name: 'Test Translate'),
          translateRecord(_otherPluginId, name: 'Other Plugin'),
        ];
        await pump(
          tester,
          ready(service: _otherPlugin, fromOther: true),
          maxLabelWidth: 120,
          pluginOverrides: translatePluginOverrides(records: records),
        );

        final pluginIcon = tester.widget<PluginIcon>(find.byType(PluginIcon));
        expect(pluginIcon.record?.installId, _otherPluginId);
        expect(
          find.byTooltip(
            translationTooltip('Translated by Other Plugin · English'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ready with refreshing: replaces plugin icon with 18px progress ring',
      (tester) async {
        await pump(tester, ready(refreshing: true), maxLabelWidth: 120);

        expect(find.byType(LyricsTranslationPill), findsOneWidget);
        expect(ring, findsOneWidget);
        expect(find.byType(PluginIcon), findsNothing);
      },
    );

    testWidgets(
      'disabled pill disables its button and dims the logo like the label',
      (tester) async {
        await pump(tester, ready(), maxLabelWidth: 120, enabled: false);

        final textButton = tester.widget<TextButton>(
          find.descendant(
            of: find.byType(LyricsTranslationPill),
            matching: find.byType(TextButton),
          ),
        );
        expect(textButton.onPressed, isNull);
        double logoOpacity() => tester
            .widget<Opacity>(
              find.ancestor(
                of: find.byType(PluginIcon),
                matching: find.byType(Opacity),
              ),
            )
            .opacity;
        expect(logoOpacity(), 0.38);

        await pump(tester, ready(), maxLabelWidth: 120);
        expect(logoOpacity(), 1);
      },
    );

    testWidgets('pressing the pill opens the modal', (tester) async {
      await pump(tester, ready(), maxLabelWidth: 120);

      await tester.tap(find.text('English'));
      await settleTranslationModal(tester);

      expect(translationModalFinder, findsOneWidget);
      expect(modalEvents, [true]);
    });

    testWidgets('a long label shrinks with an ellipsis to its room', (
      tester,
    ) async {
      await pump(tester, ready(songOverride: 'zh-Hant'), maxLabelWidth: 64);

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.text('Chinese (Traditional)')).width,
        lessThanOrEqualTo(64),
      );
    });

    testWidgets('less room than the minimum keeps the icon', (tester) async {
      await pump(tester, ready(), maxLabelWidth: 63);

      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byType(LyricsTranslationPill), findsNothing);
      expect(
        find.byTooltip(
          translationTooltip('Translated by Test Translate · English'),
        ),
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
      expect(find.byType(LyricsTranslationPill), findsNothing);
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
      expect(
        find.byTooltip(translationTooltip('Lyrics are already in English')),
        findsOneWidget,
      );
    });

    testWidgets('an open modal survives the loading to ready switch', (
      tester,
    ) async {
      await pump(
        tester,
        TranslationLoading(_info, _testPlugin),
        maxLabelWidth: 120,
      );
      await tester.tap(find.byType(IconButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(translationModalFinder, findsOneWidget);

      fake.emit(ready());
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LyricsTranslationPill), findsOneWidget);
      expect(translationModalFinder, findsOneWidget);
      expect(modalEvents, [true]);
    });
  });

  group('modal hand-off', () {
    TranslationReady ready({TranslationFailureKind? retranslateFailure}) =>
        TranslationReady(
          fakeTranslationInfo(),
          _testPlugin,
          'ja',
          const [],
          false,
          retranslateFailure: retranslateFailure,
        );

    testWidgets(
      'retranslate from the modal the button opened shows the snackbar on the '
      "button's own messenger",
      (tester) async {
        await pump(tester, ready(), maxLabelWidth: 120);
        // A messenger nearer than the app's: only the button's own handoff
        // reaches it, the modal route would find the app's.
        final nearest = GlobalKey();
        await tester.pumpWidget(
          translationApp(
            container,
            ScaffoldMessenger(
              child: Scaffold(
                key: nearest,
                body: const LyricsTranslationButton(maxLabelWidth: 120),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        fake.retranslateCompleter = Completer();

        await tester.tap(find.text('English'));
        await settleTranslationModal(tester);
        await tester.tap(find.byTooltip('Retranslate'));
        await tester.pump();
        fake.retranslateCompleter!.complete(
          const TranslationJobStatus.saved(1),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.descendant(
            of: find.byKey(nearest),
            matching: find.text('Retranslated with Test Translate'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('closing the modal returns focus to the node focused before', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final opener = ValueNotifier<bool Function()?>(null);
      addTearDown(opener.dispose);
      await pump(
        tester,
        TranslationOff(_info),
        modalOpener: opener,
        beside: Focus(focusNode: node, child: const SizedBox(width: 10)),
      );
      node.requestFocus();
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue);

      opener.value!();
      await settleTranslationModal(tester);
      expect(node.hasPrimaryFocus, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleTranslationModal(tester);

      expect(translationModalFinder, findsNothing);
      expect(node.hasPrimaryFocus, isTrue);
    });

    testWidgets(
      'modalOpener opens one modal however often it is called, and is null '
      'while unusable',
      (tester) async {
        final opener = ValueNotifier<bool Function()?>(null);
        addTearDown(opener.dispose);
        await pump(tester, TranslationOff(_info), modalOpener: opener);
        expect(opener.value, isNotNull);

        expect(opener.value!(), isTrue);
        expect(opener.value!(), isFalse);
        await settleTranslationModal(tester);

        expect(translationModalFinder, findsOneWidget);
        expect(modalEvents, [true]);

        await tester.pumpWidget(
          translationApp(
            container,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LyricsTranslationButton(enabled: false, modalOpener: opener),
              ],
            ),
          ),
        );
        await tester.pump();
        expect(opener.value, isNull);
      },
    );

    testWidgets(
      'the secondary-tap detector stays when the button is disabled',
      (tester) async {
        await pump(tester, TranslationOff(_info), enabled: false);
        final detector = find
            .descendant(
              of: find.byType(LyricsTranslationButton),
              matching: find.byType(GestureDetector),
            )
            .first;
        final before = tester.element(detector);
        expect(tester.widget<GestureDetector>(detector).onSecondaryTap, isNull);

        await tester.pumpWidget(
          translationApp(
            container,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LyricsTranslationButton(onModalChanged: modalEvents.add),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(tester.element(detector), same(before));
        expect(
          tester.widget<GestureDetector>(detector).onSecondaryTap,
          isNotNull,
        );
      },
    );

    for (final room in const [null, 200.0]) {
      testWidgets(
        'a failed retranslate marks the ${room == null ? 'icon' : 'pill'} with '
        'the error dot',
        (tester) async {
          await pump(tester, ready(), maxLabelWidth: room);
          expect(dot, findsNothing);

          fake.emit(ready(retranslateFailure: TranslationFailureKind.network));
          await tester.pump();

          expect(dot, findsOneWidget);
        },
      );
    }
  });
}
