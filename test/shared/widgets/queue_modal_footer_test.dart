import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_nav.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:kanaru/shared/widgets/queue_modal_footer.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<List<Object>> pump(
    WidgetTester tester, {
    bool divider = true,
    bool enabled = true,
  }) async {
    final log = <Object>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: QueueModalFooter(
            nav: ContextModalNav(
              push: (_) {},
              pop: () {},
              close: ([_]) => log.add('close'),
            ),
            onAction: log.add,
            keyPrefix: 'album-modal',
            divider: divider,
            enabled: enabled,
          ),
        ),
      ),
    );
    return log;
  }

  testWidgets('disabled buttons ignore taps and are dimmed', (tester) async {
    final log = await pump(tester, enabled: false);
    await tester.tap(find.byKey(const ValueKey('album-modal-play-next')));
    await tester.tap(find.byKey(const ValueKey('album-modal-add-to-queue')));
    expect(log, isEmpty);
    final inkWell = tester.widget<InkWell>(
      find.byKey(const ValueKey('album-modal-play-next')),
    );
    expect(inkWell.onTap, isNull);
  });

  testWidgets(
    'buttons carry the prefix keys and close first, then hand their action over',
    (tester) async {
      final log = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('album-modal-play-next')));
      await tester.tap(find.byKey(const ValueKey('album-modal-add-to-queue')));
      expect(log, [
        'close',
        QueueAction.playNext,
        'close',
        QueueAction.addToQueue,
      ]);
    },
  );

  testWidgets('divider flag draws or drops the line above the buttons', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(Divider), findsOneWidget);
    await pump(tester, divider: false);
    expect(find.byType(Divider), findsNothing);
  });
}
