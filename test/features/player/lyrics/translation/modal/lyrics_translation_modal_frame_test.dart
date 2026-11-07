import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/lyrics_translation_modal.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_language_row.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_modal_header.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_preview_card.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_service_section.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/shared/settings_routes.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_dialog_frame.dart';
import 'package:kanaru/shared/widgets/layered_modal/layered_modal_body.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_sheet_frame.dart';
import 'package:kanaru/shared/widgets/cover_art.dart';
import 'package:kanaru/shared/widgets/picker_field_button.dart';
import 'package:material_ui/material_ui.dart';

import 'translation_modal_harness.dart';

void main() {
  testWidgets('desktop viewport opens a 400px dialog frame', (tester) async {
    await pumpTranslationModal(tester, size: const Size(1280, 800));

    expect(find.byType(ContextModalDialogFrame), findsOneWidget);
    expect(find.byType(ContextModalSheetFrame), findsNothing);
    final modalRect = tester.getRect(find.byType(LyricsTranslationModal));
    expect(modalRect.width, 400);
  });

  testWidgets('mobile viewport opens a bottom sheet without overflow', (
    tester,
  ) async {
    await pumpTranslationModal(tester, size: const Size(380, 800));

    expect(find.byType(ContextModalSheetFrame), findsOneWidget);
    expect(find.byType(ContextModalDialogFrame), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'header has only the title, the settings button and the close button',
    (tester) async {
      await pumpTranslationModal(tester);

      final header = find.byType(TranslationModalHeader);
      expect(
        find.descendant(of: header, matching: find.text('Lyrics translation')),
        findsOneWidget,
      );
      expect(find.byType(CoverArt), findsNothing);
      expect(find.text('First Love'), findsNothing);
      expect(find.text('Utada Hikaru'), findsNothing);
      expect(
        find.descendant(of: header, matching: find.byType(IconButton)),
        findsNWidgets(2),
      );
      expect(find.byTooltip('Translation settings'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await settleModal(tester);

      expect(find.byType(LyricsTranslationModal), findsNothing);
    },
  );

  testWidgets('Escape closes the modal and keeps Now Playing open', (
    tester,
  ) async {
    final h = await pumpTranslationModal(tester);
    expect(find.byType(LyricsTranslationModal), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleModal(tester);

    expect(find.byType(LyricsTranslationModal), findsNothing);
    // The page under the modal is still there: Escape popped only the modal.
    expect(find.text('Open modal'), findsOneWidget);
    expect(h.location, '/');
    expect(h.container.read(nowPlayingOpenProvider), isTrue);
  });

  testWidgets(
    'settings button closes the modal, closes Now Playing, and navigates to playback translation settings',
    (tester) async {
      final h = await pumpTranslationModal(tester);

      await tester.tap(find.byTooltip('Translation settings'));
      await settleModal(tester);

      expect(find.byType(LyricsTranslationModal), findsNothing);
      expect(h.container.read(nowPlayingOpenProvider), isFalse);
      expect(h.location, '$settingsPlaybackRoute?focus=translation');
    },
  );

  testWidgets('an open modal closes when translation becomes unavailable', (
    tester,
  ) async {
    final h = await pumpTranslationModal(tester);
    expect(find.byType(LyricsTranslationModal), findsOneWidget);

    h.fake.emit(const TranslationUnavailable());
    await settleModal(tester);

    expect(find.byType(LyricsTranslationModal), findsNothing);
    expect(h.container.read(nowPlayingOpenProvider), isTrue);
  });

  testWidgets(
    'an open child modal and parent modal both close when translation becomes unavailable',
    (tester) async {
      final h = await pumpTranslationModal(tester);

      await tester.tap(find.byType(PickerFieldButton));
      await settleModal(tester);
      expect(find.text('Translate to'), findsOneWidget);

      h.fake.emit(const TranslationUnavailable());
      await settleModal(tester);

      expect(find.text('Translate to'), findsNothing);
      expect(find.byType(LyricsTranslationModal), findsNothing);
      expect(h.container.read(nowPlayingOpenProvider), isTrue);
    },
  );

  testWidgets('renders localized Vietnamese labels across the modal', (
    tester,
  ) async {
    await pumpTranslationModal(
      tester,
      locale: const Locale('vi'),
      state: TranslationReady(
        fakeTranslationInfo(defaultCode: 'vi'),
        testTranslatePlugin,
        'ja',
        const ['Nụ hôn cuối cùng'],
        false,
      ),
      settings: TranslationPrefs(
        show: true,
        service: testTranslatePlugin,
        noticeAcknowledged: {testTranslatePlugin},
      ),
    );

    expect(find.text('Dịch lời'), findsOneWidget);
    expect(find.text('XEM TRƯỚC'), findsOneWidget);
    expect(find.text('Dưới dòng'), findsOneWidget);
    expect(find.text('Thay dòng'), findsOneWidget);
    // No section title between the preview card and the language row.
    expect(
      find.descendant(
        of: find.byType(LayeredModalBody),
        matching: find.text('Bản dịch'),
      ),
      findsNothing,
    );
    expect(find.text('Tiếng Nhật · tự nhận'), findsOneWidget);
    expect(find.text('Tiếng Việt'), findsOneWidget);
    expect(find.text('Dịch bởi Test Translate'), findsOneWidget);
  });

  testWidgets('sections come in order: preview, language row, service', (
    tester,
  ) async {
    await pumpTranslationModal(
      tester,
      settings: TranslationPrefs(
        show: true,
        service: testTranslatePlugin,
        noticeAcknowledged: {testTranslatePlugin},
      ),
    );

    final order = [
      find.byType(TranslationPreviewCard),
      find.byType(TranslationLanguageRow),
      find.byType(TranslationServiceSection),
    ].map((finder) => tester.getTopLeft(finder).dy).toList();
    expect(order, orderedEquals([...order]..sort()));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Enter and Space on the focused switch flip translation on and off',
    (tester) async {
      final h = await pumpTranslationModal(tester);

      final switchPaint = find.descendant(
        of: find.byType(Switch),
        matching: find.byType(CustomPaint),
      );
      final node = Focus.of(tester.element(switchPaint.first));
      node.requestFocus();
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleModal(tester);
      expect(h.prefs.show, isTrue);
      expect(find.byType(LyricsTranslationModal), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settleModal(tester);
      expect(h.prefs.show, isFalse);
      expect(find.byType(LyricsTranslationModal), findsOneWidget);
    },
  );

  testWidgets(
    'short 380x600 window fits modal and target picker without overflow',
    (tester) async {
      await pumpTranslationModal(
        tester,
        size: const Size(380, 600),
        state: TranslationReady(
          fakeTranslationInfo(),
          testTranslatePlugin,
          'ja',
          const ['The last kiss', 'Tasted like cigarettes'],
          false,
        ),
        settings: TranslationPrefs(
          show: true,
          service: testTranslatePlugin,
          noticeAcknowledged: {testTranslatePlugin},
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(PickerFieldButton));
      await settleModal(tester);
      expect(find.text('Default (English)'), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, -150));
      await settleModal(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('target language picker scrolls inside a bounded height', (
    tester,
  ) async {
    await pumpTranslationModal(tester);
    await tester.tap(find.byType(PickerFieldButton));
    await settleModal(tester);

    final list = find.byType(ListView).last;
    expect(tester.getSize(list).height, lessThan(600));
    await tester.drag(list, const Offset(0, -200));
    await settleModal(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an open modal follows Loading to Ready state without reopening',
    (tester) async {
      final info = fakeTranslationInfo();
      final h = await pumpTranslationModal(
        tester,
        state: TranslationLoading(info, testTranslatePlugin),
        settings: TranslationPrefs(
          show: true,
          service: testTranslatePlugin,
          noticeAcknowledged: {testTranslatePlugin},
        ),
      );
      expect(find.text('Translating…'), findsOneWidget);

      h.fake.emit(
        TranslationReady(info, testTranslatePlugin, 'ja', const [
          'The last kiss',
          'Tasted like cigarettes',
        ], false),
      );
      await tester.pump();

      expect(find.text('Translating…'), findsNothing);
      expect(find.text('Translated by Test Translate'), findsOneWidget);
      expect(find.text('The last kiss'), findsOneWidget);
      expect(find.byType(LyricsTranslationModal), findsOneWidget);
    },
  );
}
