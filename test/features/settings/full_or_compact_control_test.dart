import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/settings/full_or_compact_control.dart';
import 'package:material_ui/material_ui.dart';

/// Natural width of the full control; the compact one is [_compactWidth].
const _fullWidth = 300.0;
const _compactWidth = 200.0;

/// Room in which the full control fits, and in which it does not.
const _roomy = 400.0;
const _tight = 250.0;

void main() {
  late _Controls controls;
  setUp(() => controls = _Controls());

  testWidgets('Tab skips the hidden control', (tester) async {
    await controls.pump(tester, width: _roomy);
    expect(controls.shown(), 'full');

    controls.before.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controls.full.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controls.after.hasFocus, isTrue, reason: 'compact skipped');

    await controls.pump(tester, width: _tight);
    expect(controls.shown(), 'compact');
    controls.before.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controls.compact.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controls.after.hasFocus, isTrue, reason: 'full skipped');
  });

  testWidgets('the semantics tree has only the shown control', (tester) async {
    final semantics = tester.ensureSemantics();
    await controls.pump(tester, width: _roomy);
    for (final label in ['Before', 'Full', 'After']) {
      expect(find.semantics.byLabel(label), findsOne, reason: label);
    }
    expect(find.semantics.byLabel('Compact'), findsNothing);

    await controls.pump(tester, width: _tight);
    expect(find.semantics.byLabel('Compact'), findsOne);
    expect(find.semantics.byLabel('Full'), findsNothing);
    semantics.dispose();
  });

  testWidgets('taps where the hidden control sits do not reach it', (
    tester,
  ) async {
    // The hidden compact control lies under the left part of the full one.
    await controls.pump(tester, width: _roomy);
    final hiddenCompact = find.byKey(controls.compactKey, skipOffstage: false);
    expect(hiddenCompact, findsOneWidget, reason: 'built and laid out');
    expect(find.byKey(controls.compactKey), findsNothing, reason: 'offstage');
    expect(hiddenCompact.hitTestable(), findsNothing);
    await tester.tapAt(tester.getCenter(hiddenCompact));
    await tester.pump();
    expect(controls.taps, ['full']);

    // The hidden full control reaches right of the compact one.
    controls.taps.clear();
    await controls.pump(tester, width: _tight);
    final hiddenFull = find.byKey(controls.fullKey, skipOffstage: false);
    expect(hiddenFull, findsOneWidget);
    expect(hiddenFull.hitTestable(), findsNothing);
    final topLeft = tester.getTopLeft(hiddenFull);
    await tester.tapAt(topLeft + const Offset(_fullWidth - 10, 20));
    await tester.pump();
    expect(controls.taps, isEmpty);

    await tester.tapAt(topLeft + const Offset(10, 20));
    await tester.pump();
    expect(controls.taps, ['compact'], reason: 'the shown one still works');
  });

  testWidgets('the choice follows the width, both ways', (tester) async {
    for (final (width, shown) in [
      (_roomy, 'full'),
      (_tight, 'compact'),
      (_roomy, 'full'),
      (_tight, 'compact'),
    ]) {
      await controls.pump(tester, width: width);
      expect(controls.shown(), shown, reason: 'at $width px');
      final size = tester.getSize(find.byType(FullOrCompactControl));
      expect(
        size.width,
        shown == 'full' ? _fullWidth : _compactWidth,
        reason: 'at $width px',
      );
    }
  });

  testWidgets('forcing the compact control keeps it mounted and focused', (
    tester,
  ) async {
    await controls.pump(tester, width: _tight);
    controls.compact.requestFocus();
    await tester.pump();
    expect(controls.mounts['compact'], 1);

    await controls.pump(tester, width: _roomy, forceCompact: true);
    expect(controls.shown(), 'compact');
    expect(controls.compact.hasFocus, isTrue);
    expect(controls.mounts['compact'], 1, reason: 'not remounted');

    await controls.pump(tester, width: _tight);
    expect(controls.compact.hasFocus, isTrue);
    expect(controls.mounts['compact'], 1);
  });

  testWidgets('focus follows the control when the choice flips', (
    tester,
  ) async {
    await controls.pump(tester, width: _roomy);
    controls.full.requestFocus();
    await tester.pump();

    await controls.pump(tester, width: _tight);
    expect(controls.compact.hasFocus, isTrue);
    expect(controls.mounts['compact'], 1, reason: 'the shown one lives on');

    await controls.pump(tester, width: _roomy);
    expect(controls.full.hasFocus, isTrue);

    // Focus elsewhere stays where it is.
    controls.after.requestFocus();
    await tester.pump();
    await controls.pump(tester, width: _tight);
    expect(controls.after.hasFocus, isTrue);
  });

  testWidgets('a menu open in the control closes when it is hidden', (
    tester,
  ) async {
    final menu = MenuController();
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: _tight, child: _menuControl(menu)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownMenu<int>));
    await tester.pumpAndSettle();
    expect(menu.isOpen, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: _roomy, child: _menuControl(menu)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Full'), findsOneWidget);
    expect(menu.isOpen, isFalse);
  });
}

