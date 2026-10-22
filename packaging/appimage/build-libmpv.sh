#!/usr/bin/env bash
# Builds an audio-only, LGPL libmpv for the AppImage into /opt/libmpv:
#   FFmpeg (audio demuxers/decoders only, no network) + static libplacebo + mpv (libmpv only).
# Runs inside the libmpv-build stage of packaging/appimage/Dockerfile (Debian 12).
# Output: /opt/libmpv/lib/*.so*  /opt/libmpv/licenses/  /opt/libmpv/SOURCES.txt
set -euo pipefail

# --- Pins. A checksum or commit mismatch fails the build. -------------------
# FFmpeg release tarball; sha256 computed once and the .asc verified against
# key FCF9 86EA 15E6 E293 A564 4F10 B432 2F04 D676 58D8 (https://ffmpeg.org/ffmpeg-devel.asc).
FFMPEG_VERSION=8.1.3
FFMPEG_SHA256=7138d28c96d9d3e3af4ee3d8cad72741f8ffb40da90c1112235dea3ecd3178a3
# mpv tag and the commit it must resolve to (the tag object itself is not the commit).
MPV_TAG=v0.41.0
MPV_COMMIT=41f6a645068483470267271e1d09966ca3b9f413
# libplacebo tag (mpv 0.41 needs >= 6.338.2) and its commit.
PLACEBO_TAG=v6.338.2
PLACEBO_COMMIT=64c1954570f1cd57f8570a57e51fb0249b57bb90

PREFIX=/opt/libmpv
MESON=/opt/meson/bin/meson
SRC=/tmp/libmpv-src
JOBS="$(nproc)"

export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

# Build options, kept in arrays so SOURCES.txt records exactly what was used.
PLACEBO_OPTS=(
  --prefix="$PREFIX" --libdir=lib --buildtype=release
  -Ddefault_library=static
  -Dvulkan=disabled -Dopengl=disabled -Dd3d11=disabled
  -Dglslang=disabled -Dshaderc=disabled -Dlcms=disabled -Dlibdovi=disabled
  -Dunwind=disabled -Dxxhash=disabled
  -Ddemos=false -Dtests=false -Dbench=false -Dfuzz=false
)
FFMPEG_OPTS=(
  --prefix="$PREFIX" --libdir="$PREFIX/lib"
  --enable-shared --disable-static --enable-small
  --disable-debug --disable-doc --disable-programs
  # --disable-autodetect also switches threads off unless pthreads is explicit.
  --disable-everything --disable-autodetect --enable-pthreads --disable-network
  --disable-avdevice
  --enable-avutil --enable-avcodec --enable-avformat --enable-avfilter
  --enable-swresample --enable-swscale --enable-zlib
  --enable-demuxer=mp3,flac,mov,aac,ogg,wav,aiff,ape,wv,dsf,iff
  --enable-decoder=mp3float,mp3,flac,aac,aac_fixed,alac,vorbis,opus,ape,wavpack,dsd_lsbf,dsd_msbf,dsd_lsbf_planar,dsd_msbf_planar,dst
  '--enable-decoder=pcm*'
  --enable-parser=mpegaudio,flac,aac,vorbis,opus
  --enable-filter=abuffer,abuffersink,aformat,aresample,anull
  --enable-protocol=file
)
MPV_OPTS=(
  --prefix="$PREFIX" --libdir=lib --buildtype=release
  -Dgpl=false -Dlibmpv=true -Dcplayer=false -Dbuild-date=false
  -Dcplugins=disabled -Dmanpage-build=disabled -Dhtml-build=disabled -Dpdf-build=disabled
  -Dlua=disabled -Djavascript=disabled -Dlibarchive=disabled -Dlibavdevice=disabled
  -Dlibbluray=disabled -Ddvdnav=disabled -Ddvbin=disabled -Dcdda=disabled
  -Duchardet=disabled -Drubberband=disabled -Dzimg=disabled -Dlcms2=disabled
  -Djpeg=disabled -Dvapoursynth=disabled -Dsixel=disabled -Dcaca=disabled
  -Dgl=disabled -Degl=disabled -Dplain-gl=disabled -Dvulkan=disabled
  -Dshaderc=disabled -Dspirv-cross=disabled
  -Dx11=disabled -Dwayland=disabled -Ddrm=disabled -Dgbm=disabled -Dxv=disabled
  -Ddmabuf-wayland=disabled -Dvaapi=disabled -Dvdpau=disabled -Dd3d11=disabled
  -Dcuda-hwaccel=disabled -Dcuda-interop=disabled
  -Djack=disabled -Doss-audio=disabled -Dsndio=disabled -Dopenal=disabled -Dsdl2-audio=disabled
  -Dalsa=enabled -Dpulse=enabled -Dpipewire=disabled
  # The static libplacebo contains C++; the C linker does not add libstdc++ on its own.
  -Dc_link_args=-lstdc++
)

mkdir -p "$SRC" "$PREFIX/licenses"
cd "$SRC"

