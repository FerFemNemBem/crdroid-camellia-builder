#!/usr/bin/env bash
# 02-check-host.sh - check that this computer is ready to build. Changes nothing.
#   bash scripts/02-check-host.sh
set -uo pipefail
. "$(dirname "$0")/lib.sh"
init_log 02-check-host
ERR=0
ok()   { log "  OK    $*"; }
bad()  { log "  FAIL  $*"; ERR=1; }
hint() { log "  NOTE  $*"; }

log "=== Host check ==="
log "System: $(. /etc/os-release; echo "$PRETTY_NAME"), kernel $(uname -r)$(is_wsl && echo ' (WSL)')"
log "Config: $( [ -f "$CCB_CONFIG" ] && echo "$CCB_CONFIG" || echo 'no config.env - using defaults')"

T=$(nproc); RAM=$(free -g | awk '/Mem:/{print $2}'); SWAP=$(free -g | awk '/Swap:/{print $2}')
[ "$T" -ge 8 ] && ok "$T CPU threads" || bad "$T CPU threads (8+ needed, 16+ recommended)"
if [ "$RAM" -ge 60 ]; then ok "$RAM GB RAM"; elif [ "$RAM" -ge "$MIN_RAM_GB" ]; then hint "$RAM GB RAM - works, 64 GB is faster"
else bad "$RAM GB RAM (at least $MIN_RAM_GB GB; on WSL raise 'memory=' in .wslconfig)"; fi
[ "$SWAP" -ge 8 ] && ok "$SWAP GB swap" || hint "$SWAP GB swap - 16 GB recommended"

mkdir -p "$WORK_DIR" "$OUTPUT_DIR" 2>/dev/null
if is_wsl && [[ $(realpath -m "$WORK_DIR") == /mnt/* ]]; then
  bad "WORK_DIR=$WORK_DIR is on a Windows drive - this is extremely slow and breaks the build. Use a path in \$HOME."
fi
free_gb() { df -BG --output=avail "$1" 2>/dev/null | tail -1 | tr -dc 0-9; }
F=$(free_gb "$WORK_DIR"); [ "${F:-0}" -ge 300 ] && ok "$F GB free for WORK_DIR ($WORK_DIR)" || \
  { [ -d "$SRC/.repo" ] && hint "$F GB free for WORK_DIR (tree already exists)" || bad "${F:-?} GB free for WORK_DIR ($WORK_DIR), 300 GB needed"; }
F=$(free_gb "$OUTPUT_DIR"); [ "${F:-0}" -ge 15 ] && ok "$F GB free for OUTPUT_DIR ($OUTPUT_DIR)" || bad "${F:-?} GB free for OUTPUT_DIR ($OUTPUT_DIR), 15 GB needed"

for t in repo git git-lfs ccache python3 make zip unzip lz4 xxd openssl rsync curl gpg tmux; do
  command -v "$t" >/dev/null && ok "tool $t" || bad "tool $t missing - run scripts/01-setup-host.sh"
done
[ -n "$(git config --global user.name)" ] && ok "git identity set" || bad "git identity missing - run scripts/01-setup-host.sh"
ccache -s >/dev/null 2>&1 && ok "ccache ($CCACHE_DIR, max $(ccache -k max_size 2>/dev/null))" || bad "ccache not working"

for u in https://android.googlesource.com https://github.com https://raw.githubusercontent.com; do
  c=$(curl -s -o /dev/null -m 15 -w '%{http_code}' "$u"); [[ $c =~ ^[23] ]] && ok "reach $u" || bad "cannot reach $u (HTTP $c)"
done

[ "$SIGNING" = test ] && hint "SIGNING=test: public test keys. For daily use / OTA set SIGNING=own BEFORE the first installation (docs/signing.md)"
log "--- settings ---"
log "  WORK_DIR=$WORK_DIR  OUTPUT_DIR=$OUTPUT_DIR  JOBS=$JOBS  SYNC_JOBS=$SYNC_JOBS"
log "  SIGNING=$SIGNING  WITH_VIPER=$WITH_VIPER  WITH_GAPPS=$WITH_GAPPS  WIDEVINE_L3=$WIDEVINE_L3  HOTSPOT_REPEATER=$HOTSPOT_REPEATER  OTA_URL=${OTA_URL:-(none)}"
if [ $ERR = 0 ]; then log "=== All checks passed - continue with scripts/03-download.sh ==="
else log "=== Some checks FAILED - see above ==="; fi
exit $ERR
