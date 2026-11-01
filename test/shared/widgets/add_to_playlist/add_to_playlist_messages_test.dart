import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_add_writes.dart';
import 'package:kanaru/core/database/playlist_rows.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/l10n/app_localizations_en.dart';
import 'package:kanaru/shared/widgets/add_to_playlist/add_to_playlist_dialog.dart';
import 'package:kanaru/shared/widgets/add_to_playlist/add_to_playlist_messages.dart';
import 'package:kanaru/shared/widgets/app_snack_bar.dart';

PlaylistSummary _pl(int id, String name) =>
    PlaylistSummary(id: id, name: name, createdAt: id, entryCount: 0);

PlaylistAddPlan _plan(
  List<PlaylistSummary> targets, [
  List<String> names = const [],
]) => PlaylistAddPlan(
  paths: const ['/a', '/b'],
  targets: {for (final t in targets) t: PlaylistAddMode.appendAll},
  newNames: names,
);

void main() {
  final AppLocalizations l10n = AppLocalizationsEn();
  final mix = _pl(1, 'Mix'), gym = _pl(2, 'Gym'), run = _pl(3, 'Run');

  test('several targets: totals, new suffix and skipped suffix', () {
    final (kind, text) = playlistAddMessage(
      l10n,
      const PlaylistAddOutcome(
        added: 4,
        skipped: 1,
        created: ['Fresh'],
        targetCount: 3,
      ),
      _plan([mix, gym], ['Fresh']),
      'Album',
    );
    expect(kind, AppSnackBarKind.success);
    expect(text, '2 songs added to 3 playlists (1 new), 1 skipped');
  });

  test('nothing added to several: info, plural names', () {
    final (kind, text) = playlistAddMessage(
      l10n,
      const PlaylistAddOutcome(skipped: 2, targetCount: 2),
      _plan([mix, gym]),
      'Album',
    );
    expect(kind, AppSnackBarKind.info);
    expect(text, 'Already in 2 playlists: Mix, Gym');
  });

  test('a gone target is not named; one left uses the single wording', () {
    final (kind, text) = playlistAddMessage(
      l10n,
      const PlaylistAddOutcome(added: 2, gone: 1, targetCount: 1),
      _plan([mix, gym]),
      'Album',
      existingIds: {2},
    );
    expect(kind, AppSnackBarKind.success);
    expect(text, 'Added to Gym: Album');
  });

  test('gone targets with nothing added name only the live ones', () {
    final (kind, text) = playlistAddMessage(
      l10n,
      const PlaylistAddOutcome(skipped: 2, gone: 1, targetCount: 2),
      _plan([mix, gym, run]),
      'Album',
      existingIds: {2, 3},
    );
    expect(kind, AppSnackBarKind.info);
    expect(text, 'Already in 2 playlists: Gym, Run');
  });

  test('every target gone is an error', () {
    final (kind, _) = playlistAddMessage(
      l10n,
      const PlaylistAddOutcome(gone: 1),
      _plan([mix]),
      'Album',
      existingIds: const {},
    );
    expect(kind, AppSnackBarKind.error);
  });

  test('a single new playlist uses its typed name', () {
    final (_, text) = playlistAddMessage(
      l10n,
      const PlaylistAddOutcome(added: 2, created: ['Fresh'], targetCount: 1),
      _plan(const [], ['Fresh']),
      'Album',
    );
    expect(text, 'Added to Fresh: Album');
  });
}
