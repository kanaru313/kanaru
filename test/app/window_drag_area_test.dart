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
/// wrapped in [WindowDragExclusion]. Window calls go to [toggles] and [drags], never to
/// the window plugin.
Future<void> pumpArea(
  WidgetTester tester, {
  required List<int> toggles,
  List<int>? drags,
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
        startWindowDragProvider.overrideWithValue(
          () async => drags?.add(drags.length),
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

/// Sends pointer events with real time stamps; `tester.tap` stamps every event
/// with zero, which hides anything the area measures in time.
class Clicker {
  Clicker(this.tester);

  final WidgetTester tester;
  Duration now = Duration.zero;
  int _nextPointer = 1;

  /// Presses at [at] for [hold], optionally moving [moveBy] meanwhile, and
  /// releases at [releaseAt] (default: where it pressed).
  Future<void> click(
    Offset at, {
    Duration hold = const Duration(milliseconds: 40),
    Offset? moveBy,
    int buttons = kPrimaryButton,
    int? pointer,
  }) async {
    final p = TestPointer(
      pointer ?? _nextPointer++,
      PointerDeviceKind.mouse,
      null,
      buttons,
    );
    await tester.sendEventToBinding(p.down(at, timeStamp: now));
    if (moveBy != null) {
      await tester.sendEventToBinding(p.move(at + moveBy, timeStamp: now));
    }
    await wait(hold);
    await tester.sendEventToBinding(p.up(timeStamp: now));
  }

  Future<void> wait(Duration d) async {
    now += d;
    await tester.pump(d);
  }
}

Future<void> doubleClick(
  WidgetTester tester,
  Finder finder, {
  Duration gap = const Duration(milliseconds: 100),
}) async {
  final clicker = Clicker(tester);
  final at = tester.getCenter(finder);
  await clicker.click(at);
  await clicker.wait(gap);
  await clicker.click(at);
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

  testWidgets('clicks without movement toggle once and never start a drag', (
    tester,
  ) async {
    final toggles = <int>[];
    final drags = <int>[];
    await pumpArea(tester, toggles: toggles, drags: drags);

    await doubleClick(tester, find.byKey(_empty));

    expect(toggles, hasLength(1));
    expect(drags, isEmpty);
  });

  testWidgets('a press that moves past the slop starts one drag and is not '
      'a click', (tester) async {
    final toggles = <int>[];
    final drags = <int>[];
    await pumpArea(tester, toggles: toggles, drags: drags);
    final clicker = Clicker(tester);
    final at = tester.getCenter(find.byKey(_empty));

    final p = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(p.down(at, timeStamp: clicker.now));
    await tester.sendEventToBinding(
      p.move(at + const Offset(10, 0), timeStamp: clicker.now),
    );
    await tester.sendEventToBinding(
      p.move(at + const Offset(20, 0), timeStamp: clicker.now),
    );
    await clicker.wait(const Duration(milliseconds: 40));
    // The window manager's synthetic release lands back at the press point.
    await tester.sendEventToBinding(p.up(timeStamp: clicker.now));
    expect(drags, hasLength(1));

    await clicker.wait(const Duration(milliseconds: 60));
    await clicker.click(at);

    expect(toggles, isEmpty);
    expect(drags, hasLength(1));
  });

  testWidgets('a press that moves within the slop is still a click', (
    tester,
  ) async {
    final toggles = <int>[];
    final drags = <int>[];
    await pumpArea(tester, toggles: toggles, drags: drags);
    final clicker = Clicker(tester);
    final at = tester.getCenter(find.byKey(_empty));

    await clicker.click(at, moveBy: const Offset(4, 0));
    await clicker.wait(const Duration(milliseconds: 60));
    await clicker.click(at, moveBy: const Offset(4, 0));

    expect(drags, isEmpty);
    expect(toggles, hasLength(1));
  });

  testWidgets('moving a press that began on a button starts no drag', (
    tester,
  ) async {
    final drags = <int>[];
    await pumpArea(tester, toggles: [], drags: drags);
    final clicker = Clicker(tester);

    await clicker.click(
      tester.getCenter(find.byKey(_button)),
      moveBy: const Offset(0, 30),
    );

    expect(drags, isEmpty);
  });

  testWidgets('a long held press without movement is still a click', (
    tester,
  ) async {
    final toggles = <int>[];
    await pumpArea(tester, toggles: toggles);
    final clicker = Clicker(tester);
    final at = tester.getCenter(find.byKey(_empty));

    await clicker.click(
      at,
      hold: kLongPressTimeout + const Duration(seconds: 1),
    );
    await clicker.wait(const Duration(milliseconds: 100));
    await clicker.click(at);

    expect(toggles, hasLength(1));
  });

  testWidgets('a mouse press that moved past the slop is not a click', (
    tester,
  ) async {
    final toggles = <int>[];
    await pumpArea(tester, toggles: toggles);
    final clicker = Clicker(tester);
    final at = tester.getCenter(find.byKey(_empty));

    // The press ends where it moved to, 30 px away: more than a mouse
    // pointer's slop, less than the double tap slop.
    for (var i = 0; i < 2; i++) {
      final p = TestPointer(1 + i, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(p.down(at, timeStamp: clicker.now));
      await tester.sendEventToBinding(
        p.move(at + const Offset(30, 0), timeStamp: clicker.now),
      );
      await clicker.wait(const Duration(milliseconds: 40));
      await tester.sendEventToBinding(p.up(timeStamp: clicker.now));
      await clicker.wait(const Duration(milliseconds: 60));
    }

    expect(toggles, isEmpty);
  });

  testWidgets('the gap runs from the first release to the second press', (
    tester,
  ) async {
    final toggles = <int>[];
    await pumpArea(tester, toggles: toggles);
    final clicker = Clicker(tester);
    final at = tester.getCenter(find.byKey(_empty));

    // A second press just inside the timeout, held long: a double click,
    // although the two releases are further apart than the timeout.
    await clicker.click(at);
    await clicker.wait(kDoubleTapTimeout - const Duration(milliseconds: 50));
    await clicker.click(at, hold: const Duration(milliseconds: 400));
    expect(toggles, hasLength(1));

    // A second press just past the timeout starts a new pair.
    await clicker.wait(const Duration(seconds: 1));
    await clicker.click(at);
    await clicker.wait(kDoubleTapTimeout + const Duration(milliseconds: 50));
    await clicker.click(at);
    expect(toggles, hasLength(1));
  });

  testWidgets('a second pointer pressed meanwhile keeps the first one\'s '
      'press', (tester) async {
    final toggles = <int>[];
    await pumpArea(tester, toggles: toggles);
    final clicker = Clicker(tester);
    final at = tester.getCenter(find.byKey(_empty));
    final button = tester.getCenter(find.byKey(_button));

    // Pointer 1 presses empty space; pointer 2 presses the button and goes
    // up first. Pointer 1's own press must still be there when it goes up.
    final first = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(first.down(at, timeStamp: clicker.now));
    await clicker.click(button, pointer: 2);
    await tester.sendEventToBinding(first.up(timeStamp: clicker.now));
    await clicker.wait(const Duration(milliseconds: 60));
    await clicker.click(at, pointer: 3);

    expect(toggles, hasLength(1));
  });

  testWidgets('a drag whose release never arrives leaves later clicks '
      'working', (tester) async {
    final toggles = <int>[];
    final drags = <int>[];
    await pumpArea(tester, toggles: toggles, drags: drags);
    final clicker = Clicker(tester);
    final at = tester.getCenter(find.byKey(_empty));

    // The window manager swallows the release: no up, no cancel.
    final lost = TestPointer(99, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(lost.down(at, timeStamp: clicker.now));
    await tester.sendEventToBinding(
      lost.move(at + const Offset(20, 0), timeStamp: clicker.now),
    );
    await tester.sendEventToBinding(
      lost.move(at + const Offset(40, 0), timeStamp: clicker.now),
    );
    expect(drags, hasLength(1));

    await clicker.wait(const Duration(milliseconds: 100));
    await clicker.click(at);
    await clicker.wait(const Duration(milliseconds: 60));
    await clicker.click(at);

    expect(toggles, hasLength(1));
    expect(drags, hasLength(1));
  });
}
