/// The path of [to] relative to the folder [from], both absolute POSIX paths
/// without `.` or `..` parts (canonical, invariant 1). For example from
/// `/a/b` to `/a/x/c.mp3` gives `../x/c.mp3`.
///
/// Written here instead of using `package:path`, which is not a direct
/// dependency of the app.
String relativePath({required String from, required String to}) {
  List<String> parts(String path) =>
      path.split('/').where((part) => part.isNotEmpty).toList();
  final base = parts(from);
  final target = parts(to);
  var common = 0;
  // The last part of [to] is the file name, never a shared folder.
  while (common < base.length &&
      common < target.length - 1 &&
      base[common] == target[common]) {
    common++;
  }
  return [
    for (var i = common; i < base.length; i++) '..',
    ...target.skip(common),
  ].join('/');
}
