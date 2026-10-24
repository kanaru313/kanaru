import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/shell/top_bar_search_shortcuts.dart';
import 'package:kanaru/shared/in_page_filter_registry.dart';
import 'package:material_ui/material_ui.dart';

class _Harness extends StatefulWidget {
  const _Harness({this.nowPlayingOpen = false, this.onOtherKey});

  final bool nowPlayingOpen;
  final void Function(LogicalKeyboardKey key)? onOtherKey;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final controller = TextEditingController(text: 'abba');
  final field = FocusNode();
  final button = FocusNode();
  final other = FocusNode();
  late final TopBarSearchShortcuts shortcuts;

  @override
  void initState() {
    super.initState();
    shortcuts = TopBarSearchShortcuts(
      focusNode: field,
      controller: controller,
      isNowPlayingOpen: () => widget.nowPlayingOpen,
    )..attach();
  }

  @override
  void dispose() {
    shortcuts.detach();
    controller.dispose();
    field.dispose();
    button.dispose();
    other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent) widget.onOtherKey?.call(event.logicalKey);
          return KeyEventResult.ignored;
        },
        child: Column(
          children: [
            TextField(controller: controller, focusNode: field),
            TextButton(
              focusNode: button,
              onPressed: () {},
              child: const Text('button'),
            ),
            TextField(key: const Key('other'), focusNode: other),
          ],
        ),
      ),
    );
  }
}

Future<_HarnessState> _pump(
  WidgetTester tester, {
  bool nowPlayingOpen = false,
  void Function(LogicalKeyboardKey key)? onOtherKey,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: _Harness(nowPlayingOpen: nowPlayingOpen, onOtherKey: onOtherKey),
    ),
  );
  return tester.state<_HarnessState>(find.byType(_Harness));
}

Future<void> _ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

