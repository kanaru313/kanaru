import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics/online/lyrics_source_names.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/features/player/lyrics/source/lyrics_source_labels.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/l10n/app_localizations_en.dart';
import 'package:kanaru/l10n/app_localizations_vi.dart';

import 'fake_playing_lyrics_resolution.dart';

const _uri = '/m/song.flac';

Lyrics _lyrics({bool synced = true, LyricsSource? source}) => Lyrics(
  lines: const [LyricLine(Duration.zero, 'words')],
  synced: synced,
  source: source ?? LyricsSource.sidecar,
);

OnlineLyricsOrigin _origin({required bool pinned}) =>
    OnlineLyricsOrigin(providerId: 'lrclib', remoteId: '1', pinned: pinned);

void main() {
  final providers = {'lrclib': const LyricsSourceName(displayName: 'LRCLIB')};

  String title(AppLocalizations l10n, PlayingLyricsStatus status) =>
      lyricsSourceTooltipTitle(l10n, fakeResolution(status), providers);

  for (final (l10n, name) in [
    (AppLocalizationsEn() as AppLocalizations, 'en'),
    (AppLocalizationsVi() as AppLocalizations, 'vi'),
  ]) {
    final vi = name == 'vi';
    String pick(String en, String viText) => vi ? viText : en;

    group('the tooltip title, $name', () {
      test('lyrics off, searching, paused', () {
        expect(
          title(l10n, const LyricsNone(_uri, LyricsNoneReason.off)),
          pick('Lyrics off', 'Đã tắt lời'),
        );
        expect(
          title(l10n, const LyricsSearching(_uri, 'lrclib')),
          pick('Searching…', 'Đang tìm…'),
        );
        expect(
          title(l10n, LyricsNone(_uri, LyricsNoneReason.paused)),
          pick('Lookups paused', 'Tạm dừng tìm'),
        );
      });

      test('the song\'s own lyrics are named plainly: the file or the tag', () {
        expect(
          title(l10n, LyricsFound(_uri, _lyrics())),
          pick('.lrc file', 'File .lrc'),
        );
        expect(
          title(
            l10n,
            LyricsFound(_uri, _lyrics(source: LyricsSource.embedded)),
          ),
          pick('Tag lyrics', 'Lời trong tag'),
        );
      });

      test('online lyrics name the service and the kind', () {
        expect(
          title(
            l10n,
            LyricsFound(_uri, _lyrics(), origin: _origin(pinned: true)),
          ),
          pick('Lyrics from LRCLIB · Synced', 'Lời từ LRCLIB · Đồng bộ'),
        );
        expect(
          title(
            l10n,
            LyricsFound(
              _uri,
              _lyrics(synced: false),
              origin: _origin(pinned: false),
            ),
          ),
          pick('Lyrics from LRCLIB · Plain', 'Lời từ LRCLIB · Lời thường'),
        );
      });

      test('reading the song reads "searching", not "no lyrics"', () {
        expect(
          title(l10n, const LyricsReading(_uri)),
          pick('Searching…', 'Đang tìm…'),
        );
      });

      test('everything else reads "no lyrics"', () {
        final none = pick('No lyrics', 'Không có lời');
        for (final reason in [
          LyricsNoneReason.noLyrics,
          LyricsNoneReason.notFound,
          LyricsNoneReason.error,
          LyricsNoneReason.instrumental,
        ]) {
          expect(title(l10n, LyricsNone(_uri, reason)), none);
        }
      });
    });
  }
}
