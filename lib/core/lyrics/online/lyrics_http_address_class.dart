import 'dart:io';

/// Where an address leads. Decided on the numeric address a name resolved to,
/// never on the name alone.
enum LyricsAddressClass {
  /// Globally routable unicast: the part of the address space that is neither
  /// reserved nor private (the IANA special-purpose registries, inverted).
  public,

  /// The user's own machine or network: loopback, RFC 1918, CGNAT
  /// (`100.64.0.0/10`), link-local (`169.254.0.0/16`, `fe80::/10`) and
  /// unique-local (`fc00::/7`), plus deprecated site-local (`fec0::/10`).
  local,

  /// Never a valid destination: `0.0.0.0/8`, `::`, multicast, broadcast and
  /// the reserved, documentation and transition ranges. (`198.18.0.0/15` is
  /// public: fake-ip proxies use it.)
  refused,

  /// Only for a set of addresses ([classifyLyricsAddresses]): the answers do
  /// not agree. Never returned for a single address.
  mixed,
}

/// Classifies one [address]. An IPv4-mapped IPv6 address (`::ffff:0:0/96`)
/// and a NAT64 address (`64:ff9b::/96`) are classified by the IPv4 address
/// they carry, so `::ffff:127.0.0.1` is loopback and not "some IPv6".
LyricsAddressClass classifyLyricsAddress(InternetAddress address) =>
    classifyAddressBytes(address.rawAddress);

/// The class of [bytes], 4 (IPv4) or 16 (IPv6) long; anything else is refused.
LyricsAddressClass classifyAddressBytes(List<int> bytes) {
  if (bytes.length == 4) return _classifyV4(bytes);
  if (bytes.length != 16) return LyricsAddressClass.refused;
  return _classifyV6(bytes);
}

/// The class shared by every address of [addresses]: the class itself when
/// they all agree, [LyricsAddressClass.mixed] when they do not, and
/// [LyricsAddressClass.refused] when any one is refused or the list is empty.
/// A name that answers with both a public and a local address is therefore
/// never accepted as either.
LyricsAddressClass classifyLyricsAddresses(
  Iterable<InternetAddress> addresses,
) {
  LyricsAddressClass? shared;
  for (final address in addresses) {
    final found = classifyLyricsAddress(address);
    if (found == LyricsAddressClass.refused) return LyricsAddressClass.refused;
    if (shared != null && shared != found) return LyricsAddressClass.mixed;
    shared = found;
  }
  return shared ?? LyricsAddressClass.refused;
}

const _local = LyricsAddressClass.local;
const _public = LyricsAddressClass.public;
const _refused = LyricsAddressClass.refused;

LyricsAddressClass _classifyV4(List<int> b) {
  final a = b[0];
  final second = b[1];
  final third = b[2];
  if (a == 0) return _refused; // "this network"
  if (a == 10) return _local;
  if (a == 100 && (second & 0xC0) == 64) return _local; // CGNAT
  if (a == 127) return _local;
  if (a == 169 && second == 254) return _local;
  if (a == 172 && (second & 0xF0) == 16) return _local;
  if (a == 192) {
    if (second == 168) return _local;
    if (second == 0 && (third == 0 || third == 2)) return _refused;
    if (second == 88 && third == 99) return _refused; // 6to4 relay anycast
  }
  if (a == 198) {
    // 198.18.0.0/15 is the benchmarking block, but fake-ip proxies (Clash,
    // mihomo, sing-box in TUN mode) answer every DNS query from it and route
    // the connection to the real host. Refusing it would break every public
    // destination for those users, and the block holds no real services.
    if (second == 51 && third == 100) return _refused; // documentation
  }
  if (a == 203 && second == 0 && third == 113) return _refused;
  // 224/4 multicast, 240/4 reserved and 255.255.255.255 broadcast.
  if (a >= 224) return _refused;
  return _public;
}

LyricsAddressClass _classifyV6(List<int> b) {
  final leadingZero = b.take(10).every((v) => v == 0);
  // ::ffff:a.b.c.d
  if (leadingZero && b[10] == 0xff && b[11] == 0xff) {
    return _classifyV4(b.sublist(12));
  }
  // 64:ff9b::a.b.c.d
  if (b[0] == 0 &&
      b[1] == 0x64 &&
      b[2] == 0xff &&
      b[3] == 0x9b &&
      b.sublist(4, 12).every((v) => v == 0)) {
    return _classifyV4(b.sublist(12));
  }
  if (b.sublist(0, 15).every((v) => v == 0) && b[15] == 1) return _local;
  // ::, IPv4-compatible and the rest of ::/8. This includes the local-use
  // NAT64 prefix 64:ff9b:1::/48 (RFC 8215): the IPv4 address sits at an
  // offset that depends on the operator's prefix length, so it cannot be
  // read safely and the address is refused.
  if (b[0] == 0) return _refused;
  if (b[0] == 0xff) return _refused; // multicast
  if ((b[0] & 0xFE) == 0xFC) return _local; // fc00::/7
  if (b[0] == 0xfe && (b[1] & 0xC0) == 0x80) return _local; // fe80::/10
  if (b[0] == 0xfe && (b[1] & 0xC0) == 0xC0) return _local; // fec0::/10
  // Only 2000::/3 is global unicast; everything else is not routable.
  if ((b[0] & 0xE0) != 0x20) return _refused;
  // 2001::/23 IETF protocol assignments (Teredo, benchmarking, ORCHID).
  if (b[0] == 0x20 && b[1] == 0x01 && (b[2] & 0xFE) == 0) return _refused;
  // 2001:db8::/32 documentation.
  if (b[0] == 0x20 && b[1] == 0x01 && b[2] == 0x0d && b[3] == 0xb8) {
    return _refused;
  }
  if (b[0] == 0x20 && b[1] == 0x02) return _refused; // 2002::/16 6to4
  // 3fff::/20 documentation.
  if (b[0] == 0x3f && b[1] == 0xff && (b[2] & 0xF0) == 0) return _refused;
  return _public;
}

const _localSuffixes = [
  '.local',
  '.lan',
  '.home.arpa',
  '.internal',
  '.localdomain',
  '.localhost',
];

/// Whether [host] is a name that, by convention, belongs to the user's own
/// network: `localhost` and the `.local`, `.lan`, `.home.arpa`, `.internal`,
/// `.localdomain` and `.localhost` zones. Case and one trailing dot are
/// ignored. A hint only: what the name resolves to decides, and a local name
/// that resolves to a public address is not trusted.
bool isLocalHostName(String host) {
  var name = host.toLowerCase();
  if (name.endsWith('.')) name = name.substring(0, name.length - 1);
  if (name == 'localhost') return true;
  return _localSuffixes.any(name.endsWith);
}
