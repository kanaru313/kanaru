import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'plugin_icon_check.dart';
import 'plugin_package_limits.dart';
import 'plugin_package_problem.dart';
import 'plugin_capped_output.dart';
import 'plugin_zip_directory_scan.dart';
import 'plugin_zip_entry_names.dart';

// `src/<name>.js`, flat; the whole file name is restricted.
final _scriptPath = RegExp(r'^src/([A-Za-z0-9_.-]+\.js)$');

/// The whitelisted entries of a plugin zip, still raw bytes.
class PluginZipContents {
  const PluginZipContents({
    required this.manifest,
    required this.scripts,
    this.icon,
    this.iconProblem,
  });

  /// `plugin.json` bytes.
  final Uint8List manifest;

  /// `src/` files by name (`search.js`), bytes not yet decoded.
  final Map<String, Uint8List> scripts;

  /// `icon.png` bytes, null when absent or [iconProblem] says it is bad.
  final Uint8List? icon;

  /// Why the icon was dropped (for the log); null when kept or absent.
  final String? iconProblem;
}

/// Reads [bytes] as a plugin zip entirely in memory. Throws
/// [PluginPackageProblem] for any rule broken; nothing is partly returned.
///
/// Only `plugin.json`, `icon.png` and `src/<name>.js` are inflated. Other
/// entries are ignored but their names, count and declared sizes still count
/// toward the limits. Every inflate is capped at the entry's declared size,
/// which is first checked against the caps, so an entry whose header lies
/// about its size is refused instead of filling memory.
PluginZipContents readPluginZip(Uint8List bytes) {
  if (bytes.length > maxPluginPackageBytes) {
    throw const PluginPackageProblem(PluginPackageProblemKind.tooLarge);
  }
  final headers = _readHeaders(bytes);
  for (final header in headers) {
    checkPluginEntryName(header.filename);
    checkNotSymlink(header);
  }
  checkNoDuplicateNames(headers.map((h) => h.filename));
  var declaredTotal = 0;
  for (final header in headers) {
    declaredTotal += header.uncompressedSize;
    if (declaredTotal > maxPluginUnpackedBytes) {
      throw PluginPackageProblem(
        PluginPackageProblemKind.tooLarge,
        detail: header.filename,
      );
    }
  }

  final folder = pluginTopFolder(headers.map((h) => h.filename).toList());
  final prefix = folder == null ? '' : '$folder/';
  Uint8List? manifest;
  Uint8List? icon;
  String? iconProblem;
  final scripts = <String, Uint8List>{};
  var inflatedTotal = 0;
  for (final header in headers) {
    final name = header.filename.substring(prefix.length);
    final scriptMatch = _scriptPath.firstMatch(name);
    final int cap;
    if (name == 'plugin.json') {
      cap = maxPluginManifestBytes;
    } else if (name == 'icon.png') {
      cap = maxPluginIconBytes;
    } else if (scriptMatch != null) {
      cap = maxPluginScriptBytes;
    } else {
      continue;
    }
    if (header.uncompressedSize > cap) {
      if (name == 'icon.png') {
        iconProblem = 'over $cap B';
        continue;
      }
      throw PluginPackageProblem(
        PluginPackageProblemKind.tooLarge,
        detail: header.filename,
      );
    }
    final Uint8List data;
    try {
      data = _inflate(header);
    } on PluginPackageProblem {
      // A broken icon is dropped like any bad icon; anything else is fatal.
      if (name == 'icon.png') {
        iconProblem = 'cannot be inflated';
        continue;
      }
      rethrow;
    }
    inflatedTotal += data.length;
    if (inflatedTotal > maxPluginUnpackedBytes) {
      throw PluginPackageProblem(
        PluginPackageProblemKind.tooLarge,
        detail: header.filename,
      );
    }
    if (name == 'plugin.json') {
      manifest = data;
    } else if (name == 'icon.png') {
      iconProblem = pluginIconProblem(data);
      icon = iconProblem == null ? data : null;
    } else {
      scripts[scriptMatch!.group(1)!] = data;
    }
  }
  if (manifest == null) {
    throw const PluginPackageProblem(PluginPackageProblemKind.missingManifest);
  }
  return PluginZipContents(
    manifest: manifest,
    scripts: scripts,
    icon: icon,
    iconProblem: iconProblem,
  );
}

List<ZipFileHeader> _readHeaders(Uint8List bytes) {
  // Cheap walk first: the parser below allocates per central record.
  final expected = scanPluginZipDirectory(bytes);
  final directory = ZipDirectory();
  try {
    directory.read(InputMemoryStream(bytes));
  } on Object {
    // The zip parser throws several types on hostile input; all mean the
    // same here.
    throw const PluginPackageProblem(PluginPackageProblemKind.notZip);
  }
  if (directory.fileHeaders.length != expected) {
    throw const PluginPackageProblem(PluginPackageProblemKind.notZip);
  }
  return directory.fileHeaders;
}

/// Inflates one entry: stored or deflate, not encrypted. The output is
/// capped at the declared size by a stream of our own, so data longer than
/// declared is `tooLarge` whatever the zip package does; any other failure
/// is `notZip`.
Uint8List _inflate(ZipFileHeader header) {
  PluginPackageProblem problem(PluginPackageProblemKind kind) =>
      PluginPackageProblem(kind, detail: header.filename);
  final file = header.file;
  final method = header.compressionMethod;
  if (file == null ||
      (method != 0 && method != 8) ||
      header.generalPurposeBitFlag & 1 != 0) {
    throw problem(PluginPackageProblemKind.notZip);
  }
  final declared = header.uncompressedSize;
  final raw = file.getRawContent();
  final Uint8List data;
  if (method == 0) {
    if (raw.length > declared) throw problem(PluginPackageProblemKind.tooLarge);
    data = raw;
  } else {
    final out = PluginCappedOutput(declared);
    try {
      ZLibDecoder().decodeStream(InputMemoryStream(raw), out, raw: true);
    } on PluginOutputOverrun {
      throw problem(PluginPackageProblemKind.tooLarge);
    } on Object {
      throw problem(PluginPackageProblemKind.notZip);
    }
    data = out.getBytes();
  }
  if (data.length != declared || getCrc32(data) != header.crc32) {
    throw problem(PluginPackageProblemKind.notZip);
  }
  return data;
}