void main() {
  testWidgets('Ctrl+F focuses the field and selects its text', (tester) async {
    final state = await _pump(tester);
    state.button.requestFocus();
    await tester.pump();

    await _ctrl(tester, LogicalKeyboardKey.keyF);
    await tester.pump();

    expect(state.field.hasFocus, isTrue);
    expect(
      state.controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 4),
    );
  });

  testWidgets('Ctrl+F works while another text field has focus', (
    tester,
  ) async {
    final state = await _pump(tester);
    state.other.requestFocus();
    await tester.pump();

    await _ctrl(tester, LogicalKeyboardKey.keyF);
    await tester.pump();

    expect(state.field.hasFocus, isTrue);
  });

  testWidgets('slash focuses the field when no text input has focus', (
    tester,
  ) async {
    final state = await _pump(tester);
    state.button.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '/');
    await tester.pump();

    expect(state.field.hasFocus, isTrue);
    expect(state.controller.selection.extentOffset, 4);
  });

  testWidgets('slash is typed when a text input has focus', (tester) async {
    final state = await _pump(tester);
    state.other.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '/');
    await tester.pump();

    expect(state.other.hasFocus, isTrue);
    expect(state.field.hasFocus, isFalse);
  });

  testWidgets('keys the player uses still reach the focus tree', (
    tester,
  ) async {
    final seen = <LogicalKeyboardKey>[];
    final state = await _pump(tester, onOtherKey: seen.add);
    state.button.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _ctrl(tester, LogicalKeyboardKey.keyS);
    await _ctrl(tester, LogicalKeyboardKey.keyR);
    // F without Ctrl is only a letter.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);

    expect(seen, [
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyR,
      LogicalKeyboardKey.keyF,
    ]);
    expect(state.field.hasFocus, isFalse);
  });

  testWidgets('Ctrl+Shift+F is left alone', (tester) async {
    final state = await _pump(tester);
    state.button.requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await _ctrl(tester, LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    expect(state.field.hasFocus, isFalse);
  });

  testWidgets('nothing happens while a dialog is open', (tester) async {
    final state = await _pump(tester);
    final context = tester.element(find.byType(Scaffold));
    showDialog<void>(
      context: context,
      builder: (_) =>
          const AlertDialog(content: Focus(autofocus: true, child: Text('x'))),
    );
    await tester.pumpAndSettle();
    expect(state.button.hasFocus, isFalse);

    await _ctrl(tester, LogicalKeyboardKey.keyF);
    await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '/');
    await tester.pump();

    expect(state.field.hasFocus, isFalse);
  });

  testWidgets('nothing happens while a menu is open', (tester) async {
    final state = await _pump(tester);
    final context = tester.element(find.byType(Scaffold));
    showMenu<void>(
      context: context,
      position: RelativeRect.fill,
      items: const [PopupMenuItem<void>(child: Text('item'))],
    );
    await tester.pumpAndSettle();

    await _ctrl(tester, LogicalKeyboardKey.keyF);
    await tester.pump();

    expect(state.field.hasFocus, isFalse);
  });

  testWidgets('nothing happens while Now Playing is open', (tester) async {
    final state = await _pump(tester, nowPlayingOpen: true);
    state.button.requestFocus();
    await tester.pump();

    await _ctrl(tester, LogicalKeyboardKey.keyF);
    await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '/');
    await tester.pump();

    expect(state.field.hasFocus, isFalse);
  });

  testWidgets('Ctrl+F in the field selects its text and skips page filters', (
    tester,
  ) async {
    final state = await _pump(tester);
    var opened = 0;
    final handle = InPageFilterHandle(
      context: tester.element(find.byType(Scaffold)),
      open: () => opened++,
      hasFocus: () => false,
    );
    InPageFilterRegistry.instance.register(handle);
    addTearDown(() => InPageFilterRegistry.instance.unregister(handle));
    state.field.requestFocus();
    await tester.pump();
    state.controller.selection = const TextSelection.collapsed(offset: 1);

    await _ctrl(tester, LogicalKeyboardKey.keyF);
    await tester.pump();

    expect(opened, 0);
    expect(state.field.hasFocus, isTrue);
    expect(
      state.controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 4),
    );
  });

  testWidgets('a held slash is consumed after it focused the field', (
    tester,
  ) async {
    final state = await _pump(tester);
    state.button.requestFocus();
    await tester.pump();

    final down = await tester.sendKeyDownEvent(
      LogicalKeyboardKey.slash,
      character: '/',
    );
    await tester.pump();
    expect(state.field.hasFocus, isTrue);
    final repeat = await tester.sendKeyRepeatEvent(
      LogicalKeyboardKey.slash,
      character: '/',
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.slash);
    expect(down, isTrue);
    expect(repeat, isTrue);

    // A slash pressed inside the field later is left to the field.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.slash, character: '/');
    final typedRepeat = await tester.sendKeyRepeatEvent(
      LogicalKeyboardKey.slash,
      character: '/',
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.slash);
    expect(typedRepeat, isFalse);
  });

  group('page filter', () {
    testWidgets('Ctrl+F opens the page filter instead of the field', (
      tester,
    ) async {
      final state = await _pump(tester);
      var opened = 0;
      final handle = InPageFilterHandle(
        context: tester.element(find.byType(Scaffold)),
        open: () => opened++,
        hasFocus: () => false,
      );
      InPageFilterRegistry.instance.register(handle);
      addTearDown(() => InPageFilterRegistry.instance.unregister(handle));
      state.button.requestFocus();
      await tester.pump();

      await _ctrl(tester, LogicalKeyboardKey.keyF);
      await tester.pump();

      expect(opened, 1);
      expect(state.field.hasFocus, isFalse);
    });

    testWidgets('Ctrl+F inside the page filter goes to the field', (
      tester,
    ) async {
      final state = await _pump(tester);
      var opened = 0;
      final handle = InPageFilterHandle(
        context: tester.element(find.byType(Scaffold)),
        open: () => opened++,
        hasFocus: () => true,
      );
      InPageFilterRegistry.instance.register(handle);
      addTearDown(() => InPageFilterRegistry.instance.unregister(handle));
      state.other.requestFocus();
      await tester.pump();

      await _ctrl(tester, LogicalKeyboardKey.keyF);
      await tester.pump();

      expect(opened, 0);
      expect(state.field.hasFocus, isTrue);
    });

    testWidgets('slash ignores the page filter', (tester) async {
      final state = await _pump(tester);
      var opened = 0;
      final handle = InPageFilterHandle(
        context: tester.element(find.byType(Scaffold)),
        open: () => opened++,
        hasFocus: () => false,
      );
      InPageFilterRegistry.instance.register(handle);
      addTearDown(() => InPageFilterRegistry.instance.unregister(handle));
      state.button.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '/');
      await tester.pump();

      expect(opened, 0);
      expect(state.field.hasFocus, isTrue);
    });
  });

  testWidgets('the handler is removed on dispose', (tester) async {
    final state = await _pump(tester);
    final field = state.field;
    await tester.pumpWidget(const SizedBox());

    // A leftover handler would touch the disposed focus node and throw.
    await _ctrl(tester, LogicalKeyboardKey.keyF);
    expect(tester.takeException(), isNull);
    expect(field.hasFocus, isFalse);
  });
}
