#!/usr/bin/env bash
# 03-download.sh - download the stock MIUI ROM (source of the proprietary vendor files) and,
# if WITH_GAPPS=true, MindTheGapps. Everything is checked against official checksums.
# Safe to interrupt: running it again resumes.
#   bash scripts/03-download.sh
set -uo pipefail
. "$(dirname "$0")/lib.sh"
init_log 03-download
mkdir -p "$DL_DIR"
ERR=0

log "=== Downloads into $DL_DIR ==="

# --- 1) Stock recovery ROM MIUI 14 Global (about 3.6 GB) ---
f=$DL_DIR/$STOCK_ZIP
if [ -f "$f.ok" ]; then
  log "Stock ROM already downloaded and verified."
else
  for h in $STOCK_MIRRORS; do
    log "Downloading $STOCK_ZIP from $h ..."
    curl -fL -C - --retry 3 --retry-delay 5 -o "$f" "https://$h/$STOCK_VERSION/$STOCK_ZIP" && break
    warn "mirror $h failed, trying the next one"
  done
  log "Verifying MD5 ..."
  if [ "$(md5sum "$f" 2>/dev/null | cut -d' ' -f1)" = "$STOCK_MD5" ]; then
    touch "$f.ok"; log "OK: $STOCK_ZIP"
  else
    log "ERROR: $STOCK_ZIP is incomplete or damaged. Run this script again (it resumes);"
    log "       if it keeps failing, delete the file and try again."
    ERR=1
  fi
fi

# --- 2) MindTheGapps for Android 16 (optional) ---
if is_true "$WITH_GAPPS"; then
  log "Looking up the latest MindTheGapps 16.0.0 arm64 release ..."
  rel=$(curl -fsSL "https://api.github.com/repos/MindTheGapps/16.0.0-arm64/releases/latest")
  url=$(printf '%s' "$rel" | python3 -c 'import json,sys; a=json.load(sys.stdin)["assets"]; print(next(x["browser_download_url"] for x in a if x["name"].endswith(".zip")))' 2>/dev/null)
  sumurl=$(printf '%s' "$rel" | python3 -c 'import json,sys; a=json.load(sys.stdin)["assets"]; print(next(x["browser_download_url"] for x in a if x["name"].endswith(".sha256sum")))' 2>/dev/null)
  if [ -z "$url" ] || [ -z "$sumurl" ]; then
    log "ERROR: could not find the MindTheGapps release on GitHub."; ERR=1
  else
    g=$DL_DIR/$(basename "$url")
    if [ -f "$g.ok" ]; then log "$(basename "$g") already downloaded and verified."
    else
      log "Downloading $(basename "$g") ..."
      curl -fL -C - --retry 3 -o "$g" "$url" && curl -fsSL -o "$g.sha256sum" "$sumurl"
      if [ "$(sha256sum "$g" | cut -d' ' -f1)" = "$(awk '{print $1; exit}' "$g.sha256sum" 2>/dev/null)" ]; then
        touch "$g.ok"; log "OK: $(basename "$g")"
      else log "ERROR: $(basename "$g") checksum mismatch - run again."; ERR=1; fi
    fi
  fi
else
  log "GApps: skipped (WITH_GAPPS=false)."
fi

[ $ERR = 0 ] && log "=== Downloads complete - continue with scripts/04-sync.sh ===" || log "=== Downloads FAILED - see above ==="
exit $ERR
