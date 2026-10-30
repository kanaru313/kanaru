import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/lyrics_provider.dart';
import '../../core/lyrics/online/lyrics_provider_registry.dart';
import '../../core/lyrics/online/lyrics_search_controller.dart';
import '../../core/lyrics/online/lyrics_source_names.dart';
import '../../core/lyrics/online/lyrics_target.dart';
import '../../l10n/l10n.dart';
import '../format_duration.dart';
import 'lyrics_picker_preview.dart';
import 'lyrics_picker_results_pane.dart';

const _contentWidth = 840.0;
const _contentHeight = 520.0;
const _listWidth = 420.0;

/// The Choose lyrics dialog: a query field, the ranked results of the manual
/// search and a preview of the selected one. Pops the chosen
/// [LyricsCandidate], or `null` on Cancel. The content has a fixed size and
/// scrolls inside a smaller window.
class LyricsPickerDialog extends ConsumerStatefulWidget {
  const LyricsPickerDialog({super.key, required this.target});

  final LyricsTarget target;

  @override
  ConsumerState<LyricsPickerDialog> createState() => _LyricsPickerDialogState();
}

class _LyricsPickerDialogState extends ConsumerState<LyricsPickerDialog> {
  late final _query = TextEditingController(
    text: lyricsSearchPrefill(widget.target),
  );

  bool get _searchesOnOpen => widget.target.query.title != null;

  LyricsSearchController get _controller =>
      ref.read(lyricsSearchControllerProvider(widget.target).notifier);

  @override
  void initState() {
    super.initState();
    // Only a song with a real title searches on open; any other waits for
    // the user to press Search. A provider may not change while widgets
    // build.
    if (!_searchesOnOpen) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.search(_query.text);
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search() => _controller.search(_query.text);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(lyricsSearchControllerProvider(widget.target));
    final registrations = ref.watch(lyricsProvidersProvider);
    final names = ref.watch(lyricsSourceNamesProvider);
    final query = widget.target.query;
    final duration = query.duration;
    final selection = state.selection;
    return Dialog(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: SizedBox(
            width: _contentWidth,
            height: _contentHeight,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.lyricsPickerTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.lyricsPickerSong(
                      query.title ?? '-',
                      query.artist ?? '-',
                      duration == null ? '-' : formatDuration(duration),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _query,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _search(),
                          decoration: InputDecoration(
                            hintText: l10n.lyricsPickerQueryHint,
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Search stays off while the field is blank.
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _query,
                        builder: (context, value, _) => FilledButton.tonal(
                          onPressed: value.text.trim().isEmpty ? null : _search,
                          child: Text(l10n.lyricsPickerSearch),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: _listWidth,
                          child: LyricsPickerResultsPane(
                            state: state,
                            searchPending: _searchesOnOpen,
                            providerNames: {
                              for (final r in registrations)
                                r.id: names[r.id]?.displayName ?? r.id,
                            },
                            onSelect: _controller.select,
                            onRetry: _controller.retry,
                          ),
                        ),
                        const VerticalDivider(width: 24),
                        Expanded(
                          child: LyricsPickerPreview(
                            candidate: selection?.candidate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.lyricsPickerFooter(
                      registrations.expand((r) => r.hosts).toSet().join(', '),
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          MaterialLocalizations.of(context).cancelButtonLabel,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: selection != null && selection.selectable
                            ? () =>
                                  Navigator.of(context).pop(selection.candidate)
                            : null,
                        child: Text(l10n.lyricsPickerUse),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
