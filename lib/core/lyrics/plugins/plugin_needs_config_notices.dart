import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/lyrics_plugin_queries.dart';

/// A run of a plugin was blocked (or the user acted on a plugin) while a
/// required config field is empty.
typedef PluginNeedsConfigNotice = ({
  String installId,
  String name,
  PluginKind? kind,
  int seq,
});

/// The latest needs-config report. Every report is a new state (its `seq`
/// grows), so a repeat for the same plugin still reaches listeners. The shell
/// shows one snack bar per report.
final pluginNeedsConfigNoticesProvider =
    NotifierProvider<PluginNeedsConfigNotices, PluginNeedsConfigNotice?>(
      PluginNeedsConfigNotices.new,
    );

class PluginNeedsConfigNotices extends Notifier<PluginNeedsConfigNotice?> {
  @override
  PluginNeedsConfigNotice? build() => null;

  void report(String installId, String name, PluginKind? kind) {
    state = (
      installId: installId,
      name: name,
      kind: kind,
      seq: (state?.seq ?? 0) + 1,
    );
  }
}
