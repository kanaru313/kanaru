import 'plugin_text_clean.dart';

/// Why a plugin package was refused. Core holds no UI text: the app maps a
/// kind (plus detail) to a localized message.
enum PluginPackageProblemKind {
  /// The file is over the package size cap, or a zip entry or the unpacked
  /// total is over its cap. `detail` names the entry when one is to blame.
  tooLarge,

  /// Not a readable zip, or an entry cannot be inflated. `detail` says which
  /// entry, when known.
  notZip,

  /// An entry name or kind that must never be unpacked (path traversal,
  /// absolute path, symlink, duplicate name). `detail` is the entry name.
  unsafeEntry,

  /// More entries than the cap.
  tooManyEntries,

  /// No `plugin.json` at the top of the package.
  missingManifest,

  /// `plugin.json` is unreadable or breaks a rule. `detail` is the field.
  invalidManifest,

  /// `metadata.apiVersion` is newer than this app understands.
  needsNewerApp,

  /// `metadata.type` is not `lyrics`.
  wrongType,

  /// A host that is not a public DNS name. `detail` is the host.
  badHost,

  /// `script.search` or `script.lyrics` names a file not in `src/`.
  /// `detail` is the file name.
  missingScript,

  /// A script does not compile or is not UTF-8. `detail` is the file name,
  /// `line` the 1-based line when known, `message` the engine's text.
  scriptError,

  /// The script runtime could not check the scripts (library not loadable),
  /// so the package cannot be told valid.
  checkUnavailable,
}

/// A refused package. Thrown by the stages inside the reader; the reader
/// turns it into a [PluginPackageRejected] result, so callers never see it.
class PluginPackageProblem implements Exception {
  // The private fields hold the raw text and the getters clean it, so the
  // named parameters cannot be initializing formals.
  const PluginPackageProblem(
    this.kind, {
    String detail = '',
    this.line,
    String? message,
    // ignore: prefer_initializing_formals
  }) : _detail = detail,
       // ignore: prefer_initializing_formals
       _message = message;

  final PluginPackageProblemKind kind;

  final String _detail;
  final String? _message;

  /// Entry name, manifest field, host or script file, per [kind]. It can echo
  /// attacker text, so control characters are replaced and it is cut to 200
  /// code points.
  String get detail => limitPluginText(_detail, 200);

  /// 1-based line of a script error; null when unknown.
  final int? line;

  /// Engine text for a script error (cleaned and cut like [detail]); not
  /// meant for display as is.
  String? get message {
    final text = _message;
    return text == null ? null : limitPluginText(text, 200);
  }

  @override
  String toString() => 'PluginPackageProblem($kind, $detail)';
}
