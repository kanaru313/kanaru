import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics/online/lrc_sidecar_writer.dart';
import 'package:kanaru/core/lyrics/online/lyrics_choice.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_actions.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/player/track.dart';

const modalUri = '/m/song.flac';
const modalTrack = Track(
  uri: modalUri,
  title: 'Song',
  artist: 'Artist',
  duration: Duration(seconds: 200),
);
const otherTrack = Track(
  uri: '/m/other.flac',
  title: 'Other',
  artist: 'Artist',
  duration: Duration(seconds: 200),
);

Lyrics modalLyrics({
  bool synced = true,
  LyricsSource source = LyricsSource.sidecar,
}) => Lyrics(
  lines: const [LyricLine(Duration.zero, 'words')],
  synced: synced,
  source: source,
);

OnlineLyricsOrigin modalOrigin({bool pinned = true, String id = 'plugin-a'}) =>
    OnlineLyricsOrigin(providerId: id, remoteId: '1', pinned: pinned);

LyricsPluginRecord modalRecord(String id, String name) => LyricsPluginRecord(
  kind: PluginKind.lyrics,
  installId: id,
  name: name,
  version: 1,
  apiVersion: 1,
  hosts: const ['api.example.com'],
  config: const [],
  packageDir: '$id/v1-1',
  sourceKind: LyricsPluginSourceKind.file,
  sourceName: 'x.zip',
  installedAt: 1,
  updatedAt: 1,
);

/// Records what the modal asks the actions to do.
class RecordingActions extends OnlineLyricsActions {
  RecordingActions(
    super.ref,
    this.log, {
    this.failChoose = false,
    this.saveResult = LrcWriteResult.written,
  });

  /// What `save` answers.
  final LrcWriteResult saveResult;

  final List<String> log;

  /// Makes `choose` throw, to see where its error snackbar shows.
  final bool failChoose;

  @override
  Future<void> turnOn(LyricsTarget target) async => log.add('turnOn');

  @override
  Future<void> choose(LyricsTarget target, LyricsChoice choice) async {
    if (failChoose) throw StateError('x');
    log.add('choose ${choice.name}');
  }

  @override
  Future<void> keep(LyricsTarget target, OnlineLyricsOrigin origin) async =>
      log.add('keep ${origin.remoteId}');

  @override
  Future<void> reject(
    LyricsTarget target,
    OnlineLyricsOrigin origin,
    Lyrics shown,
  ) async => log.add('reject ${origin.remoteId}');

  @override
  Future<void> retry(LyricsTarget target) async => log.add('retry');

  @override
  Future<LyricsSaveOutcome> save(
    LyricsTarget target,
    OnlineLyricsOrigin origin, {
    bool replace = false,
  }) async {
    log.add('save ${origin.remoteId}');
    return (result: saveResult, kept: null);
  }

  @override
  Future<LyricsSaveOutcome> saveLocalAsLrc(
    LyricsTarget target, {
    bool replace = false,
  }) async {
    log.add('saveLocal');
    return (result: LrcWriteResult.written, kept: null);
  }
}
