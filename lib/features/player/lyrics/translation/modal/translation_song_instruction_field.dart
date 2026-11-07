import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/database/library_database.dart';
import '../../../../../core/database/library_startup.dart';
import '../../../../../core/database/lyric_translation_queries.dart';
import '../../../../../core/lyrics/plugins/package/plugin_manifest.dart';
import '../../../../../core/lyrics_translation/translation_providers.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/lyrics_plugins/config/plugin_config_flush_group.dart';

final _log = Logger('lyrics_translation');

/// The "Note for this song" box of the tune modal: a note that only applies
/// to the lyrics text [hash], kept apart from the plugin's shared
/// instruction. It saves when the user leaves the box or presses Enter, and
/// it joins the modal's [flushGroup].
///
/// [hash] is the lyrics hash captured when the modal opened, never the one
/// playing now: when the track changes under the open modal, the unsaved
/// note still goes to the song it was written for. Saving a note does not
/// touch the plugin's config, so it never makes failed translations start
/// over and never starts a translation.
class TranslationSongInstructionField extends ConsumerWidget {
  const TranslationSongInstructionField({
    super.key,
    required this.hash,
    required this.field,
    this.flushGroup,
  });

  final String hash;

  /// The plugin's standard `customInstruction` field: its subtitle and the
  /// longest text it allows.
  final PluginConfigField field;
  final PluginConfigFlushGroup? flushGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(songTranslationInstructionProvider(hash));
    // The box is built once the note is read, so it starts with it.
    if (saved.isLoading) return const SizedBox(height: 72);
    return _NoteBox(
      hash: hash,
      field: field,
      // A note that cannot be read shows as an empty box.
      saved: saved.value ?? '',
      flushGroup: flushGroup,
    );
  }
}

class _NoteBox extends ConsumerStatefulWidget {
  const _NoteBox({
    required this.hash,
    required this.field,
    required this.saved,
    required this.flushGroup,
  });

  final String hash;
  final PluginConfigField field;
  final String saved;
  final PluginConfigFlushGroup? flushGroup;

  @override
  ConsumerState<_NoteBox> createState() => _NoteBoxState();
}

class _NoteBoxState extends ConsumerState<_NoteBox>
    implements PluginConfigFlushable {
  late final TextEditingController _text;
  late final FocusNode _focus;

  // What the database holds for the song, as far as this box knows.
  late String _saved;
  Future<bool>? _saving;
  String? _error;

  // Kept for the save at teardown, when the context can no longer be asked.
  LibraryDatabase? _db;
  AppLocalizations? _l10n;

  int get _maxRunes => widget.field.maxLength ?? pluginConfigMaxText;

  // The box counts characters; the limit is in code points.
  String _clip(String text) => text.runes.length <= _maxRunes
      ? text
      : String.fromCharCodes(text.runes.take(_maxRunes));

  @override
  bool get dirty => _saving != null || _text.text != _saved;

  @override
  Future<bool> flush() => _save();

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.saved);
    _focus = FocusNode()..addListener(_onFocus);
    _saved = widget.saved;
    widget.flushGroup?.register(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _db = ref.read(libraryDatabaseProvider);
    _l10n = context.l10n;
  }

  @override
  void didUpdateWidget(_NoteBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A note written elsewhere shows unless the user is in the middle of one;
    // what this box saved itself comes back the same way and is ignored.
    if (widget.saved != oldWidget.saved &&
        widget.saved != _saved &&
        _saving == null &&
        _text.text == _saved) {
      _saved = widget.saved;
      _text.value = TextEditingValue(
        text: widget.saved,
        selection: TextSelection.collapsed(offset: widget.saved.length),
      );
      widget.flushGroup?.refresh();
    }
  }

  @override
  void dispose() {
    widget.flushGroup?.unregister(this);
    final db = _db;
    final text = _clip(_text.text);
    if (db != null && text != _saved) {
      // A save still running goes first, so the last text always wins.
      final running = _saving ?? Future<bool>.value(true);
      unawaited(
        running.then((_) => _write(db, text)).then((ok) {
          if (!ok) _log.warning('A song note was not saved at teardown');
        }),
      );
    }
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focus.hasFocus) {
      // A box that is being removed is saved by dispose instead.
      Future.microtask(() {
        if (mounted) _save();
      });
    }
  }

  Future<bool> _write(LibraryDatabase db, String text) async {
    try {
      await db.setSongTranslationInstruction(widget.hash, text);
      return true;
    } catch (error, stackTrace) {
      _log.warning('Saving a song note failed', error, stackTrace);
      return false;
    }
  }

  /// Saves the text if it differs from the saved one; true when the box ends
  /// up holding nothing unsaved.
  Future<bool> _save() async {
    final running = _saving;
    if (running != null) {
      await running;
      if (!mounted) return false;
      return _save();
    }
    final text = _clip(_text.text);
    if (text != _text.text) _text.text = text;
    if (text == _saved) return true;
    final db = _db;
    if (db == null) {
      _fail();
      return false;
    }
    final write = _write(db, text);
    _saving = write;
    widget.flushGroup?.refresh();
    final ok = await write;
    _saving = null;
    if (!mounted) return ok;
    if (ok) _saved = text;
    setState(() => _error = ok ? null : _l10n?.pluginConfigSaveFailed);
    widget.flushGroup?.refresh();
    return ok && _text.text == _saved;
  }

  void _fail() => setState(() => _error = context.l10n.pluginConfigSaveFailed);

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: TextField(
            controller: _text,
            focusNode: _focus,
            inputFormatters: [
              LengthLimitingTextInputFormatter(
                _maxRunes,
                maxLengthEnforcement:
                    MaxLengthEnforcement.truncateAfterCompositionEnds,
              ),
            ],
            onChanged: (_) => widget.flushGroup?.refresh(),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              label: Text(context.l10n.translationSongInstruction),
              border: const OutlineInputBorder(),
              errorText: _error,
              errorMaxLines: 3,
              hintText: field.placeholder,
            ),
          ),
        ),
      ],
    );
  }
}
