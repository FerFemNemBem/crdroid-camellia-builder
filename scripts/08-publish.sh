#!/usr/bin/env bash
# 08-publish.sh - put a finished build on your own OTA server (optional, see docs/ota-server.md).
# Needs OTA_URL and OTA_UPLOAD in config.env.
#   bash scripts/08-publish.sh                 newest build in $OUTPUT_DIR/builds
#   bash scripts/08-publish.sh <build-folder>  a specific build
#   bash scripts/08-publish.sh -n              dry run: only write the JSON, upload nothing
set -euo pipefail
. "$(dirname "$0")/lib.sh"
init_log 08-publish
DRY=0; DIR=
for a in "$@"; do case $a in -n) DRY=1 ;; *) DIR=$a ;; esac; done

[ -n "$OTA_URL" ] || die "OTA_URL is empty in config.env - nothing to publish."
[[ $OTA_URL == */\{device\}.json ]] || die "OTA_URL must end with /{device}.json"
[ $DRY = 1 ] || [ -n "$OTA_UPLOAD" ] || die "OTA_UPLOAD is empty in config.env."
JSON_URL=${OTA_URL//\{device\}/$DEVICE}
BASE_URL=${JSON_URL%/*}
UPLOAD=${OTA_UPLOAD%/}

[ -n "$DIR" ] || DIR=$(ls -d "$BUILDS_DIR"/*/ 2>/dev/null | sort | tail -1)
DIR=${DIR%/}
[ -d "$DIR" ] || die "no build folder found in $BUILDS_DIR"
ZIP=$(ls "$DIR"/$ZIP_PATTERN 2>/dev/null | head -1)
[ -n "$ZIP" ] || die "no crDroid ZIP in $DIR"
NAME=$(basename "$ZIP")
log "=== Publish $NAME ==="

SHA=$(sha256sum "$ZIP" | cut -d' ' -f1)
if [ -f "$DIR/sha256sums.txt" ]; then
  grep -F "$SHA  $NAME" "$DIR/sha256sums.txt" >/dev/null || die "SHA-256 does not match sha256sums.txt - file damaged?"
fi
MD5=$(md5sum "$ZIP" | cut -d' ' -f1)
SIZE=$(stat -c %s "$ZIP")
META=$(python3 -I -c 'import sys,zipfile; print(zipfile.ZipFile(sys.argv[1]).read("META-INF/com/android/metadata").decode())' "$ZIP")
TS=$(sed -n 's/^post-timestamp=//p' <<<"$META")
SPL=$(sed -n 's/^post-security-patch-level=//p' <<<"$META")
SDK=$(sed -n 's/^post-sdk-level=//p' <<<"$META")
[ -n "$TS" ] && [ -n "$SDK" ] || die "timestamp/SDK level missing in the OTA metadata"
VERSION=$(sed -n 's/.*-v\([0-9.]*\)\.zip$/\1/p' <<<"$NAME")
log "version $VERSION, built $(date -d @"$TS" '+%F %T'), security patch $SPL, SDK $SDK, $((SIZE/1024/1024)) MB"

# JSON in the format of the crDroid updater. os_sdk_level is mandatory: without it the updater
# assumes 0 and drops every build as "older Android version".
JSON=$DIR/$DEVICE.json
python3 -I - "$JSON" "$MAINTAINER" "$NAME" "$BASE_URL/$DEVICE/$NAME" "$TS" "$MD5" "$SHA" "$SIZE" "$VERSION" "$SPL" "$SDK" <<'PY'
import json, sys
out, maint, name, url, ts, md5, sha, size, ver, spl, sdk = sys.argv[1:]
d = {"response": [{
  "maintainer": maint, "oem": "Xiaomi", "device": "Redmi Note 10 5G / POCO M3 Pro 5G",
  "filename": name, "download": url, "timestamp": int(ts), "md5": md5, "sha256": sha,
  "size": int(size), "version": ver, "buildtype": "Unofficial",
  "os_patch_level": spl, "os_sdk_level": int(sdk),
  "forum": "", "gapps": "", "firmware": "", "modem": "", "bootloader": "",
  "recovery": "", "paypal": "", "telegram": "", "dt": "", "common-dt": "", "kernel": ""
}]}
open(out, "w").write(json.dumps(d, indent=2) + "\n")
PY
tee -a "$LOG" < "$JSON"
[ $DRY = 1 ] && { log "dry run (-n): nothing uploaded."; exit 0; }

# ZIP first, JSON last - the updater never sees a half uploaded file
log "uploading ZIP to $UPLOAD/$DEVICE/ ..."
rsync -t --partial --progress --chmod=F644,D755 "$ZIP" "$UPLOAD/$DEVICE/"
log "uploading $DEVICE.json ..."
rsync -t --chmod=F644 "$JSON" "$UPLOAD/"

log "checking through the web server ..."
GOT=$(curl -sfI "$BASE_URL/$DEVICE/$NAME" | tr -d '\r' | awk 'tolower($1)=="content-length:"{print $2}')
[ "$GOT" = "$SIZE" ] || die "server delivers ${GOT:-nothing} bytes instead of $SIZE ($BASE_URL/$DEVICE/$NAME)"
curl -sf "$JSON_URL" | grep -F "\"$SHA\"" >/dev/null || die "the JSON on the server does not match ($JSON_URL)"

# keep only the ZIPs of the last OTA_KEEP local builds on the server
MIRROR=$(mktemp -d)
for d in $(ls -d "$BUILDS_DIR"/*/ | sort | tail -n "$OTA_KEEP"); do
  for z in "$d"$ZIP_PATTERN; do if [ -f "$z" ]; then ln -sf "$z" "$MIRROR/"; fi; done
done
ln -sf "$ZIP" "$MIRROR/"   # the published build wins if names collide (same day)
log "cleaning up the server, keeping: $(ls "$MIRROR" | tr '\n' ' ')"
rsync -rtL -v --delete --chmod=F644,D755 "$MIRROR/" "$UPLOAD/$DEVICE/" | grep -E '^deleting' | tee -a "$LOG" || true
rm -rf "$MIRROR"
log "=== Published: $JSON_URL -> $NAME. On the phone: Updater -> check for updates ==="
