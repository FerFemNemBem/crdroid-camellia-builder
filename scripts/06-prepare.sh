#!/usr/bin/env bash
# 06-prepare.sh - prepare the synced source tree for a camellia build:
#   A) device tree patches (patches/device/: VoLTE fix, gold connectivity firmware list, ViPER,
#      optional Widevine L3)
#   B) the 8 required patches in device/xiaomi/camellia/patches/ (the 8th arrives with device patch 0006 by fieldmar)
#      (a file with the same name in patches/crdroid-16.0/ replaces the device tree version)
#   C) the 8 "gold" connectivity firmware files, checked against the SHA-1 in proprietary-files.txt
#   D) proprietary vendor files extracted from the stock MIUI ROM
#   E) updater: your own OTA server, only if OTA_URL is set
#   F) signing keys present (SIGNING=own) or absent (SIGNING=test)
# Safe to run repeatedly: everything already done is detected and skipped.
#   bash scripts/06-prepare.sh
set -uo pipefail
. "$(dirname "$0")/lib.sh"
init_log 06-prepare
need_src
DT=$SRC/device/xiaomi/camellia
VND=$SRC/vendor/xiaomi/camellia
ERR=0
fail() { log "!!! $*"; ERR=1; }
# true if the commit subject is among the last 50 commits (grep without -q: avoids SIGPIPE with pipefail)
has_subject() { git -C "$1" log --format=%s -50 | grep -xF "$2" >/dev/null; }

log "=== Prepare $SRC ==="
[ -d "$DT" ] || die "device tree missing ($DT) - run scripts/04-sync.sh"

