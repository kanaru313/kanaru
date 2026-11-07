import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'source_plugin_records.dart';

/// Whether at least one enabled source plugin exists. False while the list
/// is loading and when it could not be read, so the Online entry never
/// flashes in or stays after an error.
final hasSourcePluginsProvider = Provider<bool>(
  (ref) => switch (ref.watch(sourcePluginRecordsProvider)) {
    AsyncData(:final value) => value.isNotEmpty,
    _ => false,
  },
);
