import 'package:archive/archive.dart';

import 'plugin_package_problem.dart';

final _driveLetter = RegExp(r'^[A-Za-z]:');

/// Throws [PluginPackageProblem] (`unsafeEntry`) when [name] could escape the
/// package folder if some code ever joined it to a path. Names are checked
/// even for entries that are ignored.
void checkPluginEntryName(String name) {
  PluginPackageProblem bad() =>
      PluginPackageProblem(PluginPackageProblemKind.unsafeEntry, detail: name);
  if (name.isEmpty) throw bad();
  if (name.contains('\u0000') || name.contains(r'\')) throw bad();
  if (name.startsWith('/') || _driveLetter.hasMatch(name)) throw bad();
  if (name.split('/').contains('..')) throw bad();
}

/// Throws `unsafeEntry` for a symlink entry: Unix file type bits (the high 16
/// bits of the external attributes) equal to the symlink type.
void checkNotSymlink(ZipFileHeader header) {
  final fileType = (header.externalFileAttributes >> 16) & 0xf000;
  if (fileType == 0xa000) {
    throw PluginPackageProblem(
      PluginPackageProblemKind.unsafeEntry,
      detail: header.filename,
    );
  }
}

/// Throws `unsafeEntry` when two entries have the same name, ignoring case
/// and a trailing slash.
void checkNoDuplicateNames(Iterable<String> names) {
  final seen = <String>{};
  for (final name in names) {
    final key = (name.endsWith('/') ? name.substring(0, name.length - 1) : name)
        .toLowerCase();
    if (!seen.add(key)) {
      throw PluginPackageProblem(
        PluginPackageProblemKind.unsafeEntry,
        detail: name,
      );
    }
  }
}

/// The single top-level folder to strip, or null. Zipping a folder instead
/// of its contents is the common mistake: `plugin.json` is then not at the
/// root but at `<dir>/plugin.json`, and every entry sits under `<dir>/`.
String? pluginTopFolder(List<String> names) {
  if (names.contains('plugin.json')) return null;
  for (final name in names) {
    if (!name.endsWith('/plugin.json')) continue;
    final dir = name.substring(0, name.length - '/plugin.json'.length);
    if (dir.isEmpty || dir.contains('/')) continue;
    if (names.every((n) => n.startsWith('$dir/'))) return dir;
  }
  return null;
}
