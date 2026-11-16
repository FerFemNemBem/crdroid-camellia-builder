#!/usr/bin/env bash
# 07-build.sh - build crDroid for camellia and copy the result to $OUTPUT_DIR/builds/<date-time>/.
# First build: 2-4 hours. Later builds are much faster thanks to ccache. Run it inside tmux.
#   bash scripts/07-build.sh
set -uo pipefail
. "$(dirname "$0")/lib.sh"
init_log 07-build
need_src

RAM=$(free -g | awk '/Mem:/{print $2}')
log "=== Build crDroid for $DEVICE: $(nproc) threads, $RAM GB RAM, $JOBS jobs ==="
if [ "$RAM" -lt "$MIN_RAM_GB" ]; then
  warn "only $RAM GB RAM (MIN_RAM_GB=$MIN_RAM_GB). The build may fail with out-of-memory errors."
  if [ -t 0 ] && [ -z "${CCB_UNATTENDED:-}" ]; then read -rp "Build anyway? (y/N) " a; [ "${a,,}" = y ] || exit 1; fi
fi
[ -f "$KNOWN_GOOD_MARK" ] && log "source tree is pinned to known-good state $(cat "$KNOWN_GOOD_MARK")"

cd "$SRC" || exit 1
# script(1): keep the compact progress display and still log everything
script -qefa -c "source build/envsetup.sh && lunch $LUNCH_TARGET && m bacon -j$JOBS" "$LOG"
RC=$?
OUT=$SRC/out/target/product/$DEVICE
if [ $RC -ne 0 ]; then
  log "BUILD FAILED (exit code $RC). The first error lines:"
  grep -aE "FAILED:|error:" "$LOG" | head -20 | tee -a "$LOG"
  exit $RC
fi

ZIP=$(ls -t "$OUT"/$ZIP_PATTERN 2>/dev/null | head -1)
[ -n "$ZIP" ] || die "build reported success but no ZIP was found in $OUT"
D=$BUILDS_DIR/$(date +%Y%m%d-%H%M); mkdir -p "$D"
cp "$ZIP" "$OUT/boot.img" "$D/"
( cd "$D" && sha256sum -- *.zip boot.img > sha256sums.txt )
git -C "$SRC/device/xiaomi/camellia" log --oneline -8 > "$D/device-tree.txt"
[ -f "$SOURCE_STATE" ] && cp "$SOURCE_STATE" "$D/source-state.xml"
{ echo "builder: $(git -C "$CCB_ROOT" describe --tags --always --dirty 2>/dev/null || echo unknown)"
  echo "known-good: $(cat "$KNOWN_GOOD_MARK" 2>/dev/null || echo no)"
  echo "signing: $SIGNING   viper: $WITH_VIPER   ota: ${OTA_URL:-none}"; } > "$D/build-info.txt"
log "result: $D"
cat "$D/sha256sums.txt" | tee -a "$LOG"
ccache -s 2>/dev/null | grep -iE "hits|size" | tee -a "$LOG"
log "=== Build done - flash it (docs/flash.md) or publish it (scripts/08-publish.sh) ==="
