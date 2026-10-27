import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/detail_page/play_shuffle_actions.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onPlay,
  VoidCallback? onShuffle,
  ValueChanged<QueueAction>? onQueueAction,
  double width = 600,
  Widget? menu,
}) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: PlayShuffleActions(
            playLabel: 'Play all',
            onPlay: onPlay,
            onShuffle: onShuffle,
            onQueueAction: onQueueAction,
            menu: menu,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('null callbacks disable Play and Shuffle and hide the menu', (
    tester,
  ) async {
    await _pump(tester);

    final buttons = tester.widgetList<ButtonStyleButton>(
      find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    expect(buttons, hasLength(2));
    expect(buttons.every((b) => !b.enabled), isTrue);
    expect(find.text('Play all'), findsOneWidget);
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.byType(QueueActionsButton), findsNothing);
  });

  testWidgets('callbacks enable the buttons and show the queue menu', (
    tester,
  ) async {
    var played = 0;
    var shuffled = 0;
    await _pump(
      tester,
      onPlay: () => played++,
      onShuffle: () => shuffled++,
      onQueueAction: (_) {},
    );

    expect(find.byType(QueueActionsButton), findsOneWidget);
    await tester.tap(find.text('Play all'));
    expect(played, 1);
    expect(shuffled, 0);
    await tester.tap(find.text('Shuffle'));
    expect(played, 1);
    expect(shuffled, 1);
  });

  testWidgets('menu selection reports the chosen queue action', (tester) async {
    final actions = <QueueAction>[];
    await _pump(
      tester,
      onPlay: () {},
      onShuffle: () {},
      onQueueAction: actions.add,
    );

    await tester.tap(find.byType(QueueActionsButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIcons.addToQueue));
    await tester.pumpAndSettle();
    expect(actions, [QueueAction.addToQueue]);
  });

  testWidgets('narrow width shrinks Shuffle to an enabled icon button', (
    tester,
  ) async {
    var shuffled = 0;
    await _pump(tester, width: 300, onPlay: () {}, onShuffle: () => shuffled++);

    expect(find.text('Shuffle'), findsNothing);
    expect(find.text('Play all'), findsOneWidget);
    final shuffle = find.widgetWithIcon(IconButton, AppIcons.shuffle);
    expect(shuffle, findsOneWidget);
    expect(tester.widget<IconButton>(shuffle).onPressed, isNotNull);
    await tester.tap(shuffle);
    expect(shuffled, 1);
  });

  testWidgets('narrow width with null onShuffle disables the icon button', (
    tester,
  ) async {
    await _pump(tester, width: 300, onPlay: () {});

    final shuffle = find.widgetWithIcon(IconButton, AppIcons.shuffle);
    expect(shuffle, findsOneWidget);
    expect(tester.widget<IconButton>(shuffle).onPressed, isNull);
  });

  testWidgets('menu hidden when only onQueueAction is null', (tester) async {
    await _pump(tester, onPlay: () {}, onShuffle: () {});
    expect(find.byType(QueueActionsButton), findsNothing);
    final buttons = tester.widgetList<ButtonStyleButton>(
      find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    expect(buttons.every((b) => b.enabled), isTrue);
  });

  testWidgets('menu replaces the queue button', (tester) async {
    await _pump(
      tester,
      onPlay: () {},
      onShuffle: () {},
      menu: const Icon(AppIcons.search, key: Key('custom-menu')),
    );

    expect(find.byKey(const Key('custom-menu')), findsOneWidget);
    expect(find.byType(QueueActionsButton), findsNothing);
  });

  test('menu and onQueueAction together are rejected', () {
    expect(
      () => PlayShuffleActions(
        playLabel: 'Play all',
        onPlay: null,
        onShuffle: null,
        onQueueAction: (_) {},
        menu: const SizedBox(),
      ),
      throwsAssertionError,
    );
  });
}
