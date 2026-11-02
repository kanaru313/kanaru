import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_add_writes.dart';
import 'package:kanaru/core/player/audio_output_device.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/audio_output_device_picker_setting_rows.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/widgets/add_to_playlist/already_in_playlist_dialog.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';
import 'add_to_playlist/picker_test_host.dart';

/// Scrolls [scrollable] so [tile] is cut by its top edge, hovers the visible
/// part of the tile, and checks that the [Material] painting the tile's ink
/// does not reach above the scroll view.
///
/// Ink is clipped to the nearest Material's box. When that Material is the
/// dialog, the hover of a row half under the title paints over the title.
Future<void> expectInkClipped(
  WidgetTester tester,
  Finder scrollable,
  Finder tile,
) async {
  final position = tester.state<ScrollableState>(scrollable).position;
  final viewport = tester.getRect(scrollable);
  final shift = tester.getRect(tile).top - viewport.top + 20;
  expect(
    position.maxScrollExtent,
    greaterThanOrEqualTo(position.pixels + shift),
    reason: 'the content scrolls far enough to cut the tile',
  );
  position.jumpTo(position.pixels + shift);
  await tester.pumpAndSettle();
  final cut = tester.getRect(tile);
  expect(cut.top, lessThan(viewport.top), reason: 'the tile is cut off');
  expect(cut.bottom, greaterThan(viewport.top), reason: 'part of it shows');

  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(Offset(cut.center.dx, viewport.top + 4));
  await tester.pumpAndSettle();

  final ink = Material.of(tester.element(tile)) as RenderBox;
  final inkArea = ink.localToGlobal(Offset.zero) & ink.size;
  expect(
    inkArea.top,
    greaterThanOrEqualTo(viewport.top),
    reason: 'ink must not reach above the scroll view',
  );
}

/// A host with an "Open" button that runs [open] with the button's context.
Future<void> pumpOpener(
  WidgetTester tester, {
  required Size size,
  required void Function(BuildContext context) open,
  ProviderContainer? container,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final app = MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => open(context),
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.pumpWidget(
    container == null
        ? app
        : UncontrolledProviderScope(container: container, child: app),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Finder _dialogScrollable() => find
    .descendant(of: find.byType(AlertDialog), matching: find.byType(Scrollable))
    .first;

void main() {
  testWidgets('playlist picker hover stays inside the list', (tester) async {
    await pumpPickerHost(
      tester,
      seed: {for (var i = 0; i < 20; i++) 'Playlist $i': const <String>[]},
    );
    await openPicker(tester);

    final list = find
        .descendant(of: picker, matching: find.byType(Scrollable))
        .first;
    // The "New playlist…" row heads the list.
    final first = find
        .descendant(of: list, matching: find.byType(ListTile))
        .first;
    await expectInkClipped(tester, list, first);
  });

  testWidgets('already-in-playlist hover stays inside the content', (
    tester,
  ) async {
    await pumpOpener(
      tester,
      size: const Size(500, 360),
      open: (context) => showAlreadyInPlaylistDialog(
        context,
        affected: [(name: 'Mix', held: 1), (name: 'Gym', held: 2)],
        songCount: 2,
      ),
    );

    final option = find.byType(RadioListTile<PlaylistAddMode>).first;
    await expectInkClipped(tester, _dialogScrollable(), option);
  });

  testWidgets('audio output hover stays inside the list', (tester) async {
    final backend = FakeAudioBackend()
      ..devices = [
        for (var i = 0; i < 12; i++)
          AudioOutputDevice(name: 'pipewire/out$i', description: 'Out $i'),
      ];
    final container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        initialSettingsProvider.overrideWithValue(const AppSettings()),
      ],
    );
    addTearDown(container.dispose);
    await pumpOpener(
      tester,
      size: const Size(700, 500),
      container: container,
      open: showAudioOutputDeviceDialog,
    );

    final automatic = find.byType(RadioListTile<String>).first;
    await expectInkClipped(tester, _dialogScrollable(), automatic);
  });
}
