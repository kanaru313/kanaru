/// `m:ss`, or `h:mm:ss` from one hour up.
String formatDuration(Duration duration) {
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  final hours = duration.inHours;
  if (hours == 0) return '${duration.inMinutes}:$seconds';
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
