/// Options of the online sources (source plugins that find and stream
/// music).
///
/// Consent is per plugin: a source plugin may send nothing unless its install
/// id is in [noticeAcknowledged].
class OnlineSourcesPrefs {
  const OnlineSourcesPrefs({this.noticeAcknowledged = const {}});

  /// Install ids of the source plugins whose notice the user accepted. At
  /// most 64 are kept.
  final Set<String> noticeAcknowledged;

  /// The user accepted the notice of [installId], so it may send.
  bool allows(String installId) => noticeAcknowledged.contains(installId);

  OnlineSourcesPrefs copyWith({Set<String>? noticeAcknowledged}) =>
      OnlineSourcesPrefs(
        noticeAcknowledged: noticeAcknowledged ?? this.noticeAcknowledged,
      );

  @override
  bool operator ==(Object other) =>
      other is OnlineSourcesPrefs &&
      other.noticeAcknowledged.length == noticeAcknowledged.length &&
      other.noticeAcknowledged.containsAll(noticeAcknowledged);

  @override
  int get hashCode => Object.hashAllUnordered(noticeAcknowledged);

  @override
  String toString() =>
      'OnlineSourcesPrefs(noticeAcknowledged: ${noticeAcknowledged.toList()})';
}
