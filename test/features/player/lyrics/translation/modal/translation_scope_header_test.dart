import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/translation_scope_header.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // 380 px is the narrowest sheet; 230 px forces the labels to scale down.
  for (final width in const [380.0, 230.0]) {
    for (final locale in const [Locale('en'), Locale('vi')]) {
      testWidgets('segment labels stay on one line and inside their segment '
          'at ${width.toInt()} px (${locale.languageCode})', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: TranslationScopeHeader(
                    scopes: TranslationScope.values,
                    selected: TranslationScope.song,
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);

        final boxes = find.descendant(
          of: find.byType(SegmentedButton<TranslationScope>),
          matching: find.byType(FittedBox),
        );
        expect(boxes, findsNWidgets(TranslationScope.values.length));
        for (final box in boxes.evaluate()) {
          final fitted = box.widget as FittedBox;
          final text = find.descendant(
            of: find.byWidget(fitted),
            matching: find.byType(Text),
          );
          final p = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byWidget(fitted),
              matching: find.byType(RichText),
            ),
          );
          expect(p.didExceedMaxLines, isFalse);
          final lineBoxes = p.getBoxesForSelection(
            TextSelection(
              baseOffset: 0,
              extentOffset: p.text.toPlainText().length,
            ),
          );
          expect(lineBoxes.length, 1);
          // The scaled label never spills outside its segment.
          final labelRect = tester.getRect(text);
          final boxRect = tester.getRect(find.byWidget(fitted));
          expect(labelRect.width, lessThanOrEqualTo(boxRect.width + 0.5));
        }
      });
    }
  }
}
