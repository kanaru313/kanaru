# syntax=docker/dockerfile:1
# AppImage image. Stages: debian-base, libmpv-build.

# Debian 12 keeps the glibc floor at 2.36 for everything compiled here.
FROM debian:bookworm-20261020 AS debian-base
ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C.UTF-8

# Audio-only libmpv (mpv + minimal FFmpeg + static libplacebo) in /opt/libmpv.
# Depends only on the script below, so app edits never invalidate this stage.
FROM debian-base AS libmpv-build
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential ca-certificates curl git xz-utils pkgconf ninja-build nasm \
      python3 python3-venv python3-jinja2 python3-mako patchelf \
      libass-dev libasound2-dev libpulse-dev zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*
# mpv needs meson >= 1.3; Debian 12 ships 1.0.1. The wheel hash is pinned like the sources.
RUN python3 -m venv /opt/meson \
 && echo 'meson==1.12.1 --hash=sha256:930bc7542cbd9f57009e182fd014eba48cf1a0180a7b9006d2d32d8f168d8b02' > /tmp/meson.txt \
 && /opt/meson/bin/pip install --no-cache-dir --only-binary=:all: --require-hashes -r /tmp/meson.txt \
 && rm /tmp/meson.txt
COPY packaging/appimage/build-libmpv.sh /tmp/build-libmpv.sh
RUN /tmp/build-libmpv.sh
