#!/bin/bash
# Package a built xlinuxfs.app into a distributable .dmg (macOS only).
#
# Usage:
#   bash scripts/package-x86_64.sh <path/to/xlinuxfs.app> [output.dmg]
#
# A .app is a directory, so uploading it raw as a CI artifact makes GitHub
# zip it on download and the extension comes back wrong. A .dmg is a single
# file with a real extension, so the downloaded artifact unzips to a
# mountable image containing the .app.
#
# macOS only: uses `hdiutil`, which does not exist on Linux.
set -euo pipefail

app="${1:?Usage: bash scripts/package-x86_64.sh <path/to/xlinuxfs.app> [output.dmg]}"
out="${2:-xlinuxfs-x86_64.dmg}"

if [[ ! -d "$app" ]]; then
    printf 'FAIL: app not found: %s\n' "$app" >&2
    exit 1
fi

rm -f "$out"
hdiutil create -volname "xlinuxfs" -srcfolder "$app" -ov -format UDZO "$out"
hdiutil verify "$out"
ls -lh "$out"
printf 'PASS: %s\n' "$out"
