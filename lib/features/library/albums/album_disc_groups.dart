import '../../../core/database/library_database.dart' show BrowseTrack;

/// The tracks of one disc of an album; [disc] is null for tracks without a
/// disc number.
class DiscGroup {
  const DiscGroup(this.disc, this.tracks);

  final int? disc;
  final List<BrowseTrack> tracks;
}

/// Splits [tracks], already ordered by disc (unknown last), into runs of the
/// same disc number, keeping their order.
List<DiscGroup> groupByDisc(List<BrowseTrack> tracks) {
  final groups = <DiscGroup>[];
  for (final track in tracks) {
    if (groups.isEmpty || groups.last.disc != track.discNo) {
      groups.add(DiscGroup(track.discNo, []));
    }
    groups.last.tracks.add(track);
  }
  return groups;
}
