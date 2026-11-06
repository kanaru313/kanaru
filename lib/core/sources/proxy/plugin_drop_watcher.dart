import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/settings_provider.dart';
import '../source_plugin_records.dart';

/// What [watchPluginDrops] tells: a source plugin stopped being usable, or
/// became usable again.
abstract interface class PluginDropTarget {
  /// [installId] left the enabled source plugins or the accepted notices.
  void dropPlugin(String installId);

  /// [installId] is an enabled source plugin with an accepted notice again
  /// (its notice was accepted anew, or its record came back).
  void restorePlugin(String installId);
}

/// Listens, for as long as [ref] lives, to the enabled source plugins and
/// to the accepted source notices, and tells [target] about every install
/// id that leaves either. An id that is again in both is restored. Only
/// records really read count: while the list is loading or failed nothing
/// is dropped or restored, and a settings change that leaves the accepted
/// notices as they are does nothing.
///
/// The listens are the container's, closed when [ref] is disposed: the
/// provider calling this is only read (never watched), and Riverpod pauses
/// the own listens of a provider nobody listens to, so a record removal
/// would never reach it.
void watchPluginDrops(Ref ref, PluginDropTarget target) {
  Set<String>? enabled;
  late Set<String> consented;

  Set<String>? idsOf(AsyncValue<List<LyricsPluginRecord>> records) =>
      records.hasValue && !records.hasError
      ? {for (final record in records.requireValue) record.installId}
      : null;

  final container = ref.container;
  final records = container.listen(sourcePluginRecordsProvider, (_, next) {
    final now = idsOf(next);
    if (now == null) return;
    final before = enabled;
    enabled = now;
    if (before == null) return;
    before.difference(now).forEach(target.dropPlugin);
    now
        .difference(before)
        .where(consented.contains)
        .forEach(target.restorePlugin);
  });
  final notices = container.listen(
    settingsProvider.select((s) => s.onlineSources.noticeAcknowledged),
    (_, next) {
      final before = consented;
      consented = Set.of(next);
      before.difference(consented).forEach(target.dropPlugin);
      final known = enabled;
      if (known == null) return;
      consented
          .difference(before)
          .where(known.contains)
          .forEach(target.restorePlugin);
    },
  );
  ref.onDispose(() {
    records.close();
    notices.close();
  });
  enabled = idsOf(records.read());
  consented = Set.of(notices.read());
}
