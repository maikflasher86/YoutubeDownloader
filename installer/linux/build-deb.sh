#!/usr/bin/env bash
# Build a .deb from the Flutter Linux bundle.
# Usage: build-deb.sh <version> <bundle-dir> <output.deb>
set -euo pipefail

version=$1
bundle=$(realpath "$2")
output=$(realpath -m "$3")
here=$(dirname "$(realpath "$0")")
root=$(mktemp -d)
chmod 755 "$root"
trap 'rm -rf "$root"' EXIT

install -d "$root/opt/youtube-downloader" "$root/usr/bin" \
  "$root/usr/share/applications" "$root/usr/share/icons/hicolor/192x192/apps" "$root/DEBIAN"
cp -r "$bundle"/. "$root/opt/youtube-downloader/"
ln -s /opt/youtube-downloader/youtube_downloader "$root/usr/bin/youtube-downloader"
install -m 644 "$here/youtube-downloader.desktop" "$root/usr/share/applications/"
install -m 644 "$here/../../android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" \
  "$root/usr/share/icons/hicolor/192x192/apps/youtube-downloader.png"

cat > "$root/DEBIAN/control" <<EOF
Package: youtube-downloader
Version: $version
Section: video
Priority: optional
Architecture: amd64
Depends: ffmpeg, libgtk-3-0, libjson-glib-1.0-0, libmpv2 | libmpv1
Maintainer: Maik <noreply@users.noreply.github.com>
Description: Youtube Downloader & MP3
 Download YouTube videos as MP4 or MP3.
EOF

dpkg-deb --build --root-owner-group "$root" "$output"
