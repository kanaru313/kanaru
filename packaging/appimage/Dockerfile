# syntax=docker/dockerfile:1
# AppImage image. Stages: debian-base, libmpv-build, app-build, package, export.

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

# Flutter + Rust app build. Nothing from the host (NixOS) build tree is used.
FROM debian-base AS app-build
# make: media_kit_libs_linux builds mimalloc with a plain `make` call.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates clang cmake curl git libgtk-3-dev libstdc++-12-dev make \
      ninja-build pkg-config unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*
# Flutter must be writable by the user that runs it (it writes bin/cache).
RUN useradd --create-home --uid 1000 builder \
 && install -d -o builder -g builder /opt/flutter /src
USER builder
ENV PATH=/opt/flutter/bin:/home/builder/.cargo/bin:$PATH
WORKDIR /home/builder

ARG FLUTTER_VERSION=3.47.4
ARG FLUTTER_SHA256=5b45f0ceda99b9bebdc873e7e69f6450aeb4c30f454b505e2e62fc9255a907d3
# Same engine as the Nix dev shell, so the app behaves like the one developed against.
ARG ENGINE_REVISION=06a2e2a110089dff50fe635cffd2a61e1b24fbcd
RUN curl -fsSL --retry 3 -o flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
 && echo "${FLUTTER_SHA256}  flutter.tar.xz" | sha256sum -c - \
 && tar -xJf flutter.tar.xz -C /opt \
 && rm flutter.tar.xz
# (Not named FLUTTER_ENGINE: the flutter tool reads that variable as a local engine path.)
RUN git config --global --add safe.directory /opt/flutter \
 && flutter config --no-analytics --enable-linux-desktop \
 && flutter precache --linux \
 && test "$(cat /opt/flutter/bin/internal/engine.version)" = "${ENGINE_REVISION}"

# cargokit only accepts channel names, so the toolchain floats on `stable`
# (crate MSRV is 1.89); the layer stays cached until this file changes.
ARG RUSTUP_VERSION=1.29.2
ARG RUSTUP_SHA256=5be191e8c70a5007074254cb74d78dbfdd25cd5a61c27de7b8e5410122ec24f4
RUN curl -fsSL --retry 3 -o rustup-init \
      "https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/x86_64-unknown-linux-gnu/rustup-init" \
 && echo "${RUSTUP_SHA256}  rustup-init" | sha256sum -c - \
 && chmod +x rustup-init \
 && ./rustup-init -y --profile minimal --default-toolchain stable \
 && rm rustup-init \
 && rustc --version && cargo --version

ARG KANARU_VERSION
# Only what the app build reads, so edits under packaging/ never rebuild the app.
COPY --chown=builder:builder pubspec.yaml pubspec.lock analysis_options.yaml build.yaml cargokit_options.yaml flutter_rust_bridge.yaml l10n.yaml .metadata /src/
COPY --chown=builder:builder rust_builder /src/rust_builder
COPY --chown=builder:builder rust /src/rust
COPY --chown=builder:builder linux /src/linux
COPY --chown=builder:builder lib /src/lib
WORKDIR /src
RUN --mount=type=cache,target=/home/builder/.pub-cache,uid=1000,gid=1000 \
    --mount=type=cache,target=/home/builder/.cargo/registry,uid=1000,gid=1000 \
    test -n "${KANARU_VERSION}" \
 && flutter pub get --enforce-lockfile \
 && flutter build linux --release --dart-define=KANARU_VERSION="${KANARU_VERSION}"

# AppDir assembly and appimagetool.
FROM debian-base AS package
# libass9 is bundled; libasound2 and libpulse0 only let ldd resolve libmpv here
# (they stay host-provided).
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      appstream binutils ca-certificates curl desktop-file-utils file patchelf \
      libass9 libasound2 libpulse0 \
 && rm -rf /var/lib/apt/lists/*
ARG APPIMAGETOOL_TAG=1.9.1
ARG APPIMAGETOOL_SHA256=ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0
ARG RUNTIME_TAG=20251108
ARG RUNTIME_SHA256=2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d
RUN install -d /opt/tools \
 && fetch() { curl -fsSL --retry 3 -o "/opt/tools/$1" "$2" && echo "$3  /opt/tools/$1" | sha256sum -c - && chmod +x "/opt/tools/$1"; } \
 && fetch appimagetool "https://github.com/AppImage/appimagetool/releases/download/${APPIMAGETOOL_TAG}/appimagetool-x86_64.AppImage" "${APPIMAGETOOL_SHA256}" \
 && fetch runtime-x86_64 "https://github.com/AppImage/type2-runtime/releases/download/${RUNTIME_TAG}/runtime-x86_64" "${RUNTIME_SHA256}"
ENV PATH=/opt/tools:$PATH
COPY --from=app-build /src/build/linux/x64/release/bundle /bundle
COPY --from=libmpv-build /opt/libmpv /opt/libmpv
COPY packaging /packaging
COPY LICENSE /packaging/LICENSE
ARG KANARU_VERSION
ARG SOURCE_DATE_EPOCH
RUN test -n "${KANARU_VERSION}" && test -n "${SOURCE_DATE_EPOCH}" \
 && KANARU_VERSION="${KANARU_VERSION}" SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH}" \
    /packaging/appimage/assemble-appdir.sh

FROM scratch AS export
COPY --from=package /out/ /
