import '../online/lyrics_http.dart';
import '../online/lyrics_provider.dart';
import 'lyrics_plugin_record.dart';
import 'plugin_output_reader.dart';
import 'plugin_script_runner.dart';

/// An installed plugin as a [LyricsProvider]: `id` is the install id,
/// `displayName` the plugin's name and `hosts` the hosts its manifest
/// declares. It holds no state; every call goes through the shared
/// [PluginScriptRunner], which runs the package's `search.js` or `lyrics.js`
/// and maps failures to `LyricsFetchException`.
class PluginLyricsProvider implements LyricsProvider {
  PluginLyricsProvider(LyricsPluginRecord record, this._runner)
    : id = record.installId,
      displayName = record.name,
      hosts = record.hosts;

  final PluginScriptRunner _runner;

  @override
  final String id;

  @override
  final String displayName;

  @override
  final List<String> hosts;

  /// A plugin has no exact-match call: the answer is always `null`, without
  /// running any script, and the host then runs [search].
  @override
  Future<LyricsCandidate?> lookup(LyricsQuery query, LyricsHttp http) =>
      Future.value();

  /// Runs `search.js` with `{title, artist, album, durationMs}` (missing
  /// tags are `null`), or `{text}` for the manual search.
  @override
  Future<List<LyricsCandidate>> search(LyricsQuery query, LyricsHttp http) {
    final text = query.text;
    final input = text != null
        ? {'text': text}
        : {
            'title': query.title,
            'artist': query.artist,
            'album': query.album,
            'durationMs': query.duration?.inMilliseconds,
          };
    return _runner.run(
      installId: id,
      script: PluginScript.search,
      input: input,
      http: http,
      read: (json, notes) {
        final output = readSearchOutput(json, providerId: id);
        notes.addAll(output.dropped);
        return output.candidates;
      },
    );
  }

  /// Runs `lyrics.js` with the record's id.
  @override
  Future<LyricsBody?> fetch(String remoteId, LyricsHttp http) => _runner.run(
    installId: id,
    script: PluginScript.lyrics,
    input: remoteId,
    http: http,
    read: (json, _) => readLyricsOutput(json),
  );
}
