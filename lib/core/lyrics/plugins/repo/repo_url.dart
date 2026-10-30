/// The one spelling of a repository address that identifies it: lower-case
/// scheme and host, no default port, no fragment. The path stays as typed
/// (a server may tell `/catalog` from `/catalog/`), except that a bare root
/// `/` is dropped: the request for it is the same. Returns
/// null when [input] is not an absolute `http` or `https` URL with a host.
/// User info is kept so the address rules can refuse it.
String? normalizeRepoUrl(String input) {
  final parsed = Uri.tryParse(input.trim());
  if (parsed == null || !parsed.hasAuthority || parsed.host.isEmpty) {
    return null;
  }
  final scheme = parsed.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  final defaultPort = scheme == 'http' ? 80 : 443;
  final path = parsed.path == '/' ? '' : parsed.path;
  final normalized = Uri(
    scheme: scheme,
    userInfo: parsed.userInfo,
    host: parsed.host.toLowerCase(),
    port: parsed.hasPort && parsed.port != defaultPort ? parsed.port : null,
    path: path,
    query: parsed.hasQuery ? parsed.query : null,
  );
  return normalized.toString();
}
