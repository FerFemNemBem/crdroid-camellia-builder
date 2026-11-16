#!/usr/bin/env bash
# build-all.sh - the whole first build in one go:
#   check -> downloads -> sources -> keys -> prepare -> build -> (publish)
# All questions are asked at the start; afterwards it runs unattended for several hours.
# It runs inside tmux (session "crdroid-build"): close the window and it keeps running;
# start the script again to get the display back. If it stops (network, power ...), simply start
# it again - finished steps are skipped.
#   bash scripts/build-all.sh             start or resume
#   bash scripts/build-all.sh --restart   forget the progress of an unfinished run and start over
# Requirement: scripts/01-setup-host.sh has been run once (see docs/setup.md).
set -uo pipefail
. "$(dirname "$0")/lib.sh"
SESSION=crdroid-build

# ---------- run inside tmux ----------
if [ -z "${TMUX:-}" ] && [ -t 0 ] && command -v tmux >/dev/null; then
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "build-all is already running - showing it."
  else
    tmux new-session -d -s "$SESSION" -c "$PWD" "bash $(printf %q "$(realpath "$0")") $*; echo; read -rp 'Finished - press Enter to close this window ' x"
  fi
  exec tmux attach -t "$SESSION"
fi

init_log build-all
STATE=$LOG_DIR/build-all.state     # finished steps of the current run
STATUS=$LOG_DIR/build-all.status   # one line for the tmux status bar
[ "${1:-}" = "--restart" ] && rm -f "$STATE"
touch "$STATE"
done_step() { grep -qx "$1" "$STATE"; }

if [ -n "${TMUX:-}" ]; then
  tmux set-option -q status-interval 5
  tmux set-option -q status-right-length 150
  tmux set-option -q status-left " crDroid build "
  tmux set-option -q status-style "bg=colour24,fg=colour255"
  tmux set-option -q status-right "#(cat $(printf %q "$STATUS") 2>/dev/null) "
fi

clear 2>/dev/null
cat <<'TXT'
==============================================================================
 crdroid-camellia-builder - complete build
 Takes several hours (first time: about 1-3 h download + 2-4 h build).
 The bar at the bottom shows the current step, the elapsed time and the disk
 space used so far. Close this window any time - the build keeps running;
 start the script again to see it.
==============================================================================
TXT
grep -q . "$STATE" && log "resuming - already finished: $(tr '\n' ' ' < "$STATE")"

# ---------- questions at the start ----------
need_keys=0
if [ "$SIGNING" = own ]; then
  for k in releasekey platform shared media networkstack bluetooth sdk_sandbox verifiedboot nfc testkey; do
    [ -s "$KEYS_DIR/$k.pk8" ] || need_keys=1
  done
fi
if [ $need_keys = 1 ] && [ -z "${CCB_BACKUP_PASSPHRASE:-}" ]; then
  [ -t 0 ] || die "build-all needs a terminal to ask for the key backup passphrase (or set CCB_BACKUP_PASSPHRASE)"
  echo
  echo "Your own signing keys will be created during the run (see docs/signing.md)."
  if [ ! -f "$KEYS_DIR/.subject" ] && [ -z "$KEY_SUBJECT" ]; then
    read -rp "Name or nickname for the key certificate (public): " NAME
    export KEY_SUBJECT="/O=${NAME}/OU=crDroid builds/CN=${NAME} camellia release"
  fi
  echo "The keys are backed up encrypted. Choose a passphrase and keep it in a password manager."
  while :; do
    read -rsp "Passphrase for the key backup: " P1; echo
    read -rsp "Repeat the passphrase: " P2; echo
    if [ -n "$P1" ] && [ "$P1" = "$P2" ]; then break; fi
    echo "Empty or not identical - please try again."
  done
  export CCB_BACKUP_PASSPHRASE=$P1
fi
RAM=$(free -g | awk '/Mem:/{print $2}')
if [ "$RAM" -lt "$MIN_RAM_GB" ]; then
  [ -t 0 ] || die "only $RAM GB RAM (MIN_RAM_GB=$MIN_RAM_GB)"
  read -rp "Only $RAM GB RAM available (recommended: $MIN_RAM_GB+). Continue anyway? (y/N) " a
  [ "${a,,}" = y ] || exit 1
fi
export CCB_UNATTENDED=1
echo; log "=== build-all started - from now on no more questions ==="

# ---------- status bar ----------
STEPS=(check download sync keys prepare build)
if [ -n "$OTA_URL" ] && [ -n "$OTA_UPLOAD" ]; then STEPS+=(publish); fi
T0=$(date +%s)
used_gb() { df -BG --output=used "$WORK_DIR" 2>/dev/null | tail -1 | tr -dc 0-9; }
U0=$(used_gb)
hms() { printf '%d:%02d:%02d' $(($1/3600)) $(($1%3600/60)) $(($1%60)); }
ticker() {
  local spin='|/-\' i=0 n name t1 now
  while :; do
    if [ -f "$STATUS.step" ]; then
      read -r n name t1 < "$STATUS.step"; now=$(date +%s)
      printf '%s step %s/%s: %s | step %s | total %s | disk +%s GB' "${spin:i++%4:1}" "$n" "${#STEPS[@]}" "$name" \
        "$(hms $((now-t1)))" "$(hms $((now-T0)))" "$(( $(used_gb) - U0 ))" > "$STATUS.tmp" && mv -f "$STATUS.tmp" "$STATUS"
    fi
    sleep 5
  done
}
ticker & TICKER=$!
trap 'kill $TICKER 2>/dev/null' EXIT

# ---------- the steps ----------
declare -A SCRIPT=([check]=02-check-host.sh [download]=03-download.sh [sync]=04-sync.sh [keys]=05-keys.sh
                   [prepare]=06-prepare.sh [build]=07-build.sh [publish]=08-publish.sh)
# cheap and idempotent steps always run; the long ones are skipped once finished in this run
SKIPPABLE=" sync build publish "
SUMMARY=""
n=0
for s in "${STEPS[@]}"; do
  n=$((n+1))
  if [[ $SKIPPABLE == *" $s "* ]] && done_step "$s"; then log "--- step $n/${#STEPS[@]}: $s - already done, skipped"; continue; fi
  echo "$n $s $(date +%s)" > "$STATUS.step"
  log "=================== step $n/${#STEPS[@]}: $s ==================="
  t=$(date +%s)
  if ! bash "$CCB_SCRIPTS/${SCRIPT[$s]}"; then
    echo "$n $s-FAILED $t" > "$STATUS.step"
    log "STEP '$s' FAILED after $(hms $(( $(date +%s)-t ))). Details: $LOG_DIR/${SCRIPT[$s]%.sh}.log"
    log "Fix the cause (docs/troubleshooting.md) and start build-all again - it continues here."
    exit 1
  fi
  echo "$s" >> "$STATE"
  SUMMARY+=$(printf '  %-9s %s' "$s" "$(hms $(( $(date +%s)-t )))")$'\n'
done

# ---------- summary ----------
echo "${#STEPS[@]} done $(date +%s)" > "$STATUS.step"
B=$(ls -d "$BUILDS_DIR"/*/ 2>/dev/null | sort | tail -1)
rm -f "$STATE"
log "=================== FINISHED in $(hms $(( $(date +%s)-T0 ))) ==================="
printf '%s' "$SUMMARY" | tee -a "$LOG"
log "disk space used by the build: about $(( $(used_gb) - U0 )) GB more than at the start"
log "your ROM: ${B:-?}"
log "next: install it on the phone - docs/flash.md. Later updates: scripts/update.sh (Windows: update.bat)."
