import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/shared/library_browse_refresh.dart';
import 'package:material_ui/material_ui.dart' show Size;

import '../core/player/fake_audio_backend.dart';

/// Mounts the whole app so the real router and its redirects are attached.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  LibraryDatabase? db,
  bool hasRoots = true,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      audioBackendProvider.overrideWithValue(FakeAudioBackend()),
      libraryDatabaseProvider.overrideWithValue(db),
      libraryHasRootsProvider.overrideWith(() => LibraryHasRoots(hasRoots)),
      // Reload browse lists at once so no refresh timer outlives the test.
      libraryBrowseRefreshIntervalProvider.overrideWithValue(Duration.zero),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KanaruApp()),
  );
  await tester.pumpAndSettle();
  return container;
}
