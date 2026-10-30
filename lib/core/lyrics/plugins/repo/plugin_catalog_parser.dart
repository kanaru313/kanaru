import 'dart:convert';
import 'dart:typed_data';

import '../../online/lyrics_provider_registry.dart';
import '../package/plugin_text_clean.dart';
import 'plugin_catalog.dart';
import 'repo_address_rules.dart';
import 'repo_fetch_exception.dart';
import 'repo_http.dart';

/// Most entries a catalog may list.
const maxCatalogEntries = 500;

final _slug = RegExp(r'^[a-z0-9_-]{1,64}$');
const _maxReferenceLength = 2048;

/// Parses a catalog fetched from [origin]`.url` (the final address after
/// redirects, which relative `path` and `icon` are resolved against) whose
/// address is of class [origin]`.kind`.
///
/// Throws [RepoFetchException]: `tooLarge` for a body over the cap and
/// `invalidCatalog` for bad JSON or shape, a missing name, more than
/// [maxCatalogEntries] entries, or a non-empty `data` of which no entry is
/// usable. An entry that is not valid is dropped and counted in
/// [PluginCatalog.dropped]; the entry rules are those of the plugin
/// manifest (name, version, hosts, text cleaning), plus the slug rule, the
/// `type` of `lyrics`, and the address rules for `path` (a bad `path` drops
/// the entry) and `icon` (a bad `icon` only drops the icon). An entry whose
/// `apiVersion` is newer than this app understands is kept.
PluginCatalog parsePluginCatalog(Uint8List bytes, PluginCatalogOrigin origin) {
  if (bytes.length > repoCatalogMaxBytes) {
    throw const RepoFetchException(RepoFetchErrorKind.tooLarge);
  }
  const invalid = RepoFetchException(RepoFetchErrorKind.invalidCatalog);
  final Object? json;
  try {
    var text = utf8.decode(bytes);
    if (text.startsWith('﻿')) text = text.substring(1);
    json = jsonDecode(text);
  } on FormatException {
    throw invalid;
  }
  if (json is! Map<String, dynamic>) throw invalid;
  final metadata = json['metadata'];
  final data = json['data'];
  if (metadata is! Map<String, dynamic> || data is! List) throw invalid;
  final name = _text(metadata['name'], min: 1, max: 80);
  final author = _text(metadata['author'], max: 80, optional: true);
  if (name == null || author == null) throw invalid;
  if (data.length > maxCatalogEntries) throw invalid;

  final entries = <PluginCatalogEntry>[];
  final slugs = <String>{};
  var dropped = 0;
  for (final raw in data) {
    final entry = raw is Map<String, dynamic> ? _entry(raw, origin) : null;
    if (entry == null || !slugs.add(entry.slug)) {
      dropped++;
      continue;
    }
    entries.add(entry);
  }
  if (data.isNotEmpty && entries.isEmpty) throw invalid;
  return PluginCatalog(
    name: name,
    author: author,
    entries: List.unmodifiable(entries),
    dropped: dropped,
  );
}

PluginCatalogEntry? _entry(
  Map<String, dynamic> json,
  PluginCatalogOrigin origin,
) {
  final slug = json['slug'];
  if (slug is! String || !_slug.hasMatch(slug)) return null;
  if (json['type'] != 'lyrics') return null;
  final name = _text(json['name'], min: 1, max: 80);
  final version = json['version'];
  final apiVersion = json['apiVersion'];
  if (name == null) return null;
  if (version is! int || version < 1 || version > 2147483647) return null;
  if (apiVersion is! int || apiVersion < 1) return null;
  final hosts = _hosts(json['hosts']);
  final author = _text(json['author'], max: 80, optional: true);
  final description = _text(
    json['description'],
    max: 500,
    optional: true,
    keepNewlines: true,
  );
  if (hosts == null || author == null || description == null) return null;
  final path = _reference(json['path'], origin);
  if (path == null) return null;
  final iconField = json['icon'];
  final icon = iconField == null ? null : _reference(iconField, origin);
  return PluginCatalogEntry(
    slug: slug,
    name: name,
    version: version,
    apiVersion: apiVersion,
    hosts: hosts,
    path: path,
    icon: icon,
    description: description,
    author: author,
  );
}

/// Resolves [value] against the catalog address and applies the address
/// rules that need no lookup; null when it fails either. The lookup-based
/// rules run again when the address is fetched.
Uri? _reference(Object? value, PluginCatalogOrigin origin) {
  if (value is! String || value.isEmpty || value.length > _maxReferenceLength) {
    return null;
  }
  final parsed = Uri.tryParse(value);
  if (parsed == null) return null;
  final resolved = origin.url.resolveUri(parsed).removeFragment();
  // The address is stored in its absolute form, so the length rule applies to
  // that form: what is accepted here is what reads back.
  if (resolved.toString().length > _maxReferenceLength) return null;
  final verdict = judgeRepoAddress(resolved, catalogKind: origin.kind);
  return verdict.isAllowed ? resolved : null;
}

List<String>? _hosts(Object? value) {
  if (value is! List || value.isEmpty || value.length > 20) return null;
  final hosts = <String>{};
  for (final item in value) {
    if (item is! String) return null;
    final host = item.trim().toLowerCase();
    if (lyricsHostProblem(host) != null) return null;
    hosts.add(host);
  }
  return List.unmodifiable(hosts);
}

/// Same cleaning and length rules as the manifest fields. Null when the
/// value breaks them; a missing optional value gives ''.
String? _text(
  Object? value, {
  int min = 0,
  required int max,
  bool optional = false,
  bool keepNewlines = false,
}) {
  if (value == null && optional) return '';
  if (value is! String) return null;
  final cleaned = cleanPluginText(value, keepNewlines: keepNewlines);
  final length = cleaned.runes.length;
  if (length < min || length > max) return null;
  return cleaned;
}
