import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/language_queries.dart';
import '../../../core/indexer/cover_paths.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/enqueue_tracks.dart';
import '../../../shared/language_display_name.dart';
import '../../../shared/language_summaries.dart';
import '../../../shared/play_tracks.dart';
import '../../../shared/widgets/queue_actions_menu.dart';

/// [enqueueTracks] for a language: its songs, in the order of its page.
void enqueueLanguage(
  WidgetRef ref,
  BuildContext context,
  QueueAction action,
  LanguageSummary language,
) => enqueueFromDatabase(
  ref,
  context,
  action,
  languageSummaryName(context.l10n, language),
  (db, covers) async => [
    for (final t in await db.languageTracks(language.raws))
      trackFromBrowse(t, artPath: coverPath(covers, t.coverKey)),
  ],
);
