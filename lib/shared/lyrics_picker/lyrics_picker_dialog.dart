import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/lyrics_provider.dart';
import '../../core/lyrics/online/lyrics_provider_registry.dart';
import '../../core/lyrics/online/lyrics_search_controller.dart';
import '../../core/lyrics/online/lyrics_source_names.dart';
import '../../core/lyrics/online/lyrics_target.dart';
import '../../l10n/l10n.dart';
import 'lyrics_picker_actions.dart';
import 'lyrics_picker_disabled_sources_card.dart';
import 'lyrics_picker_dialog_size.dart';
import 'lyrics_picker_failure_line.dart';
import 'lyrics_picker_footer.dart';
import 'lyrics_picker_preview.dart';
import 'lyrics_picker_result_sources.dart';
import 'lyrics_picker_results_pane.dart';
import 'lyrics_picker_search_row.dart';
import 'lyrics_picker_sources_modal.dart';
import 'lyrics_picker_title_row.dart';
import 'lyrics_source_name_text.dart';

part 'lyrics_picker_dialog_actions.dart';

/// The content of the Choose lyrics modal: a query field, the ranked results of the manual
/// search and a preview of the selected one. Pops the chosen
/// [LyricsCandidate], or `null` on Cancel. The content is 840 px wide and tall
/// by the window (see [lyricsPickerContentHeight]); it scrolls inside a smaller
/// window.
class LyricsPickerDialog extends ConsumerStatefulWidget {
  const LyricsPickerDialog({super.key, required this.target});

  final LyricsTarget target;

  @override
  ConsumerState<LyricsPickerDialog> createState() => _LyricsPickerDialogState();
}

class _LyricsPickerDialogState extends ConsumerState<LyricsPickerDialog>
    with _PickerActions {
  @override
  void initState() {
    super.initState();
    _watchBlank();
    // Only a song with a real title searches on open (after the build).
    if (!_searchesOnOpen) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.search(_query.text);
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(lyricsSearchControllerProvider(widget.target));
    final names = ref.watch(lyricsSourceNamesProvider);
    final enabled = ref.watch(lyricsProvidersProvider);
    final off = ref.watch(disabledLyricsProvidersProvider);
    // Enabled sources and the off ones searched on request: only these name
    // results and show their hosts.
    final registrations = searchRegistrations(
      enabled: enabled,
      disabled: off,
      state: state,
    );
    final unsearched = unsearchedOffSources(l10n, names, off, state);
    final blank = _queryBlank;
    final query = widget.target.query;
    final selection = state.selection;
    final sources = lyricsResultSources(state.results);
    final providerNames = {
      for (final r in registrations)
        r.id: lyricsSourceNameText(l10n, names, r.id),
    };
    final fetch = state.selectionFetch;
    final failure = lyricsSelectionFailure(l10n, state, providerNames);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: SizedBox(
          width: lyricsPickerContentWidth,
          height: lyricsPickerContentHeight(MediaQuery.sizeOf(context).height),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LyricsPickerTitleRow(query: query),
                const SizedBox(height: 16),
                LyricsPickerSearchRow(
                  query: _query,
                  sources: sources,
                  providerNames: providerNames,
                  sourceFilter: _sourceFilter,
                  onOpenSources: _openSources,
                  onSearch: _search,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: lyricsPickerListWidth,
                        child: LyricsPickerResultsPane(
                          state: state,
                          scrollController: _listScroll,
                          searchPending: _searchesOnOpen,
                          noSource:
                              ref.watch(lyricsSourcesLoadedProvider) &&
                              registrations.isEmpty,
                          offSourcesCard:
                              unsearched.isEmpty ||
                                  !ref.watch(lyricsSourcesLoadedProvider)
                              ? null
                              : LyricsPickerDisabledSourcesCard(
                                  sources: unsearched,
                                  noneOn:
                                      enabled.isEmpty && state.results.isEmpty,
                                  onSearch: blank
                                      ? null
                                      : () => _searchOff({
                                          for (final s in unsearched) s.id,
                                        }),
                                ),
                          providerNames: providerNames,
                          sourceFilter: effectiveSourceFilter(
                            _sourceFilter,
                            sources,
                          ),
                          onSelect: _controller.select,
                          onRetry: _retry,
                        ),
                      ),
                      const VerticalDivider(width: 24),
                      Expanded(
                        child: LyricsPickerPreview(
                          candidate: selection?.candidate,
                          loading: fetch?.phase == BodyFetchPhase.loading,
                          failure: failure,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                LyricsPickerFooter(registrations: registrations),
                const SizedBox(height: 12),
                LyricsPickerActions(selection: selection),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
