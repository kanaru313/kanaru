import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/add_to_playlist/playlist_name_dialog.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  String? result;
  var closed = false;

  Future<void> open(WidgetTester tester, {String? initialName}) async {
    result = null;
    closed = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showPlaylistNameDialog(
                context,
                title: 'Title',
                confirmLabel: 'Create',
                initialName: initialName,
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  FilledButton confirm(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  TextEditingController controller(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!;

  testWidgets('starts with the initial name fully selected', (tester) async {
    await open(tester, initialName: 'New playlist');

    final value = controller(tester);
    expect(value.text, 'New playlist');
    expect(
      value.selection,
      const TextSelection(baseOffset: 0, extentOffset: 12),
    );
    expect(find.text('Title'), findsOneWidget);
    expect(confirm(tester).onPressed, isNotNull);
  });

  testWidgets('blank text disables confirm and Enter keeps the dialog open', (
    tester,
  ) async {
    await open(tester);
    expect(confirm(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(confirm(tester).onPressed, isNull);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(closed, isFalse);
  });

  testWidgets('Enter returns the trimmed name', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), '  Road trip ');
    await tester.pump();

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result, 'Road trip');
  });

  testWidgets('the confirm button returns the trimmed name', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), ' Mix ');
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(result, 'Mix');
  });

  testWidgets('Esc and Cancel return null', (tester) async {
    await open(tester, initialName: 'x');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);

    await open(tester, initialName: 'x');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('a tap outside the dialog returns null', (tester) async {
    await open(tester, initialName: 'x');

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('keeps at most 200 characters', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'a' * 201);
    await tester.pump();

    expect(controller(tester).text, 'a' * playlistNameMaxLength);
  });
}
