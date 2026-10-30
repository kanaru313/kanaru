import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'plugin_runtime.dart';
import 'rust_plugin_runtime.dart';

/// The sandboxed plugin runtime. No dependencies, so it is never rebuilt.
final pluginRuntimeProvider = Provider<PluginRuntime>(
  (ref) => const RustPluginRuntime(),
);
