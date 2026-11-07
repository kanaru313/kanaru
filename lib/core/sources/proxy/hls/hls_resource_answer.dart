import 'dart:io';

import '../../hls/hls_models.dart';
import '../proxy_body.dart';
import '../range_request.dart';
import '../upstream_fetch.dart';
import '../upstream_headers.dart';
import 'hls_proxy_names.dart';
import 'hls_request_failure.dart';
import 'hls_resource_body.dart';

/// The exact size of an `AES-128` key.
const hlsKeyBytes = 16;

/// How long a key body may take, counted from its headers.
const hlsKeyBodyTimeout = Duration(seconds: 15);

/// What one sub-resource is upstream: where it is, which bytes of it, and the
/// most bytes served of it.
typedef HlsTarget = ({Uri uri, HlsByteRange? byteRange, int limit});

/// The answer to the client's [range] of [resource], built from the upstream
/// [response] fetched for [target]: a streaming body over the whole upstream
/// body (a range starting later drops the bytes before it, and needs the
/// size), or, for a key, the key read whole. Throws [UpstreamRefused] or
/// [HlsRequestFailure] for an upstream answer that must not be served; the
/// response is dropped then.
Future<ProxyAnswer> answerHlsResource(
  HlsResource resource,
  HlsTarget target,
  HttpClientResponse response,
  RangeRequest range, {
  required Duration stallTimeout,
  required Duration keyTimeout,
}) async {
  final size = _checkedSize(response, target);
  if (resource.kind == HlsResourceKind.key) {
    return _keyAnswer(resource, response, range, stallTimeout, keyTimeout);
  }
  if (size != null && size > target.limit) {
    discardUpstream(response);
    throw const UpstreamRefused('hls resource too long');
  }
  final ({int start, int end})? span;
  if (size != null) {
    span = range.within(size);
    if (span == null && range.partial) {
      discardUpstream(response);
      return ProxyAnswer.status(HttpStatus.requestedRangeNotSatisfiable, {
        'content-range': 'bytes */$size',
      });
    }
    if (span == null) {
      // No range asked and an empty body.
      discardUpstream(response);
      return ProxyAnswer.status(HttpStatus.ok, {
        'accept-ranges': 'bytes',
        'content-length': '0',
        'content-type': resource.contentType,
      });
    }
  } else if (range is WholeBody || (range is ByteRange && range.start == 0)) {
    // Size unknown: the whole body, cut at the bound. A range that only fits
    // a whole body is answered with it, as HTTP allows.
    span = (start: 0, end: target.limit - 1);
  } else {
    discardUpstream(response);
    throw const UpstreamRefused('hls range needs the size');
  }
  final partial = range.partial && size != null;
  final pump = HlsBodyPump(
    response,
    skip: span.start,
    limit: span.end - span.start + 1,
    stallTimeout: stallTimeout,
  );
  return HlsAnswer(partial ? HttpStatus.partialContent : HttpStatus.ok, {
    if (size != null) 'accept-ranges': 'bytes',
    if (size != null) 'content-length': '${span.end - span.start + 1}',
    if (partial) 'content-range': 'bytes ${span.start}-${span.end}/$size',
    'content-type': resource.contentType,
  }, pump);
}

/// The size of the resource in bytes if [response] tells it (null when it
/// does not), after checking the answer is the one asked for: `200` for a
/// whole resource, `206` with exactly the asked range for a byte range, no
/// content encoding. Throws [UpstreamRefused] for anything else.
int? _checkedSize(HttpClientResponse response, HlsTarget target) {
  final status = response.statusCode;
  final byteRange = target.byteRange;
  final encoding = response.headers.value('content-encoding');
  final encoded = encoding != null && encoding.toLowerCase() != 'identity';
  final ok = byteRange == null
      ? status == HttpStatus.ok
      : status == HttpStatus.partialContent &&
            _isRange(response.headers.value('content-range'), byteRange);
  if (!ok || encoded) {
    discardUpstream(response);
    throw UpstreamRefused('upstream status $status');
  }
  if (byteRange != null) return byteRange.length;
  return response.contentLength >= 0 ? response.contentLength : null;
}

bool _isRange(String? header, HlsByteRange asked) {
  final got = parseContentRange(header);
  return got != null && got.start == asked.offset && got.end == asked.end - 1;
}

/// A key is read whole (it must be exactly [hlsKeyBytes] long) and answered
/// from memory.
Future<ProxyAnswer> _keyAnswer(
  HlsResource resource,
  HttpClientResponse response,
  RangeRequest range,
  Duration stallTimeout,
  Duration keyTimeout,
) async {
  final List<int> key;
  try {
    key = await readUpstreamBody(
      response,
      maxBytes: hlsKeyBytes,
      timeout: keyTimeout,
    );
  } on UpstreamBodyFailure catch (failure) {
    if (failure.kind == UpstreamBodyFailureKind.tooLong) {
      throw const HlsRequestFailure(HlsRequestFailureKind.badKey);
    }
    rethrow;
  }
  if (key.length != hlsKeyBytes) {
    throw const HlsRequestFailure(HlsRequestFailureKind.badKey);
  }
  final span = range.within(key.length);
  if (span == null) {
    return ProxyAnswer.status(HttpStatus.requestedRangeNotSatisfiable, {
      'content-range': 'bytes */${key.length}',
    });
  }
  final pump = HlsBodyPump(
    Stream.value(key),
    skip: span.start,
    limit: span.end - span.start + 1,
    stallTimeout: stallTimeout,
  );
  return HlsAnswer(range.partial ? HttpStatus.partialContent : HttpStatus.ok, {
    'accept-ranges': 'bytes',
    'content-length': '${span.end - span.start + 1}',
    if (range.partial)
      'content-range': 'bytes ${span.start}-${span.end}/${key.length}',
    'content-type': resource.contentType,
  }, pump);
}
