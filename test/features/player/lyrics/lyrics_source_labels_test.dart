import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics/online/lyrics_choice.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/features/player/lyrics/source/lyrics_source_labels.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/l10n/app_localizations_en.dart';
import 'package:kanaru/l10n/app_localizations_vi.dart';

import '../../../core/lyrics/online/fake_lyrics_provider.dart';
import 'fake_playing_lyrics_resolution.dart';

const _uri = '/m/song.flac';

class _Lrclib extends FakeLyricsProvider {
  _Lrclib() : super(id: 'lrclib');

  @override
  String get displayName => 'LRCLIB';
}

Lyrics _lyrics({bool synced = true, LyricsSource? source}) => Lyrics(
  lines: const [LyricLine(Duration.zero, 'words')],
  synced: synced,
  source: source ?? LyricsSource.sidecar,
);

OnlineLyricsOrigin _origin({required bool pinned}) =>
    OnlineLyricsOrigin(providerId: 'lrclib', remoteId: '1', pinned: pinned);

void main() {
  final providers = [LyricsProviderRegistration(_Lrclib())];

  String label(
    AppLocalizations l10n,
    PlayingLyricsStatus status, {
    LyricsChoice effective = LyricsChoice.auto,
  }) => lyricsSourceLabel(
    l10n,
    fakeResolution(status, effective: effective),
    providers,
  );

  for (final (l10n, name) in [
    (AppLocalizationsEn() as AppLocalizations, 'en'),
    (AppLocalizationsVi() as AppLocalizations, 'vi'),
  ]) {
    final vi = name == 'vi';
    String pick(String en, String viText) => vi ? viText : en;

    group('the label, $name', () {
      test('lyrics off, searching, paused', () {
        expect(
          label(
            l10n,
            const LyricsNone(_uri, LyricsNoneReason.off),
            effective: LyricsChoice.off,
          ),
          pick('Lyrics off', 'Đã tắt lời'),
        );
        expect(
          label(l10n, const LyricsSearching(_uri, 'lrclib')),
          pick('Searching…', 'Đang tìm…'),
        );
        expect(
          label(l10n, LyricsNone(_uri, LyricsNoneReason.paused)),
          pick('Lookups paused', 'Tạm dừng tìm'),
        );
      });

      test(
        'the song\'s own lyrics, with "Auto" only when nothing was chosen',
        () {
          final file = LyricsFound(_uri, _lyrics());
          expect(
            label(l10n, file),
            pick('Auto · .lrc file', 'Tự động · File .lrc'),
          );
          expect(
            label(l10n, file, effective: LyricsChoice.local),
            pick('.lrc file', 'File .lrc'),
          );
          final tag = LyricsFound(_uri, _lyrics(source: LyricsSource.embedded));
          expect(
            label(l10n, tag),
            pick('Auto · Tag lyrics', 'Tự động · Lời trong tag'),
          );
          expect(
            label(l10n, tag, effective: LyricsChoice.local),
            pick('Tag lyrics', 'Lời trong tag'),
          );
        },
      );

      test(
        'online lyrics: chosen names the kind, automatic only the service',
        () {
          expect(
            label(
              l10n,
              LyricsFound(_uri, _lyrics(), origin: _origin(pinned: true)),
              effective: LyricsChoice.online,
            ),
            pick('LRCLIB · Synced', 'LRCLIB · Đồng bộ'),
          );
          expect(
            label(
              l10n,
              LyricsFound(
                _uri,
                _lyrics(synced: false),
                origin: _origin(pinned: true),
              ),
              effective: LyricsChoice.online,
            ),
            pick('LRCLIB · Plain', 'LRCLIB · Lời thường'),
          );
          expect(
            label(
              l10n,
              LyricsFound(_uri, _lyrics(), origin: _origin(pinned: false)),
            ),
            pick('Auto · LRCLIB', 'Tự động · LRCLIB'),
          );
        },
      );

      test('reading the song reads "searching", not "no lyrics"', () {
        expect(
          label(l10n, const LyricsReading(_uri)),
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
          expect(label(l10n, LyricsNone(_uri, reason)), none);
        }
      });
    });
  }

  test('only found lyrics are not muted', () {
    bool muted(PlayingLyricsStatus status) =>
        lyricsSourceMuted(fakeResolution(status));
    expect(muted(LyricsFound(_uri, _lyrics())), isFalse);
    for (final status in <PlayingLyricsStatus>[
      const LyricsNone(_uri, LyricsNoneReason.off),
      const LyricsNone(_uri, LyricsNoneReason.noLyrics),
      const LyricsSearching(_uri, 'lrclib'),
      const LyricsReading(_uri),
    ]) {
      expect(muted(status), isTrue, reason: '$status');
    }
  });
}
