import 'dart:async';
import 'dart:io';

const testCertPath = 'test/core/lyrics/plugins/repo/fixtures/test_cert.pem';
const testKeyPath = 'test/core/lyrics/plugins/repo/fixtures/test_key.pem';

/// A public address (documentation ranges are refused, so a real one) that
/// tests never connect to: a test dialer sends the connection to a loopback
/// server instead.
const fakePublicIp = '93.184.216.34';

/// A security context that trusts only the test certificate.
SecurityContext trustingTestCert() =>
    SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates(testCertPath);

/// A loopback HTTP or HTTPS server whose handler is replaced per test.
class TestServer {
  TestServer._(this.server, this.secure);

  final HttpServer server;
  final bool secure;
  final requests = <HttpRequest>[];
  final hosts = <String?>[];
  final userAgents = <String?>[];
  FutureOr<void> Function(HttpRequest request) handler = (r) async {
    r.response.statusCode = 404;
    await r.response.close();
  };

  int get port => server.port;

  static Future<TestServer> start({bool secure = false}) async {
    final HttpServer server;
    if (secure) {
      final context = SecurityContext()
        ..useCertificateChain(testCertPath)
        ..usePrivateKey(testKeyPath);
      server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
    } else {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    }
    final test = TestServer._(server, secure);
    server.listen((request) async {
      test.requests.add(request);
      test.hosts.add(request.headers.value(HttpHeaders.hostHeader));
      test.userAgents.add(request.headers.value(HttpHeaders.userAgentHeader));
      try {
        await test.handler(request);
      } on Object {
        // The client went away mid-answer (a cap was hit): fine.
      }
    }, onError: (_) {});
    return test;
  }

  Future<void> close() => server.close(force: true);
}

/// Sends every connection of a test to [server], recording what the code
/// under test asked to reach.
class RecordingDialer {
  RecordingDialer(this.server);

  final TestServer server;
  final dialed = <InternetAddress>[];

  Future<ConnectionTask<Socket>> call(InternetAddress address, int port) {
    dialed.add(address);
    return Socket.startConnect(InternetAddress.loopbackIPv4, server.port);
  }
}

/// A resolver backed by a map; unknown names fail like a missing DNS entry.
class FakeResolver {
  FakeResolver(this.answers);

  /// Each lookup of a name takes the next list; the last one repeats.
  final Map<String, List<List<String>>> answers;
  final lookups = <String>[];

  Future<List<InternetAddress>> call(String host) async {
    lookups.add(host);
    final queue = answers[host];
    if (queue == null) throw SocketException('no such host: $host');
    final answer = queue.length > 1 ? queue.removeAt(0) : queue.first;
    return [for (final a in answer) InternetAddress(a)];
  }
}
