import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../player/play_queue.dart';
import '../player/player_service.dart';
import 'translation_scope.dart';
import 'translation_service.dart';

final _log = Logger('translation');

/// Key of the choice in the playback session extras.
const queueTranslationSessionKey = 'translationQueue';

/// The service chosen for the queue playing now, or null. It is saved with
/// the playback session (so it survives a restart) and ends with the queue:
/// see [QueueTranslationChoice]. The app shell keeps it alive, so it sees
/// every queue edit even when Now Playing was never opened.
final queueTranslationChoiceProvider =
    NotifierProvider<QueueTranslationChoice, ScopedTranslationChoice?>(
      QueueTranslationChoice.new,
    );

/// Identifies a queue by its tracks, not by how it is played: the SHA-256 of
/// the track URIs in the order the queue was opened (before any shuffle).
/// Tapping another song of the same album, shuffling, or a shuffled repeat
/// round therefore keep the fingerprint; opening other tracks changes it. Not
/// `hashCode`: it must be equal across app runs.
String queueFingerprint(PlayQueue queue) {
  final bytes = BytesBuilder(copy: false);
  for (final i in queue.unshuffledOrder ?? queue.order) {
    bytes.add(utf8.encode(queue.original[i].uri));
    // A separator no URI holds, so ['ab', 'c'] and ['a', 'bc'] differ.
    bytes.addByte(0);
  }
  return sha256.convert(bytes.takeBytes()).toString();
}

/// Holds the translation service chosen for the whole current queue.
///
/// The choice ends when:
/// * the user opens other tracks (a queue with another fingerprint replaces
///   this one, heard on `PlayerService.replacedQueues`);
/// * the queue becomes empty;
/// * the queue is cleared down to other tracks.
///
/// Adding, removing, moving tracks, play next and shuffling keep it. Known
/// limit: clearing a queue that holds only the playing track keeps the choice,
/// since the queue is the same afterwards.
///
/// The choice is stored in the session extras with the fingerprint of the
/// queue it was made for; a restored choice whose fingerprint does not match
/// the restored queue is dropped.
class QueueTranslationChoice extends Notifier<ScopedTranslationChoice?> {
  // The queue lists the fingerprint was last computed for, by identity.
  (Object, Object, Object?)? _keyedLists;
  String? _queueKey;

  Stream<PlayQueue>? _stream;
  StreamSubscription<PlayQueue>? _subscription;
  bool _disposed = false;

