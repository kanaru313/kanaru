import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/indexer_state.dart';

import '../../core/indexer/scripted_indexer.dart';
import 'library_test_harness.dart';

void main() {
  Future<ScriptedIndexer> pumpApp(WidgetTester tester) async {
    final indexer = ScriptedIndexer();
    final h = LibraryHarness(
      overrides: [libraryIndexerProvider.overrideWith(() => indexer)],
    );
    await h.pump(tester, hasRoots: true);
    return indexer;
  }

  testWidgets('a quiet scan that changed nothing shows no snack bar', (
    tester,
  ) async {
    final indexer = await pumpApp(tester);

    indexer.emit(
      IndexerFinished(
        const ScanSummary(
          skippedRoots: {'/gone': SkipReason.missing},
          failedTags: 2,
        ),
        quiet: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Scan complete'), findsNothing);
    expect(find.text('No changes'), findsNothing);
  });

  testWidgets('a quiet scan that added songs is announced', (tester) async {
    final indexer = await pumpApp(tester);

    indexer.emit(IndexerFinished(const ScanSummary(added: 3), quiet: true));
    await tester.pumpAndSettle();

    expect(find.textContaining('3 new'), findsOneWidget);
  });

  testWidgets('a scan the user asked for always reports', (tester) async {
    final indexer = await pumpApp(tester);

    indexer.emit(IndexerFinished(const ScanSummary()));
    await tester.pumpAndSettle();

    expect(find.text('No changes'), findsOneWidget);
  });

  testWidgets('a failed quiet scan is announced', (tester) async {
    final indexer = await pumpApp(tester);

    indexer.emit(IndexerFailed('boom'));
    await tester.pumpAndSettle();

    expect(find.text('Scan failed'), findsOneWidget);
  });
}
