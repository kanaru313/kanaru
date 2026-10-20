import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kanaru/core/database/library_keys_provider.dart';

import 'library_test_harness.dart';

void main() {
  for (final route in ['/songs', '/albums', '/artists']) {
    testWidgets('$route shows the updating state until the keys are ready', (
      tester,
    ) async {
      final finish = Completer<void>();
      final h = LibraryHarness(
        overrides: [
          libraryKeysRunnerProvider.overrideWithValue((db, onProgress) async {
            onProgress(2000, 10000);
            await finish.future;
          }),
        ],
      );
      await tester.runAsync(() => h.db.addRoots([h.folder('music')], now: 1));
      await h.pump(tester, hasRoots: true);
      h.container.read(routerProvider).go(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Updating library…'), findsOneWidget);
      expect(find.text('2,000 / 10,000'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      finish.complete();
      await tester.pumpAndSettle();
      expect(find.text('Updating library…'), findsNothing);
      expect(h.container.read(keysReadyProvider), isTrue);
    });
  }
}