  @override
  ScopedTranslationChoice? build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      unawaited(_subscription?.cancel());
      _subscription = null;
      _stream = null;
    });
    final queue = ref.read(playerServiceProvider).queue;
    final restored = _restore(queue);
    ref.listen(
      playerServiceProvider.select(
        (s) => (s.queue.original, s.queue.order, s.queue.unshuffledOrder),
      ),
      (_, _) => _onQueueEdited(),
    );
    // The player makes a new replaced-queues stream when it rebuilds; any
    // state change is a chance to notice a finished one.
    ref.listen(playerServiceProvider, (_, _) => _listenToReplaced());
    _listenToReplaced();
    return restored;
  }

  /// Makes [service] the choice of the current queue. [tune] is empty when
  /// not given; [chosenAt] is the stamp the newest choice wins by. Nothing
  /// happens while the queue is empty.
  void set(
    TranslationServiceId service, {
    Map<String, String> tune = const {},
    required int chosenAt,
  }) {
    final queue = ref.read(playerServiceProvider).queue;
    if (queue.isEmpty) return;
    final choice = ScopedTranslationChoice(
      service: service,
      tune: Map.unmodifiable(tune),
      chosenAt: chosenAt,
    );
    state = choice;
    _write(choice, _keyFor(queue));
  }

  /// Drops the choice and what the session holds of it.
  void clear() {
    if (state == null) return;
    state = null;
    _queueKey = null;
    _keyedLists = null;
    _player.setSessionExtra(queueTranslationSessionKey, null);
  }

  PlayerService get _player => ref.read(playerServiceProvider.notifier);

  ScopedTranslationChoice? _restore(PlayQueue queue) {
    final raw = _player.restoredSessionExtra(queueTranslationSessionKey);
    if (raw == null) return null;
    final choice = _parse(raw);
    if (choice == null) {
      _log.warning('Dropping a saved queue translation choice: bad shape');
      _player.setSessionExtra(queueTranslationSessionKey, null);
      return null;
    }
    final (parsed, key) = choice;
    if (queue.isEmpty || key != _keyFor(queue)) {
      // The saved queue is not the one restored now.
      _queueKey = null;
      _keyedLists = null;
      _player.setSessionExtra(queueTranslationSessionKey, null);
      return null;
    }
    return parsed;
  }

  /// The queue changed shape: end the choice when nothing is left, else keep
  /// the stored fingerprint in step with the tracks.
  void _onQueueEdited() {
    if (state == null) return;
    final queue = ref.read(playerServiceProvider).queue;
    if (queue.isEmpty) {
      clear();
      return;
    }
    final previous = _queueKey;
    final key = _keyFor(queue);
    if (key != previous) _write(state!, key);
  }

  /// The fingerprint of [queue], recomputed only when its lists are new.
  String _keyFor(PlayQueue queue) {
    final lists = (queue.original, queue.order, queue.unshuffledOrder);
    final cached = _keyedLists;
    final key = _queueKey;
    if (cached != null &&
        key != null &&
        identical(cached.$1, lists.$1) &&
        identical(cached.$2, lists.$2) &&
        identical(cached.$3, lists.$3)) {
      return key;
    }
    final fresh = queueFingerprint(queue);
    _keyedLists = lists;
    _queueKey = fresh;
    return fresh;
  }

  void _write(ScopedTranslationChoice choice, String key) {
    _player.setSessionExtra(queueTranslationSessionKey, {
      'service': choice.service.value,
      'tune': choice.tune,
      'chosenAt': choice.chosenAt,
      'queueKey': key,
    });
  }

  /// Follows `PlayerService.replacedQueues`; a finished stream means the
  /// player rebuilt, so look for the new one (as the queue history does).
  void _listenToReplaced() {
    if (_disposed || _subscription != null) return;
    final Stream<PlayQueue> stream;
    try {
      stream = ref.read(playerServiceProvider.notifier).replacedQueues;
    } catch (error) {
      _log.warning('Not following replaced queues', error);
      return;
    }
    if (stream == _stream) return;
    _stream = stream;
    _subscription = stream.listen(
      _onReplaced,
      onDone: () {
        _subscription = null;
        Timer.run(_listenToReplaced);
      },
    );
  }

  void _onReplaced(PlayQueue previous) {
    if (state == null) return;
    // The queue playing now may be a later replacement than the event's.
    final current = ref.read(playerServiceProvider).queue;
    if (current.isEmpty || queueFingerprint(previous) != _keyFor(current)) {
      clear();
    }
  }

  /// `(choice, queueKey)` from a saved value, or null when it is not the
  /// shape [_write] makes.
  (ScopedTranslationChoice, String)? _parse(Object raw) {
    if (raw is! Map) return null;
    final service = TranslationServiceId.tryParse(raw['service']);
    final chosenAt = raw['chosenAt'];
    final key = raw['queueKey'];
    final tune = raw['tune'];
    if (service == null || chosenAt is! int || key is! String) return null;
    if (tune is! Map) return null;
    final tuneOut = <String, String>{};
    for (final e in tune.entries) {
      final k = e.key;
      final v = e.value;
      if (k is! String || v is! String) return null;
      tuneOut[k] = v;
    }
    return (
      ScopedTranslationChoice(
        service: service,
        tune: Map.unmodifiable(tuneOut),
        chosenAt: chosenAt,
      ),
      key,
    );
  }
}
