// lyrics.js: the lyrics of one record.
//
// input is the `id` string of a search result. Returns
//   null                        the record has no lyrics
//   {instrumental: true}        the song has no words
//   {data, type: 'lrc'|'txt'}   synced or plain text
load('common.js');

function execute(id) {
  var got = lrclibGet('/api/get/' + encodeURIComponent(String(id)));
  if (got.failure) return got.failure;
  if (got.notFound) return Response.success(null);

  var record = got.json;
  if (!record || typeof record !== 'object') {
    return invalidResponse('the record is not an object');
  }
  if (record.instrumental === true) {
    return Response.success({ instrumental: true });
  }
  if (hasText(record.syncedLyrics)) {
    return Response.success({ data: record.syncedLyrics, type: 'lrc' });
  }
  if (hasText(record.plainLyrics)) {
    return Response.success({ data: record.plainLyrics, type: 'txt' });
  }
  return Response.success(null);
}