/// A full control that does not fit [_tight], and a dropdown as the compact
/// one.
Widget _menuControl(MenuController menu) => Align(
  alignment: Alignment.topLeft,
  child: FullOrCompactControl(
    full: const SizedBox(width: _fullWidth, height: 40, child: Text('Full')),
    compact: DropdownMenu<int>(
      menuController: menu,
      width: _compactWidth,
      requestFocusOnTap: false,
      initialSelection: 1,
      dropdownMenuEntries: const [
        DropdownMenuEntry(value: 1, label: 'One'),
        DropdownMenuEntry(value: 2, label: 'Two'),
      ],
    ),
    compactWidth: _compactWidth,
  ),
);

/// Buttons before and after a [FullOrCompactControl] of two buttons, with
/// the focus nodes, taps and mounts of each.
class _Controls {
  final before = FocusNode(debugLabel: 'before');
  final after = FocusNode(debugLabel: 'after');
  final full = FocusNode(debugLabel: 'full');
  final compact = FocusNode(debugLabel: 'compact');
  final fullKey = GlobalKey(debugLabel: 'full');
  final compactKey = GlobalKey(debugLabel: 'compact');
  final taps = <String>[];
  final mounts = <String, int>{};
  bool _disposeAdded = false;

  void _dispose() {
    for (final node in [before, after, full, compact]) {
      node.dispose();
    }
  }

  /// Which control widget finders see.
  String? shown() {
    final full = find.byKey(fullKey).evaluate().isNotEmpty;
    final compact = find.byKey(compactKey).evaluate().isNotEmpty;
    expect(full && compact, isFalse, reason: 'never both');
    return full ? 'full' : (compact ? 'compact' : null);
  }

  /// Shows the control [width] wide; settles, so a new choice is applied.
  Future<void> pump(
    WidgetTester tester, {
    required double width,
    bool forceCompact = false,
  }) async {
    if (!_disposeAdded) {
      _disposeAdded = true;
      addTearDown(_dispose);
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _button('Before', before),
              SizedBox(
                width: width,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: FullOrCompactControl(
                    full: _counted(
                      'full',
                      SizedBox(
                        key: fullKey,
                        width: _fullWidth,
                        height: 40,
                        child: _button('Full', full),
                      ),
                    ),
                    compact: _counted(
                      'compact',
                      SizedBox(
                        key: compactKey,
                        height: 40,
                        child: _button('Compact', compact),
                      ),
                    ),
                    compactWidth: _compactWidth,
                    forceCompact: forceCompact,
                  ),
                ),
              ),
              _button('After', after),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget _button(String label, FocusNode node) => TextButton(
    focusNode: node,
    onPressed: () => taps.add(label.toLowerCase()),
    child: Text(label),
  );

  Widget _counted(String name, Widget child) => _MountCounter(
    onMount: () => mounts[name] = (mounts[name] ?? 0) + 1,
    child: child,
  );
}

/// Calls [onMount] each time it is mounted.
class _MountCounter extends StatefulWidget {
  const _MountCounter({required this.onMount, required this.child});

  final VoidCallback onMount;
  final Widget child;

  @override
  State<_MountCounter> createState() => _MountCounterState();
}

class _MountCounterState extends State<_MountCounter> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
