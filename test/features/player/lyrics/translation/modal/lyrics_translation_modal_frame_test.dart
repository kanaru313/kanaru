import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/lyrics_translation_modal.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_modal_header.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/shared/settings_routes.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_dialog_frame.dart';
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
    'header displays track metadata, has no marquee for short text, and close button dismisses',
    (tester) async {
      await pumpTranslationModal(tester);

      expect(find.byType(CoverArt), findsOneWidget);
      expect(find.text('First Love'), findsOneWidget);
      expect(find.text('Utada Hikaru'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TranslationModalHeader),
          matching: find.byType(ShaderMask),
        ),
        findsNothing,
      );

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

  testWidgets('long track title activates marquee fade in header', (
    tester,
  ) async {
    await pumpTranslationModal(
      tester,
      track: const Track(
        uri: '/m/long.flac',
        title: 'An Extraordinarily Long Track Title That Overflows The Header Area Clearly',
        artist: 'Utada Hikaru',
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.descendant(
        of: find.byType(TranslationModalHeader),
        matching: find.byType(ShaderMask),
      ),
      findsOneWidget,
    );
  });

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

    expect(find.text('XEM TRƯỚC'), findsOneWidget);
    expect(find.text('Dưới dòng'), findsOneWidget);
    expect(find.text('Thay dòng'), findsOneWidget);
    expect(find.text('Bản dịch'), findsOneWidget);
    expect(find.text('Tiếng Nhật · tự nhận'), findsOneWidget);
    expect(find.text('Tiếng Việt'), findsOneWidget);
    expect(find.text('Dịch bởi Test Translate'), findsOneWidget);
  });
}