# Shallow-clones a tag and checks the commit it resolves to.
fetch_git() { # <url> <tag> <expected-commit> <dir> [extra clone args...]
  local url=$1 tag=$2 want=$3 dir=$4
  shift 4
  git clone --quiet --depth 1 --branch "$tag" "$@" "$url" "$dir"
  local got
  got="$(git -C "$dir" rev-parse HEAD)"
  if [ "$got" != "$want" ]; then
    echo "commit mismatch for $url $tag: got $got, want $want" >&2
    exit 1
  fi
}

echo "== fetch sources"
curl -fsSL -o ffmpeg.tar.xz "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"
echo "${FFMPEG_SHA256}  ffmpeg.tar.xz" | sha256sum -c -
tar -xf ffmpeg.tar.xz
fetch_git https://github.com/mpv-player/mpv.git "$MPV_TAG" "$MPV_COMMIT" mpv
fetch_git https://code.videolan.org/videolan/libplacebo.git "$PLACEBO_TAG" "$PLACEBO_COMMIT" libplacebo \
  --recursive --shallow-submodules

echo "== libplacebo $PLACEBO_TAG (static)"
"$MESON" setup build-placebo libplacebo "${PLACEBO_OPTS[@]}"
ninja -C build-placebo
"$MESON" install -C build-placebo

echo "== FFmpeg $FFMPEG_VERSION"
mkdir build-ffmpeg
(cd build-ffmpeg && "../ffmpeg-${FFMPEG_VERSION}/configure" "${FFMPEG_OPTS[@]}")
grep -q '#define HAVE_PTHREADS 1' build-ffmpeg/config.h \
  || { echo "FFmpeg was configured without pthreads" >&2; exit 1; }
make -C build-ffmpeg -j"$JOBS"
make -C build-ffmpeg install

echo "== mpv $MPV_TAG (libmpv only)"
"$MESON" setup build-mpv mpv "${MPV_OPTS[@]}"
ninja -C build-mpv
"$MESON" install -C build-mpv

echo "== licenses and source list"
install -d "$PREFIX/licenses/ffmpeg" "$PREFIX/licenses/mpv" "$PREFIX/licenses/libplacebo" "$PREFIX/licenses/libass"
install -m644 "ffmpeg-${FFMPEG_VERSION}/COPYING.LGPLv2.1" "ffmpeg-${FFMPEG_VERSION}/LICENSE.md" "$PREFIX/licenses/ffmpeg/"
install -m644 mpv/LICENSE.LGPL "$PREFIX/licenses/mpv/"
install -m644 libplacebo/LICENSE "$PREFIX/licenses/libplacebo/"
# libass is bundled by a later stage; ship its ISC notice with the other licenses.
install -m644 /usr/share/doc/libass9/copyright "$PREFIX/licenses/libass/copyright"

{
  echo "Kanaru bundled media libraries: sources and build options"
  echo "Rebuild with packaging/appimage/build-libmpv.sh (Debian 12); all components are LGPL-2.1+."
  echo
  echo "FFmpeg ${FFMPEG_VERSION}"
  echo "  url:     https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"
  echo "  sha256:  ${FFMPEG_SHA256}"
  echo "  license: LGPL-2.1+ (no --enable-gpl, --enable-version3 or --enable-nonfree)"
  echo "  configure: ${FFMPEG_OPTS[*]}"
  echo
  echo "mpv ${MPV_TAG}"
  echo "  url:     https://github.com/mpv-player/mpv (tag ${MPV_TAG})"
  echo "  commit:  ${MPV_COMMIT}"
  echo "  license: LGPL-2.1+ (-Dgpl=false)"
  echo "  meson:   ${MPV_OPTS[*]}"
  echo
  echo "libplacebo ${PLACEBO_TAG} (linked statically into libmpv)"
  echo "  url:     https://code.videolan.org/videolan/libplacebo (tag ${PLACEBO_TAG}, with submodules)"
  echo "  commit:  ${PLACEBO_COMMIT}"
  echo "  license: LGPL-2.1+"
  echo "  meson:   ${PLACEBO_OPTS[*]}"
  echo
  echo "libass $(dpkg-query -W -f='${Version}' libass9) (Debian 12 package, ISC license, bundled unmodified)"
  echo "  source:  https://sources.debian.org/src/libass/"
} > "$PREFIX/SOURCES.txt"

echo "== post-process"
cd "$PREFIX"
# Keep only the runtime libraries.
rm -rf include share bin lib/pkgconfig lib/*.a lib/*.la
find lib -type f -name '*.so*' ! -type l | while read -r so; do
  strip --strip-unneeded "$so"
  patchelf --set-rpath '$ORIGIN' "$so"
done
test -e lib/libmpv.so.2 || { echo "libmpv.so.2 missing" >&2; exit 1; }
readelf -d lib/libmpv.so.2 | grep -q 'SONAME.*libmpv.so.2'

rm -rf "$SRC"
echo "libmpv size: $(du -ch "$PREFIX"/lib/*.so* | tail -1)"
