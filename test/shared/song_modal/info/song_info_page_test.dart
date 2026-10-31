import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_rows.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/core/track_details/release_date.dart';
import 'package:kanaru/core/track_details/track_details.dart';
import 'package:kanaru/core/track_details/track_details_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/song_modal/info/wrap_anywhere.dart';
import 'package:kanaru/shared/song_modal/open_song_modal.dart';
import 'package:material_ui/material_ui.dart';

import '../song_modal_test_support.dart' hide openSongModal;

const _song = TrackListItem(id: 1, path: '/m/1.flac', title: 'one');
final _longPath = '/home/someone/Music/${'Very Long Folder Name' * 4}/one.flac';

TrackDetails _details({int plays = 0, String? path, String? release}) =>
    TrackDetails(
      id: 1,
      title: 'One',
      localPath: path ?? _longPath,
      artist: 'Somebody',
      releaseDateRaw: release,
      releaseDate: release == null
          ? null
          : const ReleaseDate(year: 2012, month: 1, day: 1),
      sizeBytes: 1000,
      modifiedAtMs: 0,
      addedAtMs: 0,
      playCount: plays,
      firstPlayedAt: plays > 0 ? 1700000000000 : null,
      lastPlayedAt: plays > 0 ? 1700000000000 : null,
    );

Future<ProviderContainer> _openInfo(
  WidgetTester tester,
  Stream<TrackDetails?> Function() details,
) async {
  tester.view.physicalSize = const Size(360, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [trackDetailsProvider.overrideWith((ref, id) => details())],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => openSongModal(
                context,
                ref,
                song: _song,
                onQueueAction: (_) {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await settleSongModal(tester);
  await openSongInfoPage(tester);
  return container;
}

void main() {
  testWidgets('shows the fields, wraps a long path and hides unknowns', (
    tester,
  ) async {
    await _openInfo(tester, () => Stream.value(_details(plays: 3)));

    expect(find.text('Song info'), findsWidgets);
    expect(
      find.textContaining('Artist: Somebody', findRichText: true),
      findsOne,
    );
    expect(find.textContaining('Album:', findRichText: true), findsNothing);
    expect(find.textContaining('Total plays: 3'), findsOne);
    expect(find.textContaining('Path:', findRichText: true), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the eye shows unknown fields and the choice is kept', (
    tester,
  ) async {
    final container = await _openInfo(tester, () => Stream.value(_details()));
    expect(
      container.read(settingsProvider).display.songInfoShowUnknown,
      isFalse,
    );

    await tester.tap(find.byTooltip('Show unknown fields'));
    await tester.pump();

    expect(
      container.read(settingsProvider).display.songInfoShowUnknown,
      isTrue,
    );
    expect(find.textContaining('Album: Unknown', findRichText: true), findsOne);
    expect(find.byTooltip('Hide unknown fields'), findsOne);
    expect(find.textContaining('Never played'), findsOne);
  });

  testWidgets('tapping a value copies the original text', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _openInfo(tester, () => Stream.value(_details()));

    await tester.tap(find.byKey(const ValueKey('song-info-path')));
    await tester.pump();

    expect(copied, _longPath);
    expect(copied, isNot(contains(zeroWidthSpace)));
    expect(find.textContaining('Copied:', findRichText: true), findsOne);
  });

  testWidgets('a row that is gone says so and offers the way back', (
    tester,
  ) async {
    await _openInfo(tester, () => Stream.value(null));

    expect(find.text('This song is no longer in the library'), findsOne);
    await tester.tap(find.text('Back'));
    await settleSongModal(tester);
    expect(find.text('Go to artist'), findsOne);
  });

  testWidgets('shows a skeleton while the details load', (tester) async {
    await _openInfo(tester, () => const Stream.empty());
    expect(find.byKey(const ValueKey('song-info-skeleton')), findsOne);
  });

  testWidgets('a thin divider separates the rows of a group', (tester) async {
    await _openInfo(tester, () => Stream.value(_details()));

    final title = tester.getRect(find.byKey(const ValueKey('song-info-title')));
    final artist = tester.getRect(
      find.byKey(const ValueKey('song-info-artist')),
    );
    final dividers = find
        .byType(Divider)
        .evaluate()
        .map((e) => tester.getRect(find.byElementPredicate((x) => x == e)));
    expect(
      dividers.where(
        (d) => d.top >= title.bottom - 1 && d.bottom <= artist.top + 1,
      ),
      isNotEmpty,
    );
  });

  testWidgets('the release chips sit inside the release date row', (
    tester,
  ) async {
    await _openInfo(
      tester,
      () => Stream.value(_details(release: '2012-01-01')),
    );

    final row = find.byKey(const ValueKey('song-info-release-date'));
    expect(row, findsOne);
    expect(
      find.descendant(
        of: row,
        matching: find.textContaining(
          'Release date: 2012-01-01',
          findRichText: true,
        ),
      ),
      findsOne,
    );
    expect(
      find.descendant(of: row, matching: find.text('Jan 1, 2012')),
      findsOne,
    );
    // On the same line as the date, not under it.
    final date = tester.getRect(
      find.descendant(
        of: row,
        matching: find.textContaining('Release date', findRichText: true),
      ),
    );
    final chip = tester.getRect(
      find.descendant(of: row, matching: find.text('Jan 1, 2012')),
    );
    expect((chip.center.dy - date.center.dy).abs(), lessThan(date.height));
  });

  testWidgets('a tap on the empty end of a row copies its value', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _openInfo(tester, () => Stream.value(_details()));

    final row = tester.getRect(find.byKey(const ValueKey('song-info-artist')));
    await tester.tapAt(Offset(row.right - 4, row.center.dy));
    await tester.pump();

    expect(copied, 'Somebody');
  });

  testWidgets('label and value differ in weight and color', (tester) async {
    await _openInfo(tester, () => Stream.value(_details()));

    final field = find.byKey(const ValueKey('song-info-artist'));
    final rich = tester.widget<RichText>(
      find.descendant(of: field, matching: find.byType(RichText)).first,
    );
    final colors = Theme.of(tester.element(field)).colorScheme;
    final spans = ((rich.text as TextSpan).children!.single as TextSpan)
        .children!
        .cast<TextSpan>();
    expect(spans[0].text, 'Artist: ');
    expect(spans[0].style?.fontWeight, isNull);
    expect(spans[0].style?.color, colors.onSurfaceVariant);
    expect(spans[1].text, 'Somebody');
    expect(spans[1].style?.fontWeight, FontWeight.w500);
    expect(spans[1].style?.color, colors.onSurface);
  });

  testWidgets('an unknown value is italic in onSurfaceVariant', (tester) async {
    final container = await _openInfo(tester, () => Stream.value(_details()));
    await tester.tap(find.byTooltip('Show unknown fields'));
    await tester.pump();
    expect(
      container.read(settingsProvider).display.songInfoShowUnknown,
      isTrue,
    );

    final field = find.byKey(const ValueKey('song-info-album'));
    final rich = tester.widget<RichText>(
      find.descendant(of: field, matching: find.byType(RichText)).first,
    );
    final colors = Theme.of(tester.element(field)).colorScheme;
    final value = ((rich.text as TextSpan).children!.single as TextSpan)
        .children!
        .cast<TextSpan>()[1];
    expect(value.text, 'Unknown');
    expect(value.style?.fontStyle, FontStyle.italic);
    expect(value.style?.color, colors.onSurfaceVariant);
  });
}
