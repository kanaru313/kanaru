import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/lyrics_translation_modal.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/shared/widgets/selection_row.dart';
import 'package:material_ui/material_ui.dart';

import 'translation_modal_harness.dart';

void main() {
  testWidgets(
    'Unavailable while the network notice is open closes everything and writes nothing',
    (tester) async {
      final h = await pumpTranslationModal(
        tester,
        settings: TranslationPrefs(service: testTranslatePlugin),
      );
      final before = h.prefs;

      await tester.tap(find.byType(Switch));
      await settleModal(tester);
      expect(find.byType(AlertDialog), findsOneWidget);

      h.fake.emit(const TranslationUnavailable());
      await settleModal(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(LyricsTranslationModal), findsNothing);
      expect(find.text('Open modal'), findsOneWidget);
      expect(h.prefs, before);
      expect(h.container.read(nowPlayingOpenProvider), isTrue);
    },
  );

  testWidgets('target picker marks Default as selected without an override', (
    tester,
  ) async {
    await pumpTranslationModal(tester);
    await tester.tap(find.text('English'));
    await settleModal(tester);

    bool selected(String label) => tester
        .widget<SelectionRow>(find.widgetWithText(SelectionRow, label))
        .selected;
    expect(selected('Default (English)'), isTrue);
    expect(selected('Japanese'), isFalse);
  });
}
