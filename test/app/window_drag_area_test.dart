import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/shell/window/desktop_window.dart';
import 'package:kanaru/app/shell/window/window_drag_area.dart';
import 'package:material_ui/material_ui.dart';

const _empty = Key('empty');
const _button = Key('button');
const _field = Key('field');

/// Pumps a drag area with an empty region, a button and a text field, both
/// wrapped in [WindowDragExclusion]. Window calls go to [toggles], never to
/// the window plugin.
Future<void> pumpArea(
  WidgetTester tester, {
  required List<int> toggles,
  VoidCallback? onButton,
  bool doubleClickMaximizes = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customTitleBarProvider.overrideWithValue(true),
        toggleMaximizeProvider.overrideWithValue(
          () async => toggles.add(toggles.length),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: WindowDragArea(
            doubleClickMaximizes: doubleClickMaximizes,
            child: Row(
              children: [
                const Expanded(
                  child: ColoredBox(
                    key: _empty,
                    color: Colors.transparent,
                    child: SizedBox(height: 64),
                  ),
                ),
                WindowDragExclusion(
                  child: TextButton(
                    key: _button,
                    onPressed: onButton ?? () {},
                    child: const Text('go'),
                  ),
                ),
                const WindowDragExclusion(
                  child: SizedBox(width: 160, child: TextField(key: _field)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> doubleClick(
  WidgetTester tester,
  Finder finder, {
  Duration gap = const Duration(milliseconds: 100),
}) async {
  await tester.tap(finder);
  await tester.pump(gap);
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  testWidgets('a button inside the drag area fires on pointer up', (
    tester,
  ) async {
    var taps = 0;
    await pumpArea(tester, toggles: [], onButton: () => taps++);

    await tester.tap(find.byKey(_button));
    // No time passes: a double tap recognizer above would still hold the tap.
    await tester.pump(Duration.zero);

    expect(taps, 1);
  });

  testWidgets('double click on empty space toggles maximize once', (
    tester,
  ) async {
    final toggles = <int>[];
    await pumpArea(tester, toggles: toggles);

    await doubleClick(tester, find.byKey(_empty));

    expect(toggles, hasLength(1));
  });

  testWidgets('a third click does not toggle again', (tester) async {
    final toggles = <int>[];
    await pumpArea(tester, toggles: toggles);

    await doubleClick(tester, find.byKey(_empty));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(_empty));
    await tester.pump();

    expect(toggles, hasLength(1));
  });

  testWidgets('two single clicks far apart in time do not toggle', (
    tester,
  ) async {
    final toggles = <int>[];
    await pumpArea(tester, toggles: toggles);

    await doubleClick(
      tester,
      find.byKey(_empty),
      gap: kDoubleTapTimeout + const Duration(milliseconds: 100),
    );

    expect(toggles, isEmpty);
  });

  testWidgets('double click in the search field does not toggle', (
    tester,
  ) async {
    final toggles = <int>[];
    await pumpArea(tester, toggles: toggles);

    await doubleClick(tester, find.byKey(_field));

    expect(toggles, isEmpty);
  });

  testWidgets('double click on a button does not toggle', (tester) async {
    final toggles = <int>[];
    var taps = 0;
    await pumpArea(tester, toggles: toggles, onButton: () => taps++);

    await doubleClick(tester, find.byKey(_button));

    expect(taps, 2);
    expect(toggles, isEmpty);
  });

  testWidgets('a click on a button then one on empty space does not toggle', (
    tester,
  ) async {
    final toggles = <int>[];
    await pumpArea(tester, toggles: toggles);

    await tester.tap(find.byKey(_button));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(_empty));
    await tester.pump();

    expect(toggles, isEmpty);
  });

  testWidgets('double click does nothing when the area opts out', (
    tester,
  ) async {
    final toggles = <int>[];
    await pumpArea(tester, toggles: toggles, doubleClickMaximizes: false);

    await doubleClick(tester, find.byKey(_empty));

    expect(toggles, isEmpty);
  });

  testWidgets('right button double click does not toggle', (tester) async {
    final toggles = <int>[];
    await pumpArea(tester, toggles: toggles);

    final center = tester.getCenter(find.byKey(_empty));
    for (var i = 0; i < 2; i++) {
      final gesture = await tester.startGesture(
        center,
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(toggles, isEmpty);
  });
}
