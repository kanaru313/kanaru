import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http_address_class.dart';

void main() {
  LyricsAddressClass classify(String address) =>
      classifyLyricsAddress(InternetAddress(address));

  void expectAll(LyricsAddressClass expected, List<String> addresses) {
    for (final address in addresses) {
      expect(classify(address), expected, reason: address);
    }
  }

  group('IPv4', () {
    test('public unicast', () {
      expectAll(LyricsAddressClass.public, [
        '1.1.1.1',
        '8.8.8.8',
        '93.184.216.34',
        '100.63.255.255', // just below CGNAT
        '100.128.0.1', // just above CGNAT
        '172.15.255.255', // just below RFC 1918
        '172.32.0.1', // just above RFC 1918
        '169.253.1.1',
        '192.0.1.1', // between 192.0.0/24 and 192.0.2/24
        '192.167.1.1',
        '192.169.1.1',
        '198.17.255.255',
        '198.18.0.1', // fake-ip proxies answer from 198.18.0.0/15
        '198.19.255.255',
        '198.20.0.1',
        '198.51.101.1',
        '203.0.112.1',
        '203.0.114.1',
        '223.255.255.254',
      ]);
    });

    test('local: loopback, RFC 1918, CGNAT, link-local', () {
      expectAll(LyricsAddressClass.local, [
        '127.0.0.1',
        '127.255.255.255',
        '10.0.0.1',
        '10.255.255.255',
        '172.16.0.1',
        '172.31.255.255',
        '192.168.0.1',
        '192.168.255.255',
        '100.64.0.1',
        '100.127.255.255',
        '169.254.0.1',
        '169.254.169.254',
      ]);
    });

    test('refused: this-network, documentation, benchmarking, reserved', () {
      expectAll(LyricsAddressClass.refused, [
        '0.0.0.0',
        '0.1.2.3',
        '192.0.0.1',
        '192.0.2.1',
        '192.88.99.1',
        '198.51.100.7',
        '203.0.113.9',
        '224.0.0.1',
        '239.255.255.250',
        '240.0.0.1',
        '255.255.255.254',
        '255.255.255.255',
      ]);
    });
  });

  group('IPv6', () {
    test('public: global unicast', () {
      expectAll(LyricsAddressClass.public, [
        '2606:4700:4700::1111',
        '2a00:1450:4001:81b::200e',
        '2001:4860:4860::8888',
        '3ff0::1', // next to 3fff::/20, not inside it
        '3fff:1000::1',
        '3ffe::1',
        '2001:200::1', // outside 2001::/23
      ]);
    });

    test('local: loopback, unique-local, link-local, site-local', () {
      expectAll(LyricsAddressClass.local, [
        '::1',
        'fc00::1',
        'fd12:3456:789a::1',
        'fe80::1',
        'febf::1',
        'fec0::1',
      ]);
    });

    test('refused: unspecified, multicast, reserved and transition ranges', () {
      expectAll(LyricsAddressClass.refused, [
        '::',
        '::2',
        '::1:0:0:1',
        'ff02::1',
        'ff00::',
        '2001::1', // Teredo
        '2001:2::1', // benchmarking
        '2001:10::1', // ORCHID
        '2001:db8::1', // documentation
        '2002:c000:204::1', // 6to4
        '3fff::1', // documentation
        '3fff:fff::1',
        '4000::1', // outside 2000::/3
        '8000::1',
        '64:ff9b:1::1', // local-use NAT64: embedded IPv4 offset unknown
      ]);
    });

    test('an IPv4-mapped address is classified by the IPv4 it carries', () {
      expect(classify('::ffff:127.0.0.1'), LyricsAddressClass.local);
      expect(classify('::ffff:10.1.2.3'), LyricsAddressClass.local);
      expect(classify('::ffff:192.168.1.1'), LyricsAddressClass.local);
      expect(classify('::ffff:8.8.8.8'), LyricsAddressClass.public);
      expect(classify('::ffff:0.0.0.0'), LyricsAddressClass.refused);
      expect(classify('::ffff:224.0.0.1'), LyricsAddressClass.refused);
      expect(classify('::ffff:7f00:1'), LyricsAddressClass.local);
    });

    test('a NAT64 address is classified by the IPv4 it carries', () {
      expect(classify('64:ff9b::7f00:1'), LyricsAddressClass.local);
      expect(classify('64:ff9b::a00:1'), LyricsAddressClass.local);
      expect(classify('64:ff9b::808:808'), LyricsAddressClass.public);
      expect(classify('64:ff9b::'), LyricsAddressClass.refused);
    });
  });

  test('bytes of a length that is neither IPv4 nor IPv6 are refused', () {
    expect(classifyAddressBytes([1, 2, 3]), LyricsAddressClass.refused);
    expect(classifyAddressBytes(const []), LyricsAddressClass.refused);
  });

  group('classifyLyricsAddresses', () {
    List<InternetAddress> of(List<String> a) => [
      for (final s in a) InternetAddress(s),
    ];

    test('agreeing answers give their class', () {
      expect(
        classifyLyricsAddresses(of(['8.8.8.8', '2606:4700:4700::1111'])),
        LyricsAddressClass.public,
      );
      expect(
        classifyLyricsAddresses(of(['10.0.0.1', '::1'])),
        LyricsAddressClass.local,
      );
    });

    test('a public and a local answer are mixed', () {
      expect(
        classifyLyricsAddresses(of(['8.8.8.8', '127.0.0.1'])),
        LyricsAddressClass.mixed,
      );
      expect(
        classifyLyricsAddresses(of(['127.0.0.1', '8.8.8.8'])),
        LyricsAddressClass.mixed,
      );
    });

    test('one refused answer refuses the set; an empty set is refused', () {
      expect(
        classifyLyricsAddresses(of(['8.8.8.8', '0.0.0.0'])),
        LyricsAddressClass.refused,
      );
      expect(classifyLyricsAddresses(const []), LyricsAddressClass.refused);
    });
  });

  group('isLocalHostName', () {
    test('local names', () {
      for (final name in [
        'localhost',
        'LOCALHOST',
        'localhost.',
        'foo.localhost',
        'nas.local',
        'Printer.LOCAL',
        'box.lan',
        'router.home.arpa',
        'svc.internal',
        'pc.localdomain',
        'a.b.lan.',
      ]) {
        expect(isLocalHostName(name), isTrue, reason: name);
      }
    });

    test('public-looking names', () {
      for (final name in [
        'example.com',
        'lan.example.com',
        'notlocal',
        'mylan',
        'local.example.org',
        'internal.example.com',
        'xlocalhost',
        '192.168.1.1',
      ]) {
        expect(isLocalHostName(name), isFalse, reason: name);
      }
    });
  });
}
