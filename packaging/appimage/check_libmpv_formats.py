#!/usr/bin/env python3
"""Checks that a libmpv build decodes the given audio files.

Opens each file the way media_kit does (no video, no cover art display), plays it
to the end on the chosen audio output and reports the audio codec libmpv picked.

Usage: check_libmpv_formats.py <libmpv.so path> <ao> <file>...
  e.g. check_libmpv_formats.py /opt/libmpv/lib/libmpv.so.2 null rust/tests/fixtures/sample.*

<ao> is an mpv audio output: `null` for a decode-only check, `pulse` or `alsa`
to also open a real device. Exit status is 1 if any file fails to play to EOF.
Standard library only.
"""
import ctypes
import sys

MPV_EVENT_NONE = 0
MPV_EVENT_END_FILE = 7
MPV_EVENT_FILE_LOADED = 8
END_FILE_EOF = 0
WAIT_SECONDS = 10.0
MAX_IDLE_WAITS = 3  # consecutive quiet waits before a file counts as hung


class MpvEvent(ctypes.Structure):
    _fields_ = [
        ("event_id", ctypes.c_int),
        ("error", ctypes.c_int),
        ("reply_userdata", ctypes.c_uint64),
        ("data", ctypes.c_void_p),
    ]


class MpvEventEndFile(ctypes.Structure):
    _fields_ = [("reason", ctypes.c_int), ("error", ctypes.c_int)]


def load(path):
    lib = ctypes.CDLL(path)
    lib.mpv_create.restype = ctypes.c_void_p
    lib.mpv_initialize.argtypes = [ctypes.c_void_p]
    lib.mpv_set_option_string.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
    lib.mpv_command.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_char_p)]
    lib.mpv_wait_event.argtypes = [ctypes.c_void_p, ctypes.c_double]
    lib.mpv_wait_event.restype = ctypes.POINTER(MpvEvent)
    lib.mpv_get_property_string.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    lib.mpv_get_property_string.restype = ctypes.c_void_p
    lib.mpv_free.argtypes = [ctypes.c_void_p]
    lib.mpv_terminate_destroy.argtypes = [ctypes.c_void_p]
    lib.mpv_error_string.argtypes = [ctypes.c_int]
    lib.mpv_error_string.restype = ctypes.c_char_p
    return lib


def play(lib, ao, path):
    """Returns (codec, error message or None)."""
    handle = lib.mpv_create()
    if not handle:
        return "-", "mpv_create failed"
    codec = "-"
    try:
        for key, value in (("ao", ao), ("vid", "no"), ("audio-display", "no"), ("config", "no")):
            lib.mpv_set_option_string(handle, key.encode(), value.encode())
        status = lib.mpv_initialize(handle)
        if status < 0:
            return codec, "mpv_initialize: " + lib.mpv_error_string(status).decode()
        args = (ctypes.c_char_p * 3)(b"loadfile", path.encode(), None)
        status = lib.mpv_command(handle, args)
        if status < 0:
            return codec, "loadfile: " + lib.mpv_error_string(status).decode()
        idle = 0
        while True:
            event = lib.mpv_wait_event(handle, WAIT_SECONDS).contents
            if event.event_id == MPV_EVENT_NONE:
                idle += 1
                if idle >= MAX_IDLE_WAITS:
                    return codec, "timeout"
                continue
            idle = 0
            if event.event_id == MPV_EVENT_FILE_LOADED:
                raw = lib.mpv_get_property_string(handle, b"audio-codec-name")
                if raw:
                    codec = ctypes.string_at(raw).decode()
                    lib.mpv_free(raw)
            elif event.event_id == MPV_EVENT_END_FILE:
                end = ctypes.cast(event.data, ctypes.POINTER(MpvEventEndFile)).contents
                if end.reason == END_FILE_EOF:
                    return codec, None
                return codec, "end-file reason %d: %s" % (
                    end.reason,
                    lib.mpv_error_string(end.error).decode() if end.error else "unknown",
                )
    finally:
        lib.mpv_terminate_destroy(handle)


def main(argv):
    if len(argv) < 4:
        print(__doc__, file=sys.stderr)
        return 2
    lib = load(argv[1])
    failed = 0
    for path in argv[3:]:
        codec, error = play(lib, argv[2], path)
        print("%s | %s | %s" % (path, codec, "ok" if error is None else "FAIL " + error))
        failed += error is not None
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
