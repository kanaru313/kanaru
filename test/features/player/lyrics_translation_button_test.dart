import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/lyrics_translation_button.dart';

import 'fake_translation_controller.dart';

const _google = LyricsTranslationService.google;
final _info = fakeTranslationInfo();

void main() {
  late ProviderContainer container;
  late FakeTranslationController fake;
  var menuEvents = <bool>[];

  Future<void> pump(
    WidgetTester tester,
    LyricsTranslationState state, {
    bool enabled = true,
  }) async {
    menuEvents = [];
    container = ProviderContainer(
      overrides: [
        fakeTranslationOverride(fake = FakeTranslationController(state)),
        initialSettingsProvider.overrideWithValue(
          const AppSettings(
            translation: TranslationPrefs(noticeAcknowledged: {_google}),
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
    await pump(tester, TranslationReady(_info, _google, 'ja', const [], false));

    final style = button(tester).style!;
    final scheme = Theme.of(tester.element(find.byType(IconButton)))
        .colorScheme;
    expect(find.byTooltip('Lyrics translation: on'), findsOneWidget);
    expect(button(tester).isSelected, isTrue);
    expect(style.backgroundColor!.resolve({}), scheme.surfaceContainerHighest);
    expect(style.foregroundColor!.resolve({}), scheme.primary);
    expect(ring, findsNothing);
    expect(dot, findsNothing);
  });

  testWidgets('loading: a progress ring around the icon', (tester) async {
    await pump(tester, TranslationLoading(_info, _google));

    expect(find.byTooltip('Lyrics translation: translating'), findsOneWidget);
    expect(ring, findsOneWidget);
    expect(dot, findsNothing);
    expect(button(tester).isSelected, isTrue);
  });

  testWidgets('failed: an error-colour dot at the corner', (tester) async {
    await pump(
      tester,
      TranslationFailed(_info, _google, TranslationFailureKind.network),
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
    await pump(tester, TranslationNeedsNotice(_info, _google));

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
}
