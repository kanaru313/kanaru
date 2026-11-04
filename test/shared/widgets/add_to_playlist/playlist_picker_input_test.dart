import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:material_ui/material_ui.dart';

import 'picker_test_host.dart';

bool _focusIn<T extends Widget>() =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<T>() !=
    null;

void main() {
  testWidgets('Down moves to a playlist row, Space toggles it', (tester) async {
    await pumpPickerHost(tester, seed: {'Mix': const []});
    await openPicker(tester, viaKeyboard: true);

    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(_focusIn<CheckboxListTile>(), isTrue);
    await key(tester, LogicalKeyboardKey.space);

    expect(inPicker(find.text('1 selected')), findsOneWidget);
    await key(tester, LogicalKeyboardKey.space);
    expect(inPicker(find.text('1 selected')), findsNothing);
  });

  testWidgets('Enter on a playlist row presses Add', (tester) async {
    final host = await pumpPickerHost(tester, seed: {'Mix': const []});
    await openPicker(tester, viaKeyboard: true);

    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.space);
    await key(tester, LogicalKeyboardKey.enter);
    await settle(tester);

    expect(picker, findsNothing);
    expect(await host.pathsIn(tester, 'Mix'), ['/m/1', '/m/2']);
  });

  testWidgets('Enter on a row does nothing while nothing is ticked', (
    tester,
  ) async {
    await pumpPickerHost(tester, seed: {'Mix': const []});
    await openPicker(tester, viaKeyboard: true);

    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.enter);

    expect(picker, findsOneWidget);
  });

  testWidgets('Enter on a focused Cancel closes without writing', (
    tester,
  ) async {
    final host = await pumpPickerHost(tester, seed: {'Mix': const []});
    await openPicker(tester, viaKeyboard: true);
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.space);

    for (var i = 0; i < 10 && !_focusIn<TextButton>(); i++) {
      await key(tester, LogicalKeyboardKey.tab);
    }
    expect(_focusIn<TextButton>(), isTrue);
    await key(tester, LogicalKeyboardKey.enter);
    await settle(tester);

    expect(picker, findsNothing);
    expect(await host.pathsIn(tester, 'Mix'), isEmpty);
  });

  testWidgets('Enter on the New row opens the name dialog', (tester) async {
    await pumpPickerHost(tester);
    await openPicker(tester, viaKeyboard: true);

    await key(tester, LogicalKeyboardKey.enter);

    expect(find.byType(AlertDialog), findsNWidgets(2));
    expect(picker, findsOneWidget);
  });

  testWidgets('while paths load, Add holds the picker inert until done', (
    tester,
  ) async {
    final paths = Completer<List<String>>();
    final host = await pumpPickerHost(
      tester,
      seed: {'Mix': const []},
      configure: (h) => h.readPaths = () => paths.future,
    );
    await openPicker(tester);
    await tick(tester, 'Mix');
    await tester.tap(addButton);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.tap(inPicker(find.text('New playlist…')), warnIfMissed: false);
    await tester.pump();
    expect(picker, findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);

    paths.complete(['/m/1']);
    await settle(tester);

    expect(picker, findsNothing);
    expect(await host.pathsIn(tester, 'Mix'), ['/m/1']);
    expect(find.text('Added to Mix: Road album'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a read failure closes the picker and says so', (tester) async {
    final host = await pumpPickerHost(
      tester,
      seed: {'Mix': const []},
      configure: (h) => h.readPaths = () async => throw StateError('gone'),
    );
    await openPicker(tester);
    await tick(tester, 'Mix');
    await tester.tap(addButton);
    await settle(tester);

    expect(picker, findsNothing);
    expect(
      find.text("Couldn't save the playlist. See the log for details."),
      findsOneWidget,
    );
    expect(await host.pathsIn(tester, 'Mix'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no songs to add closes the picker silently', (tester) async {
    await pumpPickerHost(
      tester,
      seed: {'Mix': const []},
      configure: (h) => h.readPaths = () async => const [],
    );
    await openPicker(tester);
    await tick(tester, 'Mix');
    await tester.tap(addButton);
    await settle(tester);

    expect(picker, findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Cancel and Esc do nothing while Add waits for the paths', (
    tester,
  ) async {
    final paths = Completer<List<String>>();
    await pumpPickerHost(
      tester,
      seed: {'Mix': const []},
      configure: (h) => h.readPaths = () => paths.future,
    );
    await openPicker(tester);
    await tick(tester, 'Mix');
    await tester.tap(addButton);
    await tester.pump();

    await tester.tap(inPicker(find.text('Cancel')), warnIfMissed: false);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(picker, findsOneWidget);

    paths.complete(['/m/1']);
    await settle(tester);
    expect(picker, findsNothing);
  });

  testWidgets('Space on the New row opens the name dialog', (tester) async {
    await pumpPickerHost(tester);
    await openPicker(tester, viaKeyboard: true);

    await key(tester, LogicalKeyboardKey.space);

    expect(find.byType(AlertDialog), findsNWidgets(2));
  });

  testWidgets('a playlist deleted while the picker is open is not added', (
    tester,
  ) async {
    final host = await pumpPickerHost(
      tester,
      seed: {'Mix': const [], 'Gym': const []},
    );
    await openPicker(tester);
    await tick(tester, 'Mix');
    await tick(tester, 'Gym');
    expect(inPicker(find.text('2 selected')), findsOneWidget);

    final mix = await host.idOf(tester, 'Mix');
    await tester.runAsync(() => host.db.deletePlaylist(mix));
    await settle(tester);

    expect(inPicker(find.text('1 selected')), findsOneWidget);
    await tester.tap(addButton);
    await settle(tester);
    expect(await host.pathsIn(tester, 'Gym'), ['/m/1', '/m/2']);
    expect(find.text('Added to Gym: Road album'), findsOneWidget);
  });

  testWidgets('Add is disabled when every ticked playlist is deleted', (
    tester,
  ) async {
    final host = await pumpPickerHost(tester, seed: {'Mix': const []});
    await openPicker(tester);
    await tick(tester, 'Mix');

    final mix = await host.idOf(tester, 'Mix');
    await tester.runAsync(() => host.db.deletePlaylist(mix));
    await settle(tester);

    expect(inPicker(find.text('1 selected')), findsNothing);
    expect(tester.widget<FilledButton>(addButton).onPressed, isNull);
  });
}
