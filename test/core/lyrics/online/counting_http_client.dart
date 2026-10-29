import 'dart:io';

/// An [HttpClient] that counts the connections asked for and opens none:
/// `openUrl` fails with a [SocketException], every other member is
/// unsupported.
class CountingHttpClient implements HttpClient {
  int opened = 0;
  bool closed = false;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    opened++;
    return Future.error(const SocketException('counted, not opened'));
  }

  @override
  void close({bool force = false}) => closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
