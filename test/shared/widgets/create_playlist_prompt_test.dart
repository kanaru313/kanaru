import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/add_to_playlist/create_playlist_prompt.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> open(WidgetTester tester, {String? initialName}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => promptAndCreatePlaylist(
              context,
              db,
              ScaffoldMessenger.of(context),
              AppLocalizations.of(context),
              initialName: initialName,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('starts with the given name', (tester) async {
    await open(tester, initialName: 'Rock');

    expect(fieldText(tester), 'Rock');
  });

  testWidgets('starts with the default name without one', (tester) async {
    await open(tester);

    expect(fieldText(tester), 'New playlist');
  });
}
