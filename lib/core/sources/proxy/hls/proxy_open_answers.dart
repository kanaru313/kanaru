import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

import '../proxy_body.dart';
import '../resolved_streams.dart';

/// Install id, status and byte counts only: never a URL, query or token.
final _log = Logger('source_proxy');

/// The streaming answers the proxy has open, per plugin install id, so that
/// dropping a plugin (or closing the proxy) ends them.
class ProxyOpenAnswers {
  final _open = <String, Set<ProxyAnswer>>{};

  /// Ends [owner]'s open answers.
  void abortOwner(String owner) {
    for (final answer in _open.remove(owner)?.toList() ?? const []) {
      answer.abort();
    }
  }

  /// Ends every open answer.
  void abortAll() {
    for (final answers in _open.values) {
      for (final answer in answers.toList()) {
        answer.abort();
      }
    }
    _open.clear();
  }

  /// [answer] as a response; its body is tracked so a drop ends it. [what]
  /// names an HLS sub-resource in the log (empty for progressive). [gone]:
  /// the owner was dropped or the proxy closed while the first chunk was on
  /// its way (404).
  Response respond(
    String owner,
    Playthrough playthrough,
    ProxyAnswer answer,
    String what, {
    required bool gone,
  }) {
    final label = what.isEmpty ? '' : ' $what';
    if (gone) {
      answer.abort();
      return Response(HttpStatus.notFound);
    }
    final body = answer.body;
    if (body == null) {
      _log.info('$owner$label ${answer.status}');
      return Response(answer.status, headers: answer.headers);
    }
    final open = _open.putIfAbsent(owner, () => <ProxyAnswer>{})..add(answer);
    // Keeps the key's playthrough while its body is being sent.
    playthrough.bodyOpened();
    unawaited(
      answer.done.then((sent) {
        open.remove(answer);
        playthrough.bodyClosed();
        _log.fine('$owner$label ${answer.status} sent $sent bytes');
      }),
    );
    return Response(
      answer.status,
      headers: answer.headers,
      body: body,
      context: const {'shelf.io.buffer_output': false},
    );
  }
}
