import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'picker_test_host.dart';

void main() {
  testWidgets('the name dialog opens above the picker; Esc closes only it', (
    tester,
  ) async {
    final host = await pumpPickerHost(tester);
    await openPicker(tester);

    await tester.tap(inPicker(find.text('New playlist…')));
    await tester.pumpAndSettle();

    expect(picker, findsOneWidget);
    expect(find.byType(AlertDialog), findsNWidgets(2));
    expect(
      find.text(
        'It is added to the list, checked, and created when you press Add.',
      ),
      findsOneWidget,
    );
    await key(tester, LogicalKeyboardKey.escape);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(picker, findsOneWidget);
    expect(await host.playlistNames(tester), isEmpty);
  });

  testWidgets('Create adds a ticked New row; Cancel then creates nothing', (
    tester,
  ) async {
    final host = await pumpPickerHost(tester);
    await openPicker(tester);

    await nameNew(tester, 'Road trip');

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(inPicker(find.text('Road trip')), findsOneWidget);
    expect(inPicker(find.text('Created when you press Add')), findsOneWidget);
    expect(inPicker(find.text('1 selected')), findsOneWidget);
    final box = tester.widget<CheckboxListTile>(
      inPicker(find.byType(CheckboxListTile)),
    );
    expect(box.value, isTrue);

    await tester.tap(inPicker(find.text('Cancel')));
    await settle(tester);

    expect(picker, findsNothing);
    expect(await host.playlistNames(tester), isEmpty);
  });

  testWidgets('two playlists and a new one go in together, one message', (
    tester,
  ) async {
    final host = await pumpPickerHost(
      tester,
      seed: {'Mix': const [], 'Gym': const []},
    );
    await openPicker(tester);

    expect(inPicker(find.text('2 songs')), findsNothing);
    expect(inPicker(find.text('Road album · 2 songs')), findsOneWidget);
    await tick(tester, 'Mix');
    await tick(tester, 'Gym');
    await nameNew(tester, 'Fresh');
    expect(inPicker(find.text('3 selected')), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add to 3 playlists'));
    await settle(tester);

    expect(picker, findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('2 songs added to 3 playlists (1 new)'), findsOneWidget);
    for (final name in ['Mix', 'Gym', 'Fresh']) {
      expect(await host.pathsIn(tester, name), ['/m/1', '/m/2']);
    }
  });

  testWidgets('shows how many songs a playlist has and hides the excluded', (
    tester,
  ) async {
    late int sourceId;
    final host = await pumpPickerHost(
      tester,
      seed: {
        'Source': const ['/m/1'],
        'Half': const ['/m/2', '/x'],
      },
    );
    sourceId = await host.idOf(tester, 'Source');
    host.excludePlaylistId = sourceId;
    await openPicker(tester);

    expect(inPicker(find.text('2 songs · has 1 of them')), findsOneWidget);
    expect(inPicker(find.text('Source')), findsNothing);
    expect(await host.pathsIn(tester, 'Half'), ['/m/2', '/x']);
  });

  testWidgets('a playlist already holding a song gets only the missing one', (
    tester,
  ) async {
    final host = await pumpPickerHost(
      tester,
      seed: {
        'Half': const ['/m/2'],
        'Empty': const [],
      },
    );
    await openPicker(tester);

    await tick(tester, 'Half');
    await tick(tester, 'Empty');
    await tester.tap(addButton);
    await settle(tester);

    expect(await host.pathsIn(tester, 'Half'), ['/m/2', '/m/1']);
    expect(await host.pathsIn(tester, 'Empty'), ['/m/1', '/m/2']);
    expect(find.textContaining('2 songs added to 2 playlists'), findsOneWidget);
    expect(find.textContaining('1 skipped'), findsOneWidget);
  });
}
