import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'picker_test_host.dart';

Finder get question => find.text('Already in playlist');

Finder get confirm => find.widgetWithText(FilledButton, 'Confirm');

/// Presses the picker's Add and waits for the question. The picker shows a
/// spinner while it is busy, so nothing settles until the question closes.
Future<void> pressAdd(WidgetTester tester) async {
  await tester.tap(addButton);
  for (var i = 0; i < 50 && question.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(question, findsWidgets, reason: 'the question never appeared');
  await tester.pump(const Duration(milliseconds: 500));
}

/// Ticks [names], presses Add and picks [option] in the question.
Future<void> addChoosing(
  WidgetTester tester,
  List<String> names,
  String option,
) async {
  for (final name in names) {
    await tick(tester, name);
  }
  await pressAdd(tester);
  await tester.tap(find.text(option));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(confirm);
  await settle(tester);
}

void main() {
  const seed = {
    'Half': ['/m/2'],
    'Empty': <String>[],
  };

  testWidgets('no overlap adds directly, repeats in the batch kept', (
    tester,
  ) async {
    final host = await pumpPickerHost(
      tester,
      seed: {'Empty': const []},
      configure: (h) => h.readPaths = () async => ['/m/1', '/m/1', '/m/2'],
    );
    await openPicker(tester);
    await tick(tester, 'Empty');
    await tester.tap(addButton);
    await settle(tester);

    expect(question, findsNothing);
    expect(picker, findsNothing);
    expect(await host.pathsIn(tester, 'Empty'), ['/m/1', '/m/1', '/m/2']);
  });

  testWidgets('lists only the affected playlist; Confirm waits for a choice', (
    tester,
  ) async {
    await pumpPickerHost(tester, seed: seed);
    await openPicker(tester);
    await tick(tester, 'Half');
    await tick(tester, 'Empty');
    await pressAdd(tester);

    expect(question, findsOneWidget);
    expect(
      find.text('1 of the 2 songs is already in “Half”.'),
      findsOneWidget,
    );
    final dialog = find.byType(AlertDialog).last;
    expect(
      find.descendant(of: dialog, matching: find.textContaining('Half')),
      findsOneWidget,
    );
    // Single affected playlist does not render the inner playlist list box.
    expect(
      find.descendant(
        of: dialog,
        matching: find.byIcon(AppIcons.playlistOutlined),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: dialog, matching: find.textContaining('Empty')),
      findsNothing,
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.tap(find.text('Add all'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
  });

  testWidgets('Cancel returns to the picker with its ticks; Add asks again', (
    tester,
  ) async {
    final host = await pumpPickerHost(tester, seed: seed);
    await openPicker(tester);
    await tick(tester, 'Half');
    await nameNew(tester, 'Fresh');
    await pressAdd(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
    await settle(tester);

    expect(question, findsNothing);
    expect(picker, findsOneWidget);
    expect(inPicker(find.text('2 selected')), findsOneWidget);
    expect(inPicker(find.text('Fresh')), findsOneWidget);
    expect(await host.pathsIn(tester, 'Half'), ['/m/2']);

    await pressAdd(tester);
    expect(question, findsOneWidget);
  });

  testWidgets('Esc closes only the question; Enter does not press Add', (
    tester,
  ) async {
    final host = await pumpPickerHost(tester, seed: seed);
    await openPicker(tester);
    await tick(tester, 'Half');
    await pressAdd(tester);

    expect(picker, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 500));
    expect(question, findsOneWidget);
    expect(await host.pathsIn(tester, 'Half'), ['/m/2']);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(question, findsNothing);
    expect(picker, findsOneWidget);
    expect(inPicker(find.text('1 selected')), findsOneWidget);
  });

  group('each option, applied to the affected playlist only', () {
    Future<PickerHost> run(
      WidgetTester tester,
      String option,
      List<String> names,
    ) async {
      final host = await pumpPickerHost(tester, seed: seed);
      await openPicker(tester);
      await addChoosing(tester, names, option);
      expect(picker, findsNothing);
      return host;
    }

    testWidgets('remove the old copies', (tester) async {
      final host = await run(tester, 'Add all and remove the old copies', [
        'Half',
        'Empty',
      ]);
      expect(await host.pathsIn(tester, 'Half'), ['/m/1', '/m/2']);
      expect(await host.pathsIn(tester, 'Empty'), ['/m/1', '/m/2']);
      expect(
        find.text('2 songs added to 2 playlists, 1 old copy removed'),
        findsOneWidget,
      );
    });

    testWidgets('only missing: the unaffected playlist still gets all', (
      tester,
    ) async {
      final host = await run(tester, 'Add only missing songs', [
        'Half',
        'Empty',
      ]);
      expect(await host.pathsIn(tester, 'Half'), ['/m/2', '/m/1']);
      expect(await host.pathsIn(tester, 'Empty'), ['/m/1', '/m/2']);
      expect(
        find.text('2 songs added to 2 playlists, 1 skipped'),
        findsOneWidget,
      );
    });

    testWidgets('add all duplicates', (tester) async {
      final host = await run(tester, 'Add all', ['Half']);
      expect(await host.pathsIn(tester, 'Half'), ['/m/2', '/m/1', '/m/2']);
      expect(find.text('Added to Half: Road album'), findsOneWidget);
    });

    testWidgets('a single target says how many old copies went', (
      tester,
    ) async {
      await run(tester, 'Add all and remove the old copies', ['Half']);
      expect(
        find.text('Added to Half: Road album, 1 old copy removed'),
        findsOneWidget,
      );
    });
  });

  testWidgets('a batch with repeats: dialog and snackbar counts agree', (
    tester,
  ) async {
    final host = await pumpPickerHost(
      tester,
      seed: {
        'X': const ['/a'],
        'Y': const [],
      },
      configure: (h) => h.readPaths = () async => ['/a', '/a', '/b'],
    );
    await openPicker(tester);
    await tick(tester, 'X');
    await tick(tester, 'Y');
    await pressAdd(tester);
    expect(find.text('1 of the 2 songs is already in “X”.'), findsOneWidget);
    expect(find.text('Skips the 1 already there'), findsOneWidget);

    await tester.tap(find.text('Add only missing songs'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(confirm);
    await settle(tester);

    expect(await host.pathsIn(tester, 'X'), ['/a', '/b']);
    expect(await host.pathsIn(tester, 'Y'), ['/a', '/a', '/b']);
    expect(find.textContaining('1 skipped'), findsOneWidget);
  });

  testWidgets('single affected playlist: all songs already in (multiple songs)', (
    tester,
  ) async {
    await pumpPickerHost(
      tester,
      seed: {'Full': const ['/m/1', '/m/2']},
      configure: (h) => h.readPaths = () async => ['/m/1', '/m/2'],
    );
    await openPicker(tester);
    await tick(tester, 'Full');
    await pressAdd(tester);

    expect(question, findsOneWidget);
    expect(find.text('All 2 songs are already in “Full”.'), findsOneWidget);
    expect(find.byIcon(AppIcons.playlistOutlined), findsNothing);
  });

  testWidgets('single affected playlist: single song already in', (
    tester,
  ) async {
    await pumpPickerHost(
      tester,
      seed: {'Solo': const ['/m/1']},
      configure: (h) => h.readPaths = () async => ['/m/1'],
    );
    await openPicker(tester);
    await tick(tester, 'Solo');
    await pressAdd(tester);

    expect(question, findsOneWidget);
    expect(find.text('This song is already in “Solo”.'), findsOneWidget);
    expect(find.byIcon(AppIcons.playlistOutlined), findsNothing);
  });

  testWidgets(
    'multiple affected playlists: shows list with icons, dividers, and counts',
    (tester) async {
      await pumpPickerHost(
        tester,
        seed: {
          'Full': const ['/m/1', '/m/2'],
          'Half': const ['/m/2'],
          'Empty': const [],
        },
        configure: (h) => h.readPaths = () async => ['/m/1', '/m/2'],
      );
      await openPicker(tester);
      await tick(tester, 'Full');
      await tick(tester, 'Half');
      await tick(tester, 'Empty');
      await pressAdd(tester);

      expect(question, findsOneWidget);
      expect(
        find.text(
          'Some of the 2 songs are already in 2 of the playlists. '
          'Your choice applies to all of them.',
        ),
        findsOneWidget,
      );

      final dialog = find.byType(AlertDialog).last;
      expect(
        find.descendant(
          of: dialog,
          matching: find.byIcon(AppIcons.playlistOutlined),
        ),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Full')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Half')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Empty')),
        findsNothing,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('All 2 already in')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('1 of 2 already in')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.byType(Divider)),
        findsOneWidget,
      );
    },
  );
}
