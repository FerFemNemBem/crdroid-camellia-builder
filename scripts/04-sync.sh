#!/usr/bin/env bash
# 04-sync.sh - download (first run) or update the crDroid 16.0 source tree plus the camellia parts.
# Takes 1-3 hours the first time (about 150 GB). Run it inside tmux; it can be interrupted
# and restarted at any time.
#   bash scripts/04-sync.sh                      latest state (default)
#   bash scripts/04-sync.sh --known-good v1.0    exact state of a tagged, tested build
# A sync resets every project to its upstream state; scripts/06-prepare.sh re-applies all patches.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
init_log 04-sync

KG=""
while [ $# -gt 0 ]; do
  case $1 in
    --known-good) KG=${2:-}; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done
if [ -n "$KG" ]; then
  PINNED=$CCB_ROOT/manifests/known-good/$KG.xml
  [ -f "$PINNED" ] || die "No known-good state '$KG'. Available: $(ls "$CCB_ROOT/manifests/known-good" 2>/dev/null | sed 's/\.xml$//' | tr '\n' ' ')"
fi

mkdir -p "$SRC"; cd "$SRC" || exit 1
log "=== Sync crDroid $CRDROID_BRANCH into $SRC ($( [ -n "$KG" ] && echo "known-good $KG" || echo latest)) ==="
if [ ! -d .repo ]; then
  repo init -u https://github.com/crdroidandroid/android.git -b "$CRDROID_BRANCH" \
    --git-lfs --no-clone-bundle --depth=1 || die "repo init failed"
fi
mkdir -p .repo/local_manifests
if [ -n "$KG" ]; then
  # the pinned manifest already contains our projects - the local manifest must not be added again
  rm -f .repo/local_manifests/camellia.xml
  SYNC_ARGS="-m $(printf %q "$PINNED")"
else
  cp "$CCB_ROOT/manifests/crdroid-16.0/camellia.xml" .repo/local_manifests/camellia.xml
  SYNC_ARGS=""
fi

OK=0
for i in 1 2 3 4 5; do
  log "repo sync, attempt $i ..."
  # script(1) keeps repo's progress display and still writes everything to the log
  if script -qefa -c "repo sync $SYNC_ARGS -c -d -j$SYNC_JOBS --no-tags --no-clone-bundle --optimized-fetch --force-sync --force-remove-dirty" "$LOG"; then
    OK=1; break
  fi
  log "attempt $i incomplete (often a temporary rate limit) - waiting 120 s"; sleep 120
done
[ $OK = 1 ] || die "sync failed 5 times - see $LOG"

# the kernel toolchain contains a huge tree that Soong does not need to scan
touch prebuilts/clang/host/linux-x86-r383902/.find-ignore 2>/dev/null
# remember the exact upstream state (before our patches) - copied next to every build
repo manifest -r -o "$SOURCE_STATE" 2>/dev/null && log "source state saved"
if [ -n "$KG" ]; then echo "$KG" > "$KNOWN_GOOD_MARK"; else rm -f "$KNOWN_GOOD_MARK"; fi

log "crDroid version: $(sed -n 's/^CR_VERSION := //p' vendor/lineage/config/version.mk 2>/dev/null)"
log "device tree: $(git -C device/xiaomi/camellia log --oneline -1 2>/dev/null)"
log "size: $(du -sh "$SRC" 2>/dev/null | cut -f1), free: $(df -h "$SRC" | awk 'NR==2{print $4}')"
log "=== Sync done - continue with scripts/05-keys.sh (first time) or scripts/06-prepare.sh ==="
