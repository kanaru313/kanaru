import '../../../database/library_database.dart';
import 'plugin_repo.dart';
import 'repo_address_rules.dart';

/// Turns repository rows into [PluginRepo]s without parsing an unchanged
/// catalog again: a decoded catalog is kept per repository and reused while
/// the stored text is equal. A catalog is up to 1 MiB, and every write of one
/// repository makes the whole list emit, so decoding each time would cost
/// (repositories x writes) parses on the UI isolate.
///
/// Also holds the in-memory reason of a refused address (the table keeps the
/// error kind only).
class PluginRepoReader {
  final _decoded = <String, ({String text, StoredCatalog? stored})>{};
  final _reasons = <String, RepoAddressProblem>{};

  /// The repository of [row].
  PluginRepo read(LyricsPluginRepoRow row) =>
      PluginRepo.fromRow(row, decode: _decode, errorReason: _reasons[row.url]);

  /// Every row, in order. Forgets what was kept for repositories no longer
  /// listed.
  List<PluginRepo> readAll(List<LyricsPluginRepoRow> rows) {
    final urls = {for (final row in rows) row.url};
    _decoded.removeWhere((url, _) => !urls.contains(url));
    _reasons.removeWhere((url, _) => !urls.contains(url));
    return [for (final row in rows) read(row)];
  }

  /// Remembers why [url] was refused, or forgets it when [reason] is null.
  /// Set before the error kind is written, so the next emission carries it.
  void setReason(String url, RepoAddressProblem? reason) {
    if (reason == null) {
      _reasons.remove(url);
    } else {
      _reasons[url] = reason;
    }
  }

  StoredCatalog? _decode(String url, String text) {
    final hit = _decoded[url];
    if (hit != null && hit.text == text) return hit.stored;
    final stored = decodeStoredCatalog(url, text);
    _decoded[url] = (text: text, stored: stored);
    return stored;
  }
}
