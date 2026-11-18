# shellcheck shell=bash
# shellcheck disable=SC2034  # variables are used by the scripts that source this file
# lib.sh - shared settings and helpers, sourced by all scripts.
# Reads config.env from the repository root (or the file given in $CCB_CONFIG).

CCB_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CCB_SCRIPTS=$CCB_ROOT/scripts

# ---------- defaults (overridden by config.env) ----------
WORK_DIR="$HOME/android"
OUTPUT_DIR="$HOME/crdroid-out"
JOBS=""
SYNC_JOBS=6
CCACHE_SIZE="50G"
MIN_RAM_GB=30
WITH_VIPER=true
WITH_GAPPS=true
WIDEVINE_L3=false
SIGNING="test"
KEY_SUBJECT=""
OTA_URL=""
OTA_UPLOAD=""
OTA_KEEP=3
MAINTAINER=""
WSL_DISTRO="crdroid"

CCB_CONFIG=${CCB_CONFIG:-$CCB_ROOT/config.env}
if [ -f "$CCB_CONFIG" ]; then
  # tolerate files edited with Windows editors (CRLF line endings, UTF-8 BOM)
  # shellcheck source=/dev/null
  . <(sed -e '1s/^\xEF\xBB\xBF//' -e 's/\r$//' "$CCB_CONFIG")
fi

# ---------- fixed values for this device / ROM ----------
DEVICE=camellia
CRDROID_BRANCH=16.0
LINEAGE_BRANCH=lineage-23.2
LUNCH_TARGET=lineage_camellia-bp4a-userdebug
ZIP_PATTERN="crDroidAndroid-16.0-*-$DEVICE-*.zip"
# Stock MIUI 14 Global recovery ROM - source of the proprietary vendor files
STOCK_VERSION=V14.0.6.0.TKSMIXM
STOCK_ZIP=miui_CAMELLIANGlobal_V14.0.6.0.TKSMIXM_8be0f8ee2d_13.0.zip
STOCK_MD5=8be0f8ee2dfd7c76b06c13cbf652bbd0
# download mirrors; 03-download.sh tests them and uses the fastest. Can be set in config.env.
: "${STOCK_MIRRORS:=bkt-sgp-miui-ota-update-alisgp.oss-ap-southeast-1.aliyuncs.com cdnorg.d.miui.com bigota.d.miui.com}"

# ---------- derived paths ----------
SRC=$WORK_DIR/crdroid
KEYS_DIR=$WORK_DIR/keys
BUILDS_DIR=$OUTPUT_DIR/builds
DL_DIR=$OUTPUT_DIR/downloads
LOG_DIR=$OUTPUT_DIR/logs
KEY_BACKUP_DIR=$OUTPUT_DIR/key-backup
SOURCE_STATE=$SRC/.ccb-source-state.xml     # "repo manifest -r" right after the last sync
KNOWN_GOOD_MARK=$SRC/.ccb-known-good        # exists while the tree is pinned to a known-good tag

export PATH="$HOME/bin:$PATH"
export USE_CCACHE=1 CCACHE_EXEC=/usr/bin/ccache CCACHE_DIR=$WORK_DIR/ccache
# one cache for every tree below WORK_DIR
export CCACHE_BASEDIR=$WORK_DIR CCACHE_NOHASHDIR=1
[ -n "$JOBS" ] || JOBS=$(nproc)

# ---------- helpers ----------
LOG=/dev/null
init_log() { mkdir -p "$LOG_DIR"; LOG=$LOG_DIR/$1.log; }
log()  { printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG"; }
warn() { log "WARNING: $*"; }
die()  { log "ERROR: $*"; exit 1; }
is_true() { case "${1,,}" in true|yes|1|on) return 0 ;; *) return 1 ;; esac; }
need_src() { [ -d "$SRC/.repo" ] || die "No source tree in $SRC - run scripts/04-sync.sh first."; }
is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }
# Subject of a git-format-patch file (folded header lines joined)
patch_subject() {
  awk '/^Subject:/{s=$0; while((getline l)>0 && l ~ /^[ \t]/) s=s l; print s; exit}' "$1" \
    | sed 's/^Subject: \(\[PATCH[^]]*\] \)\{0,1\}//'
}