# ---------- A) device tree patches ----------
log "--- A) device tree patches ---"
for p in "$CCB_ROOT"/patches/device/*.patch; do
  [ -f "$p" ] || continue
  n=$(basename "$p"); s=$(patch_subject "$p")
  # optional patches: applied or removed according to their switch in config.env
  opt=""
  case $n in *ViPER*) opt=WITH_VIPER ;; *Widevine-L3*) opt=WIDEVINE_L3 ;; *hotspot-share*) opt=HOTSPOT_REPEATER ;; esac
  if [ -n "$opt" ]; then
    if git -C "$DT" apply --reverse --check "$p" 2>/dev/null; then
      if is_true "${!opt}"; then log "already applied: $s"
      else
        git -C "$DT" apply -R "$p" && git -C "$DT" commit -qam "Remove: $s" && log "removed ($opt=false): $s" \
          || fail "could not remove: $s"
      fi
      continue
    fi
    if ! is_true "${!opt}"; then log "skipped ($opt=false): $s"; continue; fi
  elif has_subject "$DT" "$s" || git -C "$DT" apply --reverse --check "$p" 2>/dev/null; then
    log "already applied: $s"; continue
  fi
  if git -C "$DT" am --keep-cr -q "$p"; then log "applied: $s"
  else git -C "$DT" am --abort 2>/dev/null; fail "device patch does not apply: $n"; fi
done

# ---------- B) required patches from the device tree ----------
log "--- B) required patches ---"
declare -A TARGET=(
  [bluetooth_mtk_sniff_subrating]=packages/modules/Bluetooth
  [codec2_mtk_dequeue_fence_leak]=frameworks/av
  [connectivity_android16_on_kernel414]=packages/modules/Connectivity
  [fmradio_rds_lp64_struct]=packages/apps/FMRadio
  [livedisplay_sysfs_se_value]=hardware/lineage/interfaces
  [sensors_multihal_vendor_type]=hardware/interfaces
  [wifi_countrycode_chip_fallback]=packages/modules/Wifi
  [wifi_mtk_configurechip_quirk]=packages/modules/Wifi
)
for p in $(printf '%s\n' "${!TARGET[@]}" | sort); do
  pf=$DT/patches/$p.patch; repo=$SRC/${TARGET[$p]}
  if [ -f "$CCB_ROOT/patches/crdroid-16.0/$p.patch" ]; then pf=$CCB_ROOT/patches/crdroid-16.0/$p.patch; log "(crDroid replacement for $p)"; fi
  [ -f "$pf" ] || { fail "patch $p missing in the device tree"; continue; }
  [ -d "$repo" ] || { fail "project ${TARGET[$p]} missing"; continue; }
  if git -C "$repo" apply --reverse --check "$pf" 2>/dev/null; then log "already applied: $p"; continue; fi
  if git -C "$repo" apply --check "$pf" 2>/tmp/ccb-err; then
    git -C "$repo" apply "$pf" && git -C "$repo" add -A && git -C "$repo" commit -q -m "camellia (local): $p" \
      && log "applied: $p -> ${TARGET[$p]}"
  else
    fail "$p does not apply to ${TARGET[$p]}:"; tee -a "$LOG" < /tmp/ccb-err
  fi
done

# ---------- C) gold connectivity firmware ----------
log "--- C) gold connectivity firmware ---"
mkdir -p "$VND/proprietary/vendor/firmware"
while IFS='|' read -r path want; do
  f=$(basename "$path"); dest=$VND/proprietary/$path
  if [ -f "$dest" ] && [ "$(sha1sum "$dest" | cut -c1-40)" = "$want" ]; then log "present: $f"; continue; fi
  curl -fsSL --retry 3 "https://raw.githubusercontent.com/crdroidandroid/android_vendor_xiaomi_camellia/14.0/proprietary/vendor/firmware/$f" -o "$dest"
  have=$(sha1sum "$dest" 2>/dev/null | cut -c1-40)
  if [ "$have" = "$want" ]; then log "downloaded: $f"; else fail "$f has SHA-1 ${have:-none}, expected $want"; fi
done < <(grep -E '^vendor/firmware/(soc2_2_ram_|WIFI_RAM_CODE_soc2_2_).*\|' "$DT/proprietary-files.txt")

# ---------- D) proprietary vendor files ----------
log "--- D) vendor files from $STOCK_ZIP ---"
ZIP=$DL_DIR/$STOCK_ZIP
if [ ! -f "$ZIP.ok" ]; then
  fail "stock ROM missing or not verified - run scripts/03-download.sh"
else
  cd "$DT" || exit 1
  # wifi.cfg is pinned AND modified by a fixup. extract-utils restores the already modified copy on
  # every run and appends the line again -> remove it first so it is fixed exactly once.
  rm -f "$VND/proprietary/vendor/firmware/wifi.cfg"
  ./extract-files.py "$ZIP" 2>&1 | tee /tmp/ccb-extract.log >> "$LOG"
  n=$(grep -c '^SapCheckPmkidInDriver' "$VND/proprietary/vendor/firmware/wifi.cfg" 2>/dev/null || echo 0)
  [ "$n" = 1 ] && log "wifi.cfg fixup applied exactly once" || fail "wifi.cfg: SapCheckPmkidInDriver ${n}x instead of 1x"
  N=$(find "$VND/proprietary" -type f | wc -l)
  [ "$N" -gt 500 ] && log "$N vendor files extracted" || fail "only $N vendor files extracted - see $LOG"
fi

# ---------- E) updater: own OTA server ----------
log "--- E) updater ---"
UPD=$SRC/packages/apps/Updater
OTA_SUBJECT="Updater: use custom OTA server"
STR=$UPD/app/src/main/res/values/strings.xml
cur=$(sed -n 's:.*<string name="updater_server_url"[^>]*>\(.*\)</string>.*:\1:p' "$STR")
if [ -z "$OTA_URL" ]; then
  if has_subject "$UPD" "$OTA_SUBJECT"; then
    git -C "$UPD" checkout -q --detach refs/remotes/m/"$CRDROID_BRANCH" && log "custom OTA server removed (OTA_URL is empty)"
  else
    log "stock updater kept (OTA_URL is empty)"
  fi
elif [[ $OTA_URL != */\{device\}.json ]] || [[ $OTA_URL != http://* && $OTA_URL != https://* ]]; then
  fail "OTA_URL must start with http:// or https:// and end with /{device}.json (is: $OTA_URL)"
elif [ "$cur" = "$OTA_URL" ]; then
  log "updater already points to $OTA_URL"
else
  if has_subject "$UPD" "$OTA_SUBJECT"; then git -C "$UPD" checkout -q --detach refs/remotes/m/"$CRDROID_BRANCH"; fi
  if python3 - "$UPD" "$OTA_URL" <<'PY'
import os, re, sys
from urllib.parse import urlparse
from xml.sax.saxutils import escape
upd, url = sys.argv[1], sys.argv[2]
app = os.path.join(upd, "app/src/main")
# 1) URL
p = os.path.join(app, "res/values/strings.xml")
s = open(p).read()
s2 = re.sub(r'(<string name="updater_server_url"[^>]*>)(.*?)(</string>)', lambda m: m.group(1) + escape(url) + m.group(3), s, count=1)
if s2 == s: sys.exit("updater_server_url not found in strings.xml")
open(p, "w").write(s2)
if url.startswith("http://"):
    host = urlparse(url).hostname
    # 2) allow cleartext HTTP for exactly this host
    os.makedirs(os.path.join(app, "res/xml"), exist_ok=True)
    open(os.path.join(app, "res/xml/network_security_config.xml"), "w").write(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!-- Cleartext HTTP only for the own OTA server; packages are verified with the release key. -->\n'
        '<network-security-config>\n'
        '    <base-config cleartextTrafficPermitted="false" />\n'
        '    <domain-config cleartextTrafficPermitted="true">\n'
        f'        <domain includeSubdomains="false">{escape(host)}</domain>\n'
        '    </domain-config>\n'
        '</network-security-config>\n')
    p = os.path.join(app, "AndroidManifest.xml")
    s = open(p).read()
    if "networkSecurityConfig" not in s:
        s2 = re.sub(r"<application\b", '<application\n        android:networkSecurityConfig="@xml/network_security_config"', s, count=1)
        if s2 == s: sys.exit("<application> not found in AndroidManifest.xml")
        open(p, "w").write(s2)
    # 3) the updater refuses non-HTTPS URLs - allow this one host
    hit = False
    for root, _, files in os.walk(os.path.join(app, "java")):
        for f in files:
            if not f.endswith((".kt", ".java")): continue
            fp = os.path.join(root, f); t = open(fp).read()
            if 'base.startsWith("https://")' in t and "http://" + host not in t:
                t = t.replace('base.startsWith("https://")', 'base.startsWith("https://") || base.startsWith("http://%s/")' % host, 1)
                open(fp, "w").write(t); hit = True
    if not hit: sys.exit("HTTPS check not found in the updater code - use an https:// OTA_URL")
PY
  then
    git -C "$UPD" add -A && git -C "$UPD" commit -q -m "$OTA_SUBJECT" -m "URL: $OTA_URL" && log "updater now uses $OTA_URL"
  else
    git -C "$UPD" checkout -q -- . ; git -C "$UPD" clean -qfd
    fail "could not change the updater (see message above)"
  fi
fi

# ---------- F) signing ----------
log "--- F) signing ---"
KMK=$SRC/vendor/lineage-priv/keys/keys.mk
if [ "$SIGNING" = "own" ]; then
  if [ ! -f "$KMK" ]; then fail "own keys not installed - run scripts/05-keys.sh"
  elif ! grep -q MAINLINE_BLUETOOTH_SEPOLICY "$KMK"; then fail "keys.mk lacks the Bluetooth line - run scripts/05-keys.sh again"
  else log "own release keys installed"; fi
elif [ "$SIGNING" = "test" ]; then
  [ -d "$SRC/vendor/lineage-priv/keys" ] && fail "SIGNING=test but own keys are installed - run scripts/05-keys.sh to disable them" \
    || log "test keys (SIGNING=test)"
else
  fail "SIGNING must be 'own' or 'test'"
fi

if [ $ERR = 0 ]; then log "=== Everything prepared - continue with scripts/07-build.sh ==="
else log "=== Preparation FAILED - see the lines marked !!! above and $LOG ==="; fi
exit $ERR
