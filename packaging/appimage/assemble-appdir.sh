#!/usr/bin/env bash
# Assembles AppDir from the Flutter bundle and the libmpv stage, checks it, and
# packs it with appimagetool. Runs in the `package` Docker stage.
#
# Inputs:  /bundle (flutter build linux), /opt/libmpv, /packaging (this repo's
#          packaging/ plus LICENSE), $KANARU_VERSION, $SOURCE_DATE_EPOCH
# Output:  /out/Kanaru-$KANARU_VERSION-x86_64.AppImage
set -euo pipefail

: "${KANARU_VERSION:?}" "${SOURCE_DATE_EPOCH:?}"
APP_ID=io.github.kanaru313.kanaru
APPDIR=/AppDir
OUT=/out
# glibc symbol version the Debian 12 build container provides; nothing may need more.
GLIBC_FLOOR=2.36

fail() { echo "assemble-appdir: $*" >&2; exit 1; }

install -d "$APPDIR/usr/share/applications" "$APPDIR/usr/share/metainfo" \
           "$APPDIR/usr/share/licenses/kanaru" "$OUT"

echo "== Flutter bundle (layout untouched: the exe keeps RUNPATH \$ORIGIN/lib)"
cp -a /bundle/kanaru "$APPDIR/usr/kanaru"
cp -a /bundle/lib /bundle/data "$APPDIR/usr/"

echo "== libmpv set and libass"
# libmpv's own libraries are already stripped and have RUNPATH $ORIGIN (build-libmpv.sh).
# Unversioned development symlinks are not needed at run time (libmpv.so is kept on purpose).
cp -a /opt/libmpv/lib/. "$APPDIR/usr/lib/"
find "$APPDIR/usr/lib" -type l \( -name 'libav*.so' -o -name 'libsw*.so' \) -delete
# libass is the only library libmpv needs that is neither bundled nor common on desktops.
# linuxdeploy was dropped: it bundles the whole ldd closure of the libraries it excludes
# (pulse -> systemd, sndfile, ..., freetype -> png, brotli, ...), about 30 extra libraries.
libass=$(ldd /opt/libmpv/lib/libmpv.so.2 | awk '$1 == "libass.so.9" {print $3}')
[ -n "$libass" ] || fail "libmpv does not link libass.so.9"
cp -L "$libass" "$APPDIR/usr/lib/libass.so.9"
patchelf --set-rpath '$ORIGIN' "$APPDIR/usr/lib/libass.so.9"
# media_kit tries libmpv.so before libmpv.so.2; keep the symlink so a host libmpv.so is never picked.
ln -sf libmpv.so.2 "$APPDIR/usr/lib/libmpv.so"

echo "== desktop entry, metainfo, icons, licenses"
cp "/packaging/linux/$APP_ID.desktop" "$APPDIR/usr/share/applications/"
cp "/packaging/linux/$APP_ID.metainfo.xml" "$APPDIR/usr/share/metainfo/"
cp -r /packaging/linux/icons "$APPDIR/usr/share/"
cp /packaging/LICENSE "$APPDIR/usr/share/licenses/kanaru/LICENSE"
cp -r /opt/libmpv/licenses/. "$APPDIR/usr/share/licenses/"
cp /opt/libmpv/SOURCES.txt "$APPDIR/usr/share/licenses/SOURCES.txt"

echo "== AppDir root"
install -m755 /packaging/appimage/AppRun "$APPDIR/AppRun"
ln -s "usr/share/applications/$APP_ID.desktop" "$APPDIR/$APP_ID.desktop"
ln -s "usr/share/icons/hicolor/256x256/apps/$APP_ID.png" "$APPDIR/$APP_ID.png"
ln -s "$APP_ID.png" "$APPDIR/.DirIcon"

appstreamcli validate --no-net "$APPDIR/usr/share/metainfo/$APP_ID.metainfo.xml"

echo "== checks"
readelf -d "$APPDIR/usr/kanaru" | grep -Eq 'RUNPATH.*\$ORIGIN/lib' \
  || fail "kanaru lost RUNPATH \$ORIGIN/lib"
readelf -d "$APPDIR/usr/lib/libflutter_linux_gtk.so" | grep -Eq 'RUNPATH.*\$ORIGIN' \
  || fail "libflutter_linux_gtk.so lost RUNPATH \$ORIGIN"
# Flutter files must be exactly what flutter build produced.
cmp /bundle/kanaru "$APPDIR/usr/kanaru" || fail "kanaru changed"
for f in /bundle/lib/*; do cmp "$f" "$APPDIR/usr/lib/$(basename "$f")" || fail "$(basename "$f") changed"; done
diff -r /bundle/data "$APPDIR/usr/data" || fail "data changed"
# Host-provided: GTK stack, GLib, libstdc++.
if find "$APPDIR" \( -name 'libgtk-3.so*' -o -name 'libglib-2.0.so*' -o -name 'libstdc++.so*' \) | grep .; then
  fail "host-provided library found in AppDir"
fi
# Exactly the Flutter bundle libs, the libmpv libs and libass; anything else is a dependency leak.
expected=$( { ls /bundle/lib; ls /opt/libmpv/lib | grep -Ev '^lib(av|sw).*\.so$'; echo libass.so.9; } | sort -u )
actual=$(ls "$APPDIR/usr/lib" | sort -u)
if [ "$expected" != "$actual" ]; then
  echo "expected vs actual usr/lib:" >&2
  diff <(echo "$expected") <(echo "$actual") >&2 || true
  fail "usr/lib holds an unexpected set of files"
fi
# Every direct dependency of the libmpv set is in AppDir or one of the host-provided ones.
host_ok='^(libc|libm|libdl|libpthread|librt|libstdc\+\+|libgcc_s|libz|libasound|libpulse|libfontconfig|libfreetype|libharfbuzz|libfribidi)\.so'
for lib in "$APPDIR"/usr/lib/libmpv.so.2 "$APPDIR"/usr/lib/libav*.so.* "$APPDIR"/usr/lib/libsw*.so.* "$APPDIR"/usr/lib/libass.so.9; do
  ldd "$lib" | grep -q 'not found' && fail "ldd: unresolved dependency of $lib"
  for soname in $(readelf -d "$lib" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p'); do
    [ -e "$APPDIR/usr/lib/$soname" ] || echo "$soname" | grep -Eq "$host_ok" \
      || fail "$(basename "$lib") needs $soname, which is neither bundled nor host-provided"
  done
done
# glibc floor: nothing may need a newer symbol version than the build container's.
max=$(find "$APPDIR" -type f \( -name '*.so*' -o -name kanaru \) -exec objdump -T {} + 2>/dev/null \
  | grep -o 'GLIBC_[0-9.]*' | sed 's/GLIBC_//' | sort -uV | tail -n 1)
echo "highest GLIBC symbol version: $max"
[ "$(printf '%s\n%s\n' "$max" "$GLIBC_FLOOR" | sort -V | tail -n 1)" = "$GLIBC_FLOOR" ] \
  || fail "GLIBC_$max exceeds floor $GLIBC_FLOOR"
echo "AppDir size: $(du -sh "$APPDIR" | cut -f1)"

echo "== appimagetool"
VERSION="$KANARU_VERSION" ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 \
  appimagetool --runtime-file /opt/tools/runtime-x86_64 "$APPDIR" "$OUT/Kanaru-$KANARU_VERSION-x86_64.AppImage"
ls -l "$OUT"
