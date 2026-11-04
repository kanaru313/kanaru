import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'picker_test_host.dart';

/// True when the primary focus sits on a widget inside the open picker.
bool _focusInPicker() {
  final focus = FocusManager.instance.primaryFocus;
  if (focus == null || focus is FocusScopeNode) return false;
  final ctx = focus.context;
  if (ctx == null) return false;
  return find
      .descendant(
        of: picker,
        matching: find.byElementPredicate((e) => e == ctx),
      )
      .evaluate()
      .isNotEmpty;
}

/// True when the primary focus sits on the "New playlist…" row.
bool _focusOnNewPlaylist() {
  final focus = FocusManager.instance.primaryFocus;
  if (focus == null || focus is FocusScopeNode) return false;
  final tile = focus.context?.findAncestorWidgetOfExactType<ListTile>();
  if (tile == null) return false;
  final title = tile.title;
  return title is Text && title.data == 'New playlist…';
}

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  testWidgets(
    'a mouse click opens the picker with no focus inside',
    (tester) async {
      await pumpPickerHost(tester, seed: {'Mix': const []});
      await openPicker(tester, viaKeyboard: false);

      expect(picker, findsOneWidget);
      expect(_focusInPicker(), isFalse);
      expect(_focusOnNewPlaylist(), isFalse);
    },
  );

  testWidgets(
    'opening via keyboard focuses "New playlist…" at once',
    (tester) async {
      await pumpPickerHost(tester, seed: {'Mix': const []});
      await openPicker(tester, viaKeyboard: true);

      expect(picker, findsOneWidget);
      expect(_focusInPicker(), isTrue);
      expect(_focusOnNewPlaylist(), isTrue);
    },
  );

  testWidgets(
    'Down arrow on an unfocused picker lands on "New playlist…"',
    (tester) async {
      await pumpPickerHost(tester, seed: {'Mix': const []});
      await openPicker(tester, viaKeyboard: false);

      expect(_focusInPicker(), isFalse);

      await key(tester, LogicalKeyboardKey.arrowDown);

      expect(_focusInPicker(), isTrue);
      expect(_focusOnNewPlaylist(), isTrue);
    },
  );

  testWidgets(
    'Tab on an unfocused picker lands on "New playlist…"',
    (tester) async {
      await pumpPickerHost(tester, seed: {'Mix': const []});
      await openPicker(tester, viaKeyboard: false);

      expect(_focusInPicker(), isFalse);

      await key(tester, LogicalKeyboardKey.tab);

      expect(_focusInPicker(), isTrue);
      expect(_focusOnNewPlaylist(), isTrue);
    },
  );

  testWidgets(
    'Up arrow on an unfocused picker lands on "New playlist…"',
    (tester) async {
      await pumpPickerHost(tester, seed: {'Mix': const []});
      await openPicker(tester, viaKeyboard: false);

      expect(_focusInPicker(), isFalse);

      await key(tester, LogicalKeyboardKey.arrowUp);

      expect(_focusInPicker(), isTrue);
      expect(_focusOnNewPlaylist(), isTrue);
    },
  );
}
