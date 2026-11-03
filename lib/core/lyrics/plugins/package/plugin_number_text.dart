/// Parses plain decimal number text, the one grammar used by manifests and
/// forms: an optional leading `-`, one or more ASCII digits, an optional `.`
/// with one or more digits, and an optional `e`/`E` with an optional sign and
/// one or more digits. No `+5`, `.5`, `5.`, hex, spaces, `Infinity` or `NaN`.
///
/// Returns null when [text] does not fit or the value is not finite. With
/// [whole] the result is an int and a fraction or exponent form that `int`
/// cannot read (`1.5`, `1e3`) is refused.
num? parsePluginNumberText(String text, {bool whole = false}) {
  if (!_fitsGrammar(text)) return null;
  final value = whole ? int.tryParse(text) : num.tryParse(text);
  return value != null && value.isFinite ? value : null;
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

// Linear character scan; no backtracking.
bool _fitsGrammar(String text) {
  var i = 0;
  final n = text.length;
  if (i < n && text.codeUnitAt(i) == 0x2d) i++;
  int digits() {
    final start = i;
    while (i < n && _isDigit(text.codeUnitAt(i))) {
      i++;
    }
    return i - start;
  }

  if (digits() == 0) return false;
  if (i < n && text.codeUnitAt(i) == 0x2e) {
    i++;
    if (digits() == 0) return false;
  }
  if (i < n && (text.codeUnitAt(i) | 0x20) == 0x65) {
    i++;
    if (i < n && (text.codeUnitAt(i) == 0x2b || text.codeUnitAt(i) == 0x2d)) {
      i++;
    }
    if (digits() == 0) return false;
  }
  return i == n;
}
