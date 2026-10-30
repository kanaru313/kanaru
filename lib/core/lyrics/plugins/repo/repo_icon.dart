import 'dart:typed_data';

import '../package/plugin_icon_check.dart';
import 'repo_address_rules.dart';
import 'repo_fetch_exception.dart';
import 'repo_http.dart';

/// Fetches the icon of a catalog entry and returns its bytes only when they
/// are an acceptable PNG (`pluginIconProblem`: signature, IHDR, at most
/// 256x256, 64 KiB). Any failure (address rules, network, size, not a PNG)
/// gives null: a missing icon is never an error for the store.
Future<Uint8List?> fetchCatalogIcon(
  RepoHttp http,
  Uri url, {
  required RepoAddressKind catalogKind,
}) async {
  try {
    final response = await http.fetchIcon(url, catalogKind: catalogKind);
    return pluginIconProblem(response.bytes) == null ? response.bytes : null;
  } on RepoFetchException {
    return null;
  }
}
