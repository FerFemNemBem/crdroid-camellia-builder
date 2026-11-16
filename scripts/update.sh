#!/usr/bin/env bash
# update.sh - keep your crDroid build up to date.
#   bash scripts/update.sh                  check: compare your source tree with GitHub (changes nothing)
#   bash scripts/update.sh build            if something is new: sync -> prepare -> build -> publish (run in tmux!)
#   bash scripts/update.sh build --force    build even if nothing is new
# Exit code of "check": 0 = nothing new, 10 = updates available, 1 = error.
# "publish" only runs if OTA_URL and OTA_UPLOAD are set in config.env.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
init_log update
MODE=check; FORCE=0
for a in "$@"; do case $a in check|build) MODE=$a ;; --force) FORCE=1 ;; *) echo "Unknown option: $a"; exit 1 ;; esac; done
need_src

# Sources to watch:  path in tree | GitHub repository | branch
# 1) fixed crDroid repositories (all other crDroid changes come with a manifest update)
WATCH="
.repo/manifests|crdroidandroid/android|$CRDROID_BRANCH
vendor/lineage|crdroidandroid/android_vendor_crdroid|$CRDROID_BRANCH
build/make|crdroidandroid/android_build|$CRDROID_BRANCH
frameworks/base|crdroidandroid/android_frameworks_base|$CRDROID_BRANCH
packages/apps/Settings|crdroidandroid/android_packages_apps_Settings|$CRDROID_BRANCH
packages/apps/Updater|crdroidandroid/android_packages_apps_Updater|$CRDROID_BRANCH
"
# 2) every GitHub project of our local manifest (device, kernel, LineageOS forks, ViPER ...).
#    Without revision: lineage-23.2. Projects pinned to a commit never change and are skipped.
WATCH+=$(python3 -I - "$CCB_ROOT/manifests/crdroid-16.0/camellia.xml" "$LINEAGE_BRANCH" <<'PY'
import re, sys, xml.etree.ElementTree as ET
for p in ET.parse(sys.argv[1]).getroot().iter("project"):
    if p.get("remote") != "github": continue
    rev = p.get("revision", sys.argv[2])
    if re.fullmatch(r"[0-9a-f]{40}", rev): continue
    print(f'{p.get("path")}|{p.get("name")}|{rev.removeprefix("refs/heads/")}')
PY
)

check() {  # sets NEW = number of sources with new commits
  NEW=0
  local path repo branch here there
  while IFS='|' read -r path repo branch; do
    [ -n "$path" ] || continue
    if [ "$path" = .repo/manifests ]; then here=$(git -C "$SRC/$path" rev-parse -q --verify HEAD 2>/dev/null)
    else
      # synced upstream state without our patches (set by repo); HEAD as fallback
      here=$(git -C "$SRC/$path" rev-parse -q --verify "refs/remotes/m/$CRDROID_BRANCH" 2>/dev/null \
             || git -C "$SRC/$path" rev-parse -q --verify HEAD 2>/dev/null)
    fi
    there=$(GIT_TERMINAL_PROMPT=0 git ls-remote "https://github.com/$repo" "refs/heads/$branch" 2>/dev/null | cut -f1)
    if [ -z "$there" ]; then log "  ?    $path: $repo not reachable"; continue; fi
    if [ "$here" = "$there" ]; then log "  =    $path"
    else
      NEW=$((NEW+1))
      if [ -n "$here" ]; then log "  NEW  $path: https://github.com/$repo/compare/${here:0:12}...${there:0:12}"
      else log "  NEW  $path (local state unknown): https://github.com/$repo/commits/$branch"; fi
    fi
  done <<< "$WATCH"
  local vl vo
  vl=$(sed -n 's/^CR_VERSION := //p' "$SRC/vendor/lineage/config/version.mk" 2>/dev/null)
  vo=$(curl -fsSL "https://raw.githubusercontent.com/crdroidandroid/android_vendor_crdroid/$CRDROID_BRANCH/config/version.mk" 2>/dev/null | sed -n 's/^CR_VERSION := //p')
  log "  crDroid version: local ${vl:-?}, GitHub ${vo:-?}$( [ -n "$vl" ] && [ -n "$vo" ] && [ "$vl" != "$vo" ] && echo '  <- NEW VERSION')"
  lineage_ahead
  android17_watch
}

# What does LineageOS 23.2 already have that crDroid has not merged yet? (usually the monthly
# security forks) - information only, a build uses what crDroid ships plus our local forks.
lineage_ahead() {
  local c=$WORK_DIR/.lineage-manifest-cache list
  if [ ! -d "$c" ]; then
    git init -q --bare "$c" && git -C "$c" remote add los https://github.com/LineageOS/android \
      && git -C "$c" remote add cr https://github.com/crdroidandroid/android
  fi
  if ! { git -C "$c" fetch -q --filter=blob:none los "$LINEAGE_BRANCH" && git -C "$c" fetch -q --filter=blob:none cr "$CRDROID_BRANCH"; } 2>/dev/null; then
    log "  LineageOS comparison: GitHub not reachable"; return
  fi
  list=$(git -C "$c" log --format='%cd %s' --date=short "refs/remotes/cr/$CRDROID_BRANCH..refs/remotes/los/$LINEAGE_BRANCH")
  if [ -z "$list" ]; then log "  LineageOS $LINEAGE_BRANCH: crDroid has merged everything"
  else
    log "  LineageOS $LINEAGE_BRANCH has $(echo "$list" | wc -l) commit(s) crDroid has not merged yet (info):"
    echo "$list" | head -10 | while IFS= read -r z; do log "       $z"; done
  fi
}

