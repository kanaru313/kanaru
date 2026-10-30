// search.js: find records for a song.
//
// input is {title, artist, album, durationMs} for an automatic lookup (a
// missing tag is null) or {text} for the manual search. The app matches the
// results against the song and picks the best, so this script only maps
// LRCLIB's records. It returns at most 20 items:
//   {id, title, artist, album?, durationMs?, lyrics?}
// `lyrics` is optional inline text; LRCLIB sends it with every record, which
// saves a second call to lyrics.js. A record without text (an instrumental
// one, say) is returned without `lyrics` and the app calls lyrics.js for it.
load('common.js');

var MAX_RESULTS = 20;
var MAX_DURATION_SECONDS = 86400;

function execute(input) {
  var queries;
  if (hasText(input.text)) {
    queries = { q: nfc(input.text.trim()) };
  } else if (hasText(input.title)) {
    // LRCLIB matches artist_name against any position of a record's artist
    // string, so it is sent only when the tag names exactly one artist; a tag
    // with several searches by title and the app filters by artist. fetch()
    // skips undefined values.
    var names = artistNames(input.artist);
    queries = {
      track_name: nfc(input.title.trim()),
      artist_name: names.length === 1 ? nfc(names[0]) : undefined,
    };
  } else {
    return Response.success([]); // nothing to search for, nothing to ask
  }

  var got = lrclibGet('/api/search', queries);
  if (got.failure) return got.failure;
  if (!Array.isArray(got.json)) {
    return invalidResponse('search answer is not an array');
  }

  var items = [];
  for (var i = 0; i < got.json.length; i++) {
    var item = toItem(got.json[i]);
    if (item) items.push(item);
  }
  // A non-empty array of nothing usable is a changed format, not "no results".
  if (got.json.length > 0 && items.length === 0) {
    return invalidResponse('no usable record in the search answer');
  }
  return Response.success(items.slice(0, MAX_RESULTS));
}

// One LRCLIB record as a result item, or null when it has the wrong shape.
function toItem(record) {
  if (!record || typeof record !== 'object') return null;
  if (typeof record.id !== 'number' || Math.floor(record.id) !== record.id) {
    return null;
  }
  if (typeof record.trackName !== 'string') return null;
  if (typeof record.artistName !== 'string') return null;

  // Like the Dart provider, a record with an optional field of the wrong
  // type, or a duration that is negative or over a day, is dropped whole.
  var seconds = record.duration;
  var optionalOk =
    isOptional(record.albumName, 'string') &&
    isOptional(record.instrumental, 'boolean') &&
    isOptional(record.syncedLyrics, 'string') &&
    isOptional(record.plainLyrics, 'string') &&
    (seconds == null ||
      (typeof seconds === 'number' &&
        isFinite(seconds) &&
        seconds >= 0 &&
        seconds <= MAX_DURATION_SECONDS));
  if (!optionalOk) return null;

  var item = {
    id: String(record.id),
    title: record.trackName,
    artist: record.artistName,
  };
  if (typeof record.albumName === 'string') item.album = record.albumName;

  // LRCLIB counts seconds (it may have decimals); the app wants milliseconds
  // above 0. A duration of 0 keeps the record and leaves the duration out.
  if (typeof seconds === 'number' && Math.round(seconds * 1000) > 0) {
    item.durationMs = Math.round(seconds * 1000);
  }

  // Synced text wins over plain text; an instrumental record has none.
  if (record.instrumental !== true) {
    if (hasText(record.syncedLyrics)) item.lyrics = record.syncedLyrics;
    else if (hasText(record.plainLyrics)) item.lyrics = record.plainLyrics;
  }
  return item;
}

// Whether value is absent (null or undefined) or of the given typeof.
function isOptional(value, type) {
  return value == null || typeof value === type;
}

// The artist names of a tag, split like the app does (`;`, `/`, " feat. ",
// " ft. ", " featuring ", " with "). Not copied from the Dart provider:
//   - the keep-whole list of names that contain a separator (AC/DC);
//   - bracketed "(feat. X)" parts;
//   - dropping placeholder artists such as "Unknown Artist" (the app never
//     runs a structured search for one);
//   - cleaning titles and albums (control characters, spaces) and dropping a
//     blank title: the app checks plugin results again before it shows or
//     stores them.
function artistNames(tag) {
  if (typeof tag !== 'string') return [];
  var parts = tag.split(/\s*;\s*|\s*\/\s*|\s+(?:feat\.?|ft\.?|featuring|with)\s+/i);
  var names = [];
  for (var i = 0; i < parts.length; i++) {
    var name = parts[i].trim();
    if (name !== '' && names.indexOf(name) < 0) names.push(name);
  }
  return names;
}
