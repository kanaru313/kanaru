import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics/lrc_sidecar_reader.dart';
import '../../../../../core/lyrics/lyrics.dart';
import '../../../../../core/lyrics/online/lrc_sidecar_write_steps.dart';
import '../../../../../core/lyrics/online/playing_lyrics_source_provider.dart';
import '../../../../../core/lyrics/online/playing_lyrics_status.dart';
import '../../../../../core/player/local_path_of.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/icons/app_icons.dart';
import '../../../../../shared/widgets/layered_modal/layered_modal_route.dart';
import '../../../../../shared/widgets/selection_row.dart';
import '../../lyrics_save_flow.dart';
import 'lyrics_source_modal_run.dart';

/// Opens the child modal "Save lyrics to" over the lyrics source modal that
/// owns [context]. [source] and [messenger] are the ones the parent holds, so
/// the save acts on the lyrics the user saw and reports on the screen behind.
Future<void> showLyricsSaveTargetsModal(
  BuildContext context, {
  required LyricsSourceResolution source,
  required ScaffoldMessengerState? messenger,
}) => showLayeredModal<void>(
  context,
  semanticLabel: context.l10n.lyricsSaveToTitle,
  builder: (_) => LyricsSaveTargetsModal(
    parentContext: context,
    source: source,
    messenger: messenger,
  ),
);

/// Multi-select list of the places the lyrics on screen can be saved to, with
/// a [Save (n)] button. The `.lrc` file is chosen at first; the tags are
/// listed but not available yet.
///
/// Saving closes the whole modal stack first, so the result snackbar shows on
/// the screen behind instead of under the scrim.
class LyricsSaveTargetsModal extends StatefulWidget {
  const LyricsSaveTargetsModal({
    super.key,
    required this.parentContext,
    required this.source,
    required this.messenger,
  });

  /// Context of the parent modal: closing the stack from it closes the parent
  /// and this child, while closing from the child would leave the parent.
  final BuildContext parentContext;
  final LyricsSourceResolution source;
  final ScaffoldMessengerState? messenger;

  @override
  State<LyricsSaveTargetsModal> createState() => _LyricsSaveTargetsModalState();
}

class _LyricsSaveTargetsModalState extends State<LyricsSaveTargetsModal> {
  final _targets = <LyricsSaveTarget>{};
  var _initialized = false;
  var _busy = false;

  /// An `.lrc` already sits next to the song, so saving moves it to the trash.
  var _sidecarExists = false;

  @override
  void initState() {
    super.initState();
    final path = localPathOf(widget.source.status.uri);
    if (path != null) {
      existingLrcSidecars(path).then((names) {
        if (mounted && names.isNotEmpty) setState(() => _sidecarExists = true);
      }, onError: (_) {});
    }
  }

  /// The shown lyrics come from the `.lrc` file itself: saving there would
  /// only rewrite it.
  bool get _fromSidecar {
    final status = widget.source.status;
    return status is LyricsFound &&
        status.origin == null &&
        status.lyrics.source == LyricsSource.sidecar;
  }

  String? get _sidecarName {
    final uri = widget.source.status.uri;
    final path = localPathOf(uri);
    return path == null ? null : lrcCandidates(path).first.split('/').last;
  }

  void _toggle(LyricsSaveTarget target) => setState(() {
    if (!_targets.remove(target)) _targets.add(target);
  });

  void _save() {
    if (_busy || _targets.isEmpty) return;
    setState(() => _busy = true);
    closeStackThenRun(
      widget.parentContext,
      source: widget.source,
      messenger: widget.messenger,
      action: (runner) => runner.save({..._targets}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lrcEnabled = !_fromSidecar;
    if (!_initialized) {
      _initialized = true;
      if (lrcEnabled) _targets.add(LyricsSaveTarget.lrc);
    }
    return LayeredModalBody(
      header: LayeredModalTopBar(title: l10n.lyricsSaveToTitle),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 16, 12),
        child: Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _busy || _targets.isEmpty ? null : _save,
            child: Text(l10n.lyricsSaveToButton(_targets.length)),
          ),
        ),
      ),
      children: [
        SelectionRow(
          title: l10n.lyricsSaveToLrc,
          subtitle: _sidecarName == null
              ? null
              : _sidecarExists
              ? l10n.lyricsSaveToLrcTrash(_sidecarName!)
              : _sidecarName,
          leading: const Icon(AppIcons.lyricsFile),
          selected: _targets.contains(LyricsSaveTarget.lrc),
          onTap: lrcEnabled && !_busy
              ? () => _toggle(LyricsSaveTarget.lrc)
              : null,
        ),
        SelectionRow(
          title: l10n.lyricsSaveToTag,
          subtitle: l10n.settingsComingSoon,
          leading: const Icon(AppIcons.editTags),
          selected: false,
          onTap: null,
        ),
      ],
    );
  }
}
