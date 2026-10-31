import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_route.dart';

import 'context_modal_harness.dart';

void main() {
  testWidgets('shows subtitle and runs trailing buttons without the row', (
    tester,
  ) async {
    var row = 0, trail = 0;
    await pumpModalApp(
      tester,
      extra: [
        ContextModalAction(
          id: 'path',
          icon: Icons.folder,
          label: 'Folder',
          subtitle: '/music/a',
          onTap: (_) => row++,
          trailing: [
            ContextModalTrailing(
              icon: Icons.open_in_new,
              tooltip: 'Show',
              onTap: (_) => trail++,
            ),
          ],
        ),
      ],
    );
    expect(find.text('/music/a'), findsOneWidget);
    await tester.tap(find.byTooltip('Show'));
    expect(trail, 1);
    expect(row, 0);
    await tester.tap(find.text('Folder'));
    expect(row, 1);
  });

  testWidgets('coming soon: badge, tap shows a snackbar, Enter does nothing', (
    tester,
  ) async {
    var called = 0;
    await pumpModalApp(
      tester,
      extra: [
        ContextModalAction(
          id: 'soon',
          icon: Icons.delete,
          label: 'Later',
          comingSoon: true,
          onTap: (_) => called++,
        ),
      ],
    );
    expect(find.text('Coming soon'), findsOneWidget);

    // A coming-soon row takes no focus, so Enter can never reach it.
    final ink = tester.widget<InkWell>(
      find.ancestor(of: find.text('Later'), matching: find.byType(InkWell)),
    );
    expect(ink.onTap, isNull);

    await tester.tap(find.text('Later'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining("isn't available yet"), findsOneWidget);
    expect(called, 0);

    // The snackbar belongs to the modal's own messenger, above the scrim.
    final modal = ScaffoldMessenger.of(tester.element(find.text('Later')));
    final app = ScaffoldMessenger.of(tester.element(find.text('open')));
    expect(modal, isNot(same(app)));
    expect(
      find.descendant(
        of: find.byWidget(modal.widget),
        matching: find.textContaining("isn't available yet"),
      ),
      findsOneWidget,
    );
  });

  testWidgets('disabled and destructive rows', (tester) async {
    var called = 0;
    await pumpModalApp(
      tester,
      extra: [
        ContextModalAction(
          id: 'off',
          icon: Icons.delete,
          label: 'Off',
          enabled: false,
          onTap: (_) => called++,
        ),
        ContextModalAction(
          id: 'danger',
          icon: Icons.delete,
          label: 'Danger',
          destructive: true,
          onTap: (_) {},
        ),
      ],
    );
    await tester.tap(find.text('Off'));
    expect(called, 0);
    final colors = Theme.of(tester.element(find.text('Danger'))).colorScheme;
    expect(tester.widget<Text>(find.text('Danger')).style?.color, colors.error);
  });

  testWidgets('chips expand and collapse, and a chip runs its callback', (
    tester,
  ) async {
    String? picked;
    await pumpModalApp(
      tester,
      extra: [
        ContextModalAction(
          id: 'artists',
          icon: Icons.person,
          label: 'Artists',
          chips: ContextModalChips(
            items: [
              ContextModalChip(label: 'Alpha', onTap: (_) => picked = 'a'),
              ContextModalChip(label: 'Beta', onTap: (_) {}),
            ],
          ),
        ),
      ],
    );
    expect(find.text('Alpha'), findsNothing);
    await tester.tap(find.text('Artists'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(
      tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
      0.5,
    );
    await tester.tap(find.text('Alpha'));
    expect(picked, 'a');

    await tester.tap(find.text('Artists'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsNothing);
  });

  testWidgets('chips wrap in a sheet', (tester) async {
    await pumpModalApp(
      tester,
      size: const Size(360, 800),
      extra: [
        ContextModalAction(
          id: 'artists',
          icon: Icons.person,
          label: 'Artists',
          chips: ContextModalChips(
            initiallyExpanded: true,
            items: [
              for (var i = 0; i < 8; i++)
                ContextModalChip(label: 'Artist number $i', onTap: (_) {}),
            ],
          ),
        ),
      ],
    );
    expect(find.byType(Wrap), findsOneWidget);
  });

  testWidgets('contextModalSections puts dividers between non-empty groups', (
    tester,
  ) async {
    late List<Widget> out;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          out = contextModalSections(
            ContextModalNav(push: (_) {}, pop: () {}, close: ([_]) {}),
            [
              [ContextModalAction(id: 'a', icon: Icons.info, label: 'A')],
              [],
              [ContextModalAction(id: 'b', icon: Icons.info, label: 'B')],
            ],
          );
          return const SizedBox();
        },
      ),
    );
    expect(out.length, 3);
    expect(out[1], isA<Divider>());
  });
}
