// Helpers shared by search.js and lyrics.js. A script reaches this file with
// load('common.js'): every file of src/ runs in one global scope.

var LRCLIB = 'https://lrclib.net';

// LRCLIB finds composed (NFC) text only, while some taggers write decomposed
// text, so every value is sent in NFC.
function nfc(text) {
  return typeof text === 'string' ? text.normalize('NFC') : text;
}

// Response.error(...) for a request that went wrong at the HTTP level.
function invalidResponse(why) {
  return Response.error(why, { kind: 'invalidResponse' });
}

// GET LRCLIB + path. Returns exactly one of:
//   { json }      a 200 answer with a JSON body
//   { notFound }  the 404 whose JSON name is "TrackNotFound" (the one answer
//                 LRCLIB documents as "no such record")
//   { failure }   a Response.error to return from execute()
// Only these answers are trusted: a captive portal's HTML 404, say, is a
// failure and never a reason to remember "no lyrics".
function lrclibGet(path, queries) {
  // A failed fetch (network, blocked host, ...) throws. Not catching it is
  // right: the app records the failure and the song is asked again later.
  var res = fetch(LRCLIB + path, { queries: queries });

  if (res.status === 429 || res.status === 503) {
    // Retry-After as whole seconds; any other form (an HTTP date) is
    // ignored, like the app's own reading of the header.
    var header = (res.header('retry-after') || '').trim();
    return {
      failure: Response.error('LRCLIB asked to slow down', {
        kind: 'rateLimited',
        retryAfterSec: /^\d+$/.test(header) ? parseInt(header, 10) : undefined,
      }),
    };
  }
  if (res.status !== 200 && res.status !== 404) {
    return { failure: Response.error('HTTP ' + res.status, { kind: 'server' }) };
  }
  var type = (res.header('content-type') || '').toLowerCase();
  if (type.indexOf('application/json') !== 0) {
    return { failure: invalidResponse('the answer is not JSON') };
  }
  var json;
  try {
    json = res.json();
  } catch (e) {
    return { failure: invalidResponse('the answer is not valid JSON') };
  }
  if (res.status === 404) {
    if (json && json.name === 'TrackNotFound') return { notFound: true };
    return { failure: invalidResponse('an unexpected 404') };
  }
  return { json: json };
}

// Whether a record's optional text is usable lyrics.
function hasText(value) {
  return typeof value === 'string' && value.trim() !== '';
}
