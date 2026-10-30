import 'dart:typed_data';

import 'plugin_manifest.dart';
import 'plugin_package_problem.dart';

/// A fully checked plugin, held in memory. Every field was validated.
class PluginPackage {
  const PluginPackage({required this.manifest, required this.files, this.icon});

  final PluginManifest manifest;

  /// `src/` files by name (`search.js`): UTF-8 decoded, BOM stripped, and
  /// accepted by the script runtime's syntax check.
  final Map<String, String> files;

  /// A valid `icon.png`; null when there was none or it was dropped.
  final Uint8List? icon;
}

/// Outcome of reading a package: all of it, or a problem and nothing else.
sealed class PluginPackageResult {
  const PluginPackageResult();
}

class PluginPackageAccepted extends PluginPackageResult {
  const PluginPackageAccepted(this.package);

  final PluginPackage package;
}

class PluginPackageRejected extends PluginPackageResult {
  const PluginPackageRejected(this.problem);

  final PluginPackageProblem problem;
}
