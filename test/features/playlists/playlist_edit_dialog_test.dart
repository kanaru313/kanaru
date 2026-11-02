import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_rows.dart';
import 'package:kanaru/features/playlists/playlist_edit_cover.dart';
import 'package:kanaru/features/playlists/playlist_edit_dialog.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/playlist_cover.dart';
import 'package:material_ui/material_ui.dart';

const _playlist = PlaylistSummary(
  id: 7,
  name: 'Chill',
  createdAt: 0,
  entryCount: 3,
  description: 'Evening mix',
);

final _name = find.byKey(const ValueKey('playlist-edit-name'));
final _description = find.byKey(const ValueKey('playlist-edit-description'));
final _save = find.widgetWithText(FilledButton, 'Save');

void main() {
  PlaylistDetailsEdit? result;
  var closed = false;

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(900, 900),
  }) async {
    result = null;
    closed = false;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showPlaylistEditDialog(
                  context,
                  playlist: _playlist,
                  coverKeys: const [],
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('starts with the current values, name selected', (tester) async {
    await open(tester);
    expect(find.text('Edit playlist'), findsOneWidget);
    final name = tester.widget<TextField>(_name).controller!;
    expect(name.text, 'Chill');
    expect(name.selection, const TextSelection(baseOffset: 0, extentOffset: 5));
    expect(find.text('Evening mix'), findsOneWidget);
  });

  testWidgets('empty name shows the error and disables Save', (tester) async {
    await open(tester);
    await tester.enterText(_name, '   ');
    await tester.pump();
    expect(find.text("Name can't be empty"), findsOneWidget);
    expect(tester.widget<FilledButton>(_save).onPressed, isNull);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(closed, isFalse);
  });

  testWidgets('Enter in Name saves trimmed values', (tester) async {
    await open(tester);
    await tester.enterText(_name, '  Gym  ');
    await tester.enterText(_description, '  fast  ');
    await tester.tap(_name);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result, (name: 'Gym', description: 'fast'));
  });

  testWidgets('Enter in Description adds a line and does not save', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(_description, 'a\nb');
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await tester.pump();
    expect(closed, isFalse);
    expect(find.text('Edit playlist'), findsOneWidget);
    final field = tester.widget<TextField>(_description);
    expect(field.controller!.text, contains('\n'));
    expect(field.keyboardType, TextInputType.multiline);
    expect(field.minLines, field.maxLines);
  });

  testWidgets('the 2001st character is refused and the counter shows it', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(_description, 'x' * 2000);
    await tester.pump();
    await tester.enterText(_description, '${'x' * 2000}y');
    await tester.pump();
    expect(
      tester.widget<TextField>(_description).controller!.text.length,
      2000,
    );
    expect(find.text('2000 / 2000'), findsOneWidget);
  });

  testWidgets('limit counts graphemes, not code units', (tester) async {
    await open(tester);
    final emoji = '\u{1F44D}' * 2000;
    await tester.enterText(_description, emoji);
    await tester.pump();
    await tester.enterText(_description, '${emoji}y');
    await tester.pump();
    expect(tester.widget<TextField>(_description).controller!.text, emoji);
    expect(find.text('2000 / 2000'), findsOneWidget);
    await tester.enterText(_description, '');
    final combining = 'e\u0301' * 2000;
    await tester.enterText(_description, combining);
    await tester.enterText(_description, '${combining}e');
    await tester.pump();
    expect(tester.widget<TextField>(_description).controller!.text, combining);
  });

  testWidgets('wide: cover beside the fields', (tester) async {
    await open(tester);
    final cover = tester.getRect(find.byType(PlaylistCover));
    expect(cover.right, lessThanOrEqualTo(tester.getTopLeft(_name).dx));
  });

  testWidgets('narrow: one column, cover above the fields', (tester) async {
    await open(tester, size: const Size(360, 900));
    final cover = tester.getRect(find.byType(PlaylistCover));
    expect(cover.bottom, lessThanOrEqualTo(tester.getTopLeft(_name).dy));
  });

  // Content width is the dialog (surface minus 80) minus 48; 520 is the cut.
  testWidgets('stacks just below 520 px of content', (tester) async {
    await open(tester, size: const Size(647, 900));
    final cover = tester.getRect(find.byType(PlaylistCover));
    expect(cover.bottom, lessThanOrEqualTo(tester.getTopLeft(_name).dy));
  });

  testWidgets('two columns from 520 px of content', (tester) async {
    await open(tester, size: const Size(648, 900));
    final cover = tester.getRect(find.byType(PlaylistCover));
    expect(cover.right, lessThanOrEqualTo(tester.getTopLeft(_name).dx));
  });

  testWidgets('crossing the breakpoint keeps focus and text', (tester) async {
    await open(tester);
    await tester.tap(_description);
    await tester.enterText(_description, 'kept');
    await tester.pump();
    tester.view.physicalSize = const Size(400, 900);
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(_description);
    expect(field.controller!.text, 'kept');
    expect(field.focusNode?.hasFocus ?? true, isTrue);
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<TextField>()
          ?.key,
      const ValueKey('playlist-edit-description'),
    );
  });

  testWidgets('the cover is inert: no focus, no tap action', (tester) async {
    await open(tester);
    final cover = find.byType(PlaylistEditCover);
    expect(
      find.descendant(of: cover, matching: find.byType(ExcludeFocus)),
      findsWidgets,
    );
    expect(
      find.descendant(of: cover, matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(
      find.descendant(of: cover, matching: find.byType(GestureDetector)),
      findsNothing,
    );
    expect(
      find.descendant(of: cover, matching: find.byType(ExcludeSemantics)),
      findsWidgets,
    );
  });

  for (final (label, dismiss)
      in <(String, Future<void> Function(WidgetTester))>[
        ('Close button', (t) => t.tap(find.byTooltip('Close'))),
        ('Cancel', (t) => t.tap(find.text('Cancel'))),
        ('Esc', (t) => t.sendKeyEvent(LogicalKeyboardKey.escape)),
        ('tap outside', (t) => t.tapAt(const Offset(2, 2))),
      ]) {
    testWidgets('$label closes with null', (tester) async {
      await open(tester);
      await dismiss(tester);
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result, isNull);
    });
  }
}
