import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/lyrics/plugins/lyrics_plugins_provider.dart';
import '../../../core/lyrics/plugins/package/plugin_manifest.dart';
import '../../../core/lyrics/plugins/store/plugin_config_values.dart';
import '../../../core/lyrics_translation/translation_jobs.dart';
import '../../../l10n/l10n.dart';
import 'plugin_config_flush_group.dart';
import 'plugin_config_payload_checks.dart';
import 'plugin_config_save.dart';
import 'plugin_config_value_messages.dart';

final _log = Logger('lyrics_sources');

/// Saving and checking for the editors of a config field that saves when the
/// user leaves it (text boxes, rows, chips).
///
/// The editor says what it holds ([commitPayload]) and calls [commit] when
/// the user leaves it. The mixin checks the value, keeps the error under the
/// field (shown only once the field was left), saves one value at a time
/// (what is committed meanwhile waits and goes next), does not send the same
/// value twice or one the store refused, and at teardown saves the last edit,
/// best effort.
///
/// An editor in a [PluginConfigFlushGroup] ([commitFlushGroup]) can be asked
/// whether it holds an unsaved edit ([commitDirty]) and to save it and wait
/// ([commitFlush]).
///
/// An empty string is the way to remove a saved value; a list or map that is
/// empty is a value of its own.
mixin PluginConfigCommit<W extends ConsumerStatefulWidget> on ConsumerState<W>
    implements PluginConfigFlushable {
  PluginConfigField get commitField;
  String get commitInstallId;

  /// What the editor holds, typed for the store: a string (empty for none), a
  /// number, a list or a map. Text that does not parse stays a string, so
  /// the value check reports it.
  Object? get commitPayload;

  /// A secret box: empty means "no change", not "remove".
  bool get commitSkipsEmpty => false;

  /// The field already holds a saved value that the editor does not show
  /// (a secret), so empty is not "missing".
  bool get commitHasHiddenValue => false;

  /// Called after [payload] was saved.
  void onCommitted(Object? payload) {}

  /// Choice editors (switch, dropdown, chips) show what the user picked right
  /// away; when the store refuses the latest pick they go back to the last
  /// saved value ([onCommitRefused]) and the reason stays under the field.
  bool get commitRevertsOnRefusal => false;

  /// Called when the latest pick was refused and [commitRevertsOnRefusal] is
  /// set: show [lastSaved] again (a string, number, list or map, as saved).
  void onCommitRefused(Object? lastSaved) {}

  /// Whether a saved value makes the translations that failed for this plugin
  /// start over. Settings does; an editor beside a translation under way
  /// turns it off.
  bool get commitForgetsFailures => true;

  /// The group this editor saves with, or null.
  PluginConfigFlushGroup? get commitFlushGroup => null;

  /// Whether the editor holds something not saved: a save under way or
  /// waiting, or content that differs from the saved value.
  bool get commitDirty =>
      _saving ||
      _queued ||
      (_signature(commitPayload) != _saved &&
          !(commitSkipsEmpty && pluginPayloadIsEmptyText(commitPayload)));

  @override
  bool get dirty => commitDirty;

  @override
  Future<bool> flush() => commitFlush();

  /// Whether the user has left the field; no error shows before.
  bool commitTouched = false;

  /// The message under the field, or null.
  String? commitError;

  String _saved = '';
  // The last saved value the parent passed to [commitExternal].
  String _parentSig = '';
  Object? _savedPayload = '';
  String? _inFlight;
  String? _refused;
  String? _refusedMessage;
  // The value [_refusedMessage] is about; kept even for a retryable refusal.
  String? _failedSig;
  bool _saving = false;
  bool _queued = false;
  Completer<void>? _idle;

  // Kept for the save at teardown, when the context can no longer be asked.
  LyricsPluginsController? _plugins;
  AppLocalizations? _l10n;
  TranslationJobs? _jobs;

  /// Sets the editor's content to [payload] (a string, number, bool, list or
  /// map, as [commitPayload] would give it). Called by [commitExternal] from
  /// `didUpdateWidget`, so no `setState` is needed.
  void onExternalValue(Object? payload) {}

  /// Call from `didUpdateWidget` with the saved payload the parent now passes.
  /// What this editor saved itself comes back the same way (the stored values
  /// are live) and is ignored: while a save runs or waits, and when the value
  /// is the one already saved, so a save never rebuilds or resets its editor.
  /// Any other value was written elsewhere: it becomes the saved value and the
  /// editor shows it.
  void commitExternal(Object? payload) {
    final sig = _signature(payload);
    // The parent also rebuilds with the same value (a reload in between):
    // only a value that differs from the last one it passed is news.
    if (sig == _parentSig) return;
    _parentSig = sig;
    if (sig == _saved || sig == _inFlight || _saving || _queued) return;
    // A cleared value is removed from the store, and the parent then passes
    // the field's default: the same state, shown as the empty box and its hint.
    if (_saved == _signature('') &&
        sig == _signature(commitField.defaultValue)) {
      return;
    }
    _saved = sig;
    _savedPayload = payload;
    _refused = null;
    _failedSig = null;
    commitError = null;
    onExternalValue(payload);
    // The group's listeners must not be told in the middle of a build.
    scheduleMicrotask(() => commitFlushGroup?.refresh());
  }

  /// Tells the mixin what is already saved; call from `initState`.
  void commitStart(Object? saved) {
    _saved = _signature(saved);
    _parentSig = _saved;
    _savedPayload = saved;
    commitFlushGroup?.register(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _plugins = ref.read(lyricsPluginsControllerProvider);
    _l10n = context.l10n;
    _jobs = ref.read(translationJobsProvider.notifier);
  }

  static String _signature(Object? payload) => pluginPayloadSignature(payload);

  /// Extra rules of an editor, checked before the field's own; null if none.
  String? commitProblem(AppLocalizations l10n, Object? payload) => null;

  /// A message that stops [payload] from being saved, or null.
  String? _blocking(AppLocalizations l10n, Object? payload) {
    if (pluginPayloadIsEmptyText(payload)) return null;
    if (pluginPayloadHasNonFinite(payload)) {
      return l10n.pluginConfigNumberInvalid;
    }
    if (pluginPayloadIsEmptyCollection(payload) && commitField.required) {
      return l10n.pluginConfigRequired;
    }
    final own = commitProblem(l10n, payload);
    if (own != null) return own;
    final problem = pluginValueProblem(commitField, payload);
    return problem == null
        ? null
        : pluginValueProblemMessage(l10n, commitField, problem);
  }

  String? _display(AppLocalizations l10n, Object? payload) {
    if (!commitTouched) return null;
    final blocking = _blocking(l10n, payload);
    if (blocking != null) return blocking;
    if (pluginPayloadIsEmptyText(payload) &&
        commitField.required &&
        !commitHasHiddenValue) {
      return l10n.pluginConfigRequired;
    }
    return _signature(payload) == _failedSig ? _refusedMessage : null;
  }

  /// Re-checks the content after an edit; only once the field was left does
  /// this show or clear the error.
  void commitChanged() {
    commitFlushGroup?.refresh();
    if (!commitTouched || !mounted) return;
    setState(() => commitError = _display(context.l10n, commitPayload));
  }

  bool _worthSaving(Object? payload) {
    final sig = _signature(payload);
    return sig != _saved &&
        sig != _inFlight &&
        sig != _refused &&
        !(commitSkipsEmpty && pluginPayloadIsEmptyText(payload));
  }

  /// For a focus listener: the field was left. The commit waits a microtask,
  /// so a field that loses focus because its page is closing (nothing left
  /// to draw into) is not committed; [commitTeardown] saves it instead.
  void commitOnBlur() => scheduleMicrotask(() {
    if (mounted) commit();
  });

  /// The user left the field (or pressed Enter, or toggled a chip): check the
  /// value, then save it if it is new.
  Future<void> commit() async {
    if (!mounted) return;
    commitTouched = true;
    final l10n = context.l10n;
    final payload = commitPayload;
    setState(() => commitError = _display(l10n, payload));
    commitFlushGroup?.refresh();
    if (_blocking(l10n, payload) != null) return;
    if (_saving) {
      _queued = true;
      return;
    }
    if (!_worthSaving(payload)) return;
    final sig = _signature(payload);
    _saving = true;
    _inFlight = sig;
    commitFlushGroup?.refresh();
    final PluginConfigSaveResult result;
    try {
      result = await savePluginConfigValue(
        context,
        ref,
        commitInstallId,
        commitField.key,
        payload,
        forgetFailures: commitForgetsFailures,
      );
    } finally {
      _saving = false;
      _inFlight = null;
    }
    if (!mounted) {
      // Nothing waits for a save of an editor that is gone.
      _queued = false;
      _signalIdle();
      return;
    }
    final message = result.message;
    // A refusal that may pass later is not remembered: the same value can be
    // sent again. Choice editors never remember one: a queued pick of the
    // same value must be sent again so its own refusal reverts the display.
    _refused = message == null || result.retryable || commitRevertsOnRefusal
        ? null
        : sig;
    _refusedMessage = message;
    _failedSig = message == null ? null : sig;
    if (message == null) {
      _saved = commitSkipsEmpty ? _signature('') : sig;
      _savedPayload = commitSkipsEmpty ? '' : payload;
      onCommitted(payload);
    }
    // A newer pick is waiting: it replaces this one, nothing to take back.
    final revert = message != null && commitRevertsOnRefusal && !_queued;
    if (revert) {
      // The same pick may be tried again later.
      _refused = null;
      _failedSig = null;
    }
    if (mounted) {
      setState(() {
        if (revert) onCommitRefused(_savedPayload);
        commitError = revert ? message : _display(context.l10n, commitPayload);
      });
    }
    if (_queued) {
      _queued = false;
      unawaited(commit());
    }
    commitFlushGroup?.refresh();
    _signalIdle();
  }

  // Wakes [commitFlush] once no save is under way or waiting.
  void _signalIdle() {
    if (_saving || _queued) return;
    final idle = _idle;
    _idle = null;
    if (idle != null && !idle.isCompleted) idle.complete();
  }

  /// Saves what the editor holds now and waits until that save, and any save
  /// queued behind it, is done. True when the editor holds nothing unsaved
  /// and shows no error; false when the value was refused, is invalid, or the
  /// editor is gone. The caller bounds the wait (a hung keyring never ends it).
  Future<bool> commitFlush() async {
    if (!mounted) return false;
    await commit();
    while (mounted && (_saving || _queued)) {
      await (_idle ??= Completer<void>()).future;
    }
    if (!mounted) return false;
    final payload = commitPayload;
    final saved =
        _signature(payload) == _saved ||
        (commitSkipsEmpty && pluginPayloadIsEmptyText(payload));
    return commitError == null && saved;
  }

  /// Call from `dispose` before the editor's controllers are disposed:
  /// leaving the page with the field still focused does not blur it, so the
  /// last edit is saved here. A refusal is only logged.
  void commitTeardown() {
    commitFlushGroup?.unregister(this);
    _queued = false;
    _signalIdle();
    final plugins = _plugins;
    final l10n = _l10n;
    if (plugins == null || l10n == null) return;
    final payload = commitPayload;
    if (!_worthSaving(payload) || _blocking(l10n, payload) != null) return;
    unawaited(
      savePluginConfigValueWith(
        controller: plugins,
        l10n: l10n,
        installId: commitInstallId,
        key: commitField.key,
        value: payload,
        onSaved: _jobs == null || !commitForgetsFailures
            ? null
            : () => forgetTranslationFailures(_jobs!, commitInstallId),
      ).then((result) {
        if (!result.saved) {
          _log.warning('A plugin setting was not saved at teardown');
        }
      }),
    );
  }
}
