import 'dart:ui' show Tristate;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/marquee_text.dart';
import 'package:kanaru/shared/widgets/picker_field_button.dart';
import 'package:kanaru/shared/widgets/selection_row.dart';
import 'package:material_ui/material_ui.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 360, child: child)),
  ),
);

void main() {
  testWidgets(
    'selected row has secondaryContainer fill and check; unselected has neither and keeps the same title width',
    (tester) async {
      await tester.pumpWidget(
        _host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectionRow(
                key: const ValueKey('selected-row'),
                title: 'Japanese',
                subtitle: 'Detected',
                selected: true,
                onTap: () {},
              ),
              SelectionRow(
                key: const ValueKey('unselected-row'),
                title: 'Vietnamese',
                subtitle: 'Target',
                selected: false,
                onTap: () {},
              ),
            ],
          ),
        ),
      );

      final selectedRow = find.byKey(const ValueKey('selected-row'));
      final unselectedRow = find.byKey(const ValueKey('unselected-row'));
      final scheme = Theme.of(tester.element(selectedRow)).colorScheme;

      final selectedMaterial = tester.widget<Material>(
        find.descendant(of: selectedRow, matching: find.byType(Material)).first,
      );
      final unselectedMaterial = tester.widget<Material>(
        find
            .descendant(of: unselectedRow, matching: find.byType(Material))
            .first,
      );
      expect(selectedMaterial.color, scheme.secondaryContainer);
      expect(unselectedMaterial.color, Colors.transparent);

      expect(
        find.descendant(of: selectedRow, matching: find.byIcon(AppIcons.check)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: unselectedRow,
          matching: find.byIcon(AppIcons.check),
        ),
        findsNothing,
      );

      final selectedTitleWidth = tester
          .getSize(
            find.descendant(
              of: selectedRow,
              matching: find.byType(MarqueeText),
            ),
          )
          .width;
      final unselectedTitleWidth = tester
          .getSize(
            find.descendant(
              of: unselectedRow,
              matching: find.byType(MarqueeText),
            ),
          )
          .width;
      expect(selectedTitleWidth, unselectedTitleWidth);
    },
  );

  testWidgets('tap, Enter and Space invoke onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        SelectionRow(
          title: 'English',
          selected: false,
          autofocus: true,
          onTap: () => taps++,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(SelectionRow));
    await tester.pump();
    expect(taps, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 3);
  });

  testWidgets('exposes selected state in semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectionRow(
              key: const ValueKey('on'),
              title: 'Selected option',
              selected: true,
              onTap: () {},
            ),
            SelectionRow(
              key: const ValueKey('off'),
              title: 'Other option',
              selected: false,
              onTap: () {},
            ),
          ],
        ),
      ),
    );

    final onData = tester
        .getSemantics(find.byKey(const ValueKey('on')))
        .getSemanticsData();
    final offData = tester
        .getSemantics(find.byKey(const ValueKey('off')))
        .getSemanticsData();
    expect(onData.flagsCollection.isSelected, Tristate.isTrue);
    expect(offData.flagsCollection.isSelected, Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('disabled row reports enabled=false in semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const SelectionRow(
          key: ValueKey('off'),
          title: 'Off',
          selected: false,
          onTap: null,
        ),
      ),
    );
    final data = tester
        .getSemantics(find.byKey(const ValueKey('off')))
        .getSemanticsData();
    expect(data.flagsCollection.isEnabled, Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('PickerFieldButton shows label and chevron and dims when null', (
    tester,
  ) async {
    var pressed = 0;
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PickerFieldButton(
              key: const ValueKey('enabled-btn'),
              label: 'Vietnamese',
              onPressed: () => pressed++,
            ),
            const PickerFieldButton(
              key: ValueKey('disabled-btn'),
              label: 'Disabled',
              onPressed: null,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Vietnamese'), findsOneWidget);
    expect(find.byIcon(AppIcons.expandMore), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('enabled-btn')));
    expect(pressed, 1);

    final disabledOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('disabled-btn')),
        matching: find.byType(Opacity),
      ),
    );
    expect(disabledOpacity.opacity, lessThan(1));
  });

  testWidgets('disabled row is dimmed and an enabled row is not', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SelectionRow(
              key: ValueKey('off'),
              title: 'Off',
              selected: false,
              onTap: null,
            ),
            SelectionRow(
              key: const ValueKey('on'),
              title: 'On',
              selected: false,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
    double opacityOf(String key) => tester
        .widget<Opacity>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    expect(opacityOf('off'), 0.38);
    expect(opacityOf('on'), 1);
  });

  testWidgets('trailing replaces the check and keeps the title width', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectionRow(
              key: const ValueKey('with'),
              title: 'A',
              selected: true,
              onTap: () {},
              trailing: const Icon(Icons.search, size: 24),
            ),
            SelectionRow(
              key: const ValueKey('without'),
              title: 'A',
              selected: false,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
    final withRow = find.byKey(const ValueKey('with'));
    expect(
      find.descendant(of: withRow, matching: find.byIcon(AppIcons.check)),
      findsNothing,
    );
    expect(
      find.descendant(of: withRow, matching: find.byIcon(Icons.search)),
      findsOneWidget,
    );
    double titleWidth(String key) => tester
        .getSize(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(MarqueeText),
          ),
        )
        .width;
    expect(titleWidth('with'), titleWidth('without'));
  });

  testWidgets('details is drawn under the subtitle', (tester) async {
    await tester.pumpWidget(
      _host(
        SelectionRow(
          title: 'T',
          subtitle: 'Sub',
          selected: false,
          onTap: () {},
          details: const Text('Badge'),
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.text('Badge')).dy,
      greaterThan(tester.getTopLeft(find.text('Sub')).dy),
    );
  });
}
