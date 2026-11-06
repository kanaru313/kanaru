import '../lyrics/plugins/store/plugin_install_id.dart';

/// Where a track found through a source plugin comes from: the plugin and
/// its own id of the item. A remote track has no file; its audio is
/// resolved by the plugin's `stream.js` when the player asks for it.
class RemoteSourceRef {
  const RemoteSourceRef({
    required this.installId,
    required this.itemId,
    this.artworkUrl,
    this.webUrl,
  });

  /// Install id of the source plugin (`plugin-` + 12 `[a-z0-9]`).
  final String installId;

  /// The plugin's id of the item, handed back to `stream.js` as it came.
  final String itemId;

  /// Absolute `https` URLs from the search result, or null.
  final String? artworkUrl;
  final String? webUrl;

  @override
  bool operator ==(Object other) =>
      other is RemoteSourceRef &&
      other.installId == installId &&
      other.itemId == itemId &&
      other.artworkUrl == artworkUrl &&
      other.webUrl == webUrl;

  @override
  int get hashCode => Object.hash(installId, itemId, artworkUrl, webUrl);

  @override
  String toString() => 'RemoteSourceRef($installId)';
}

/// The scheme of a remote track's uri.
const remoteTrackUriScheme = 'kanaru-source';

const _prefix = '$remoteTrackUriScheme:';

/// The uri of the track [ref] names:
/// `kanaru-source:<installId>/<Uri.encodeComponent(itemId)>`. The item id
/// is encoded, so a `/` or `%` in it stays inside its part.
String remoteTrackUri(RemoteSourceRef ref) =>
    '$_prefix${ref.installId}/${Uri.encodeComponent(ref.itemId)}';

/// The plugin and item a [remoteTrackUri] names (no artwork or web URL), or
/// null when [uri] is not one: another scheme, an install id that is not a
/// plugin id, an empty item id, or an item part that is not exactly what
/// [remoteTrackUri] writes.
RemoteSourceRef? parseRemoteTrackUri(String uri) {
  if (!uri.startsWith(_prefix)) return null;
  final rest = uri.substring(_prefix.length);
  final slash = rest.indexOf('/');
  if (slash < 0) return null;
  final installId = rest.substring(0, slash);
  final encoded = rest.substring(slash + 1);
  if (!pluginInstallIdPattern.hasMatch(installId) || encoded.isEmpty) {
    return null;
  }
  final String itemId;
  try {
    itemId = Uri.decodeComponent(encoded);
  } on ArgumentError {
    return null;
  } on FormatException {
    return null;
  }
  // One uri per item: a differently encoded form is not accepted.
  if (Uri.encodeComponent(itemId) != encoded) return null;
  return RemoteSourceRef(installId: installId, itemId: itemId);
}

/// Whether [uri] is a [remoteTrackUri].
bool isRemoteTrackUri(String uri) => parseRemoteTrackUri(uri) != null;
