import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/paths/app_directories.dart';

/// Where Kanaru keeps its files; a `null` path could not be resolved.
class AppDirectoryPaths {
  const AppDirectoryPaths({this.config, this.data, this.cache});

  final String? config;
  final String? data;
  final String? cache;
}

/// Read from the real environment; tests override it.
final appDirectoryPathsProvider = Provider<AppDirectoryPaths>((ref) {
  final environment = Platform.environment;
  return AppDirectoryPaths(
    config: resolveConfigDirectory(environment),
    data: resolveDataDirectory(environment),
    cache: resolveCacheDirectory(environment),
  );
});