# Android 17 (LineageOS 24 / crDroid 13) for camellia? Information only.
android17_watch() {
  local found="" r b
  for r in cristidclxvi/android_device_xiaomi_camellia cristidclxvi/android_kernel_xiaomi_camellia \
           cristidclxvi/android_kernel_modules_xiaomi_camellia fieldmar/android_device_xiaomi_camellia \
           crdroidandroid/android_device_xiaomi_camellia LineageOS/android_device_xiaomi_camellia; do
    # matches e.g. lineage-24.0, camellian-24.0, 17.0 (not lineage-23.2, 13.0, 14.0)
    b=$(GIT_TERMINAL_PROMPT=0 git ls-remote --heads "https://github.com/$r" 2>/dev/null | sed 's#.*refs/heads/##' \
        | grep -E '(^|-)2[4-9](\.|$)|^1[7-9]\.' | tr '\n' ' ')
    if [ -n "$b" ]; then found+="       $r: $b"$'\n'; fi
  done
  if [ "$(curl -s -o /dev/null -w '%{http_code}' https://raw.githubusercontent.com/crdroidandroid/android_vendor_crDroidOTA/17.0/camellia.json)" = 200 ]; then
    found+="       official crDroid 13 for camellia: https://github.com/crdroidandroid/android_vendor_crDroidOTA/blob/17.0/camellia.json"$'\n'
  fi
  if [ -n "$found" ]; then
    log "  *** ANDROID 17 for camellia: something is happening ***"
    printf '%s' "$found" | while IFS= read -r z; do log "$z"; done
  else
    log "  Android 17 for camellia: nothing yet (no lineage-24.0 device tree/kernel, no official crDroid 13)"
  fi
}

log "=== update ($MODE) ==="
[ -f "$KNOWN_GOOD_MARK" ] && log "note: the tree is pinned to known-good state $(cat "$KNOWN_GOOD_MARK"); 'build' switches to the latest state"
log "comparing $SRC with GitHub ..."
check
if [ "$MODE" = check ]; then
  if [ "$NEW" = 0 ]; then log "Nothing new."; exit 0; fi
  log "$NEW source(s) with new commits. Build with:  bash scripts/update.sh build   (inside tmux)"
  exit 10
fi
if [ "$NEW" = 0 ] && [ $FORCE = 0 ] && [ ! -f "$KNOWN_GOOD_MARK" ]; then log "Nothing new - no build (use --force to build anyway)."; exit 0; fi

# ---------- 1) sync ----------
bash "$CCB_SCRIPTS/04-sync.sh" || die "sync failed - see $LOG_DIR/04-sync.log"
log "check after the sync:"
check
[ "$NEW" = 0 ] || warn "$NEW source(s) still differ after the sync - the build continues."
# do we still need our LineageOS forks? (remove-project entries in the local manifest)
for p in $(sed -n 's/.*<remove-project path="\([^"]*\)".*/\1/p' "$CCB_ROOT/manifests/crdroid-16.0/camellia.xml"); do
  name=$(grep -rhoE "<project [^>]*path=\"$p\"[^>]*>" "$SRC/.repo/manifests" --include='*.xml' | grep -oE 'name="[^"]*"' | head -1)
  case $name in
    ''|'name="platform/'*) ;;   # crDroid still uses the AOSP version -> our LineageOS fork is still needed
    *) log "NOTE: crDroid now has its own $p ($name) - the replacement in the local manifest may be obsolete" ;;
  esac
done

# ---------- 2) prepare, 3) build ----------
bash "$CCB_SCRIPTS/06-prepare.sh" || die "prepare failed (does a patch no longer apply?) - see $LOG_DIR/06-prepare.log.
       Building a tested state instead:  bash scripts/04-sync.sh --known-good <tag>  (tags: git tag -l)"
bash "$CCB_SCRIPTS/07-build.sh" || die "build failed - see $LOG_DIR/07-build.log"

# ---------- 4) publish ----------
if [ -n "$OTA_URL" ] && [ -n "$OTA_UPLOAD" ]; then
  bash "$CCB_SCRIPTS/08-publish.sh" || die "publish failed - see $LOG_DIR/08-publish.log"
  log "=== DONE: new build on your OTA server - on the phone: Updater -> check for updates ==="
else
  log "=== DONE: new build in $BUILDS_DIR (no OTA server configured - flash it manually, docs/flash.md) ==="
fi
