import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/m3u/m3u_import.dart';
import 'package:kanaru/features/playlists/m3u_import_report_dialog.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('a long report lists 100 lines and counts the rest', (
    tester,
  ) async {
    final result = M3uImportResult(
      paths: const ['/m/a.flac'],
      duplicates: 0,
      unresolved: [
        for (var i = 0; i < 10000; i++) (line: i + 2, text: 'x$i.mp3'),
      ],
      total: 10001,
      truncated: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showM3uImportReport(
              context,
              result: result,
              added: 1,
              notInLibrary: 0,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Added 1 of 10001 lines.'), findsOneWidget);
    expect(find.text('Only the first 50000 songs were read.'), findsOneWidget);
    expect(find.textContaining('Line '), findsAtLeastNWidgets(1));
    await tester.scrollUntilVisible(find.text('and 9900 more lines'), 500);
    expect(find.text('and 9900 more lines'), findsOneWidget);
    expect(find.text('Line 102: x100.mp3'), findsNothing);
  });
}
