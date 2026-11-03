import 'package:flutter/widgets.dart' show VoidCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/history/most_played_modal/most_played_modal_actions.dart';
import 'package:kanaru/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  var taps = <String>[];
  VoidCallback tap(String id) =>
      () => taps.add(id);

  MostPlayedModalHandlers handlers() => MostPlayedModalHandlers(
    play: tap('play'),
    shuffle: tap('shuffle'),
    addToPlaylist: tap('playlist'),
    addToFavorites: tap('favorites'),
    exportAbsolute: tap('absolute'),
    exportRelative: tap('relative'),
  );

  setUp(() => taps = []);

  test(
    'three groups: play and shuffle, playlist and favorites, then both exports',
    () {
      final sections = mostPlayedModalSections(
        l10n,
        'Last 30 days',
        3,
        handlers(),
      );

      expect(
        [
          for (final s in sections) [for (final a in s) a.id],
        ],
        [
          ['play-all', 'shuffle'],
          ['add-to-playlist', 'add-all-to-favorites'],
          ['export-absolute', 'export-relative'],
        ],
      );
    },
  );

  test('subtitles name the suggested playlist and count the songs', () {
    final rows = {
      for (final a in mostPlayedModalSections(
        l10n,
        'Last 30 days',
        3,
        handlers(),
      ).expand((s) => s))
        a.id: a.subtitle,
    };

    expect(
      rows['add-to-playlist'],
      'New playlist suggests “Most played · Last 30 days”',
    );
    expect(rows['add-all-to-favorites'], '3 songs');
    expect(rows['export-absolute'], endsWith('3 songs, in rank order'));
    expect(rows['export-relative'], endsWith('3 songs, in rank order'));
  });

  test('a single song is singular', () {
    final rows = mostPlayedModalSections(
      l10n,
      'x',
      1,
      handlers(),
    ).expand((s) => s);

    expect(
      rows.firstWhere((a) => a.id == 'export-absolute').subtitle,
      endsWith('1 song, in rank order'),
    );
  });

  test('every row is off without a playable song', () {
    final rows = mostPlayedModalSections(
      l10n,
      'x',
      0,
      handlers(),
    ).expand((s) => s);

    expect(rows, hasLength(6));
    expect(rows.every((a) => !a.enabled), isTrue);
  });
}
