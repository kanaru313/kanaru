import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/language_queries.dart';
import '../../../core/database/library_database.dart' show LibraryDatabase;
import '../../../core/player/track.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/enqueue_tracks.dart';
import '../../../shared/language_display_name.dart';
import '../../../shared/language_summaries.dart';
import '../../../shared/play_tracks.dart';
import '../../../shared/widgets/queue_actions_menu.dart';

/// The songs of the language's page, in its order.
Future<List<Track>> Function(LibraryDatabase db, String? covers) _languageTracks(
  LanguageSummary language,
) => (db, covers) async {
  final rows = await db.languageTracks(language.raws);
  return [
    for (final t in rows)
      trackFromRow(t, covers),
  ];
};

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
  _languageTracks(language),
);

/// Replaces the queue with the songs of the language's page, in its order, and
/// plays from the first; see [playFromDatabase].
Future<void> playLanguage(WidgetRef ref, LanguageSummary language) =>
    playFromDatabase(ref, 'Playing a language failed', _languageTracks(language));
