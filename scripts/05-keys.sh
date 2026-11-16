#!/usr/bin/env bash
# 05-keys.sh - create your own signing keys (once!) and install them into the source tree.
#   bash scripts/05-keys.sh            create missing keys, install them, encrypted backup if new
#   bash scripts/05-keys.sh --backup   additionally make a new encrypted backup now
# With SIGNING=test in config.env the public AOSP test keys are used instead (see docs/signing.md).
#
# Keys are created WITHOUT a password in $WORK_DIR/keys and never leave this computer
# except as the encrypted backup in $OUTPUT_DIR/key-backup. Existing keys are never overwritten.
# LOSING THE KEYS means the next build can only be installed with "Format data".
set -euo pipefail
. "$(dirname "$0")/lib.sh"
init_log 05-keys
BACKUP=0; [ "${1:-}" = "--backup" ] && BACKUP=1
need_src
DEST=$SRC/vendor/lineage-priv/keys

if [ "$SIGNING" = "test" ]; then
  log "SIGNING=test: builds will be signed with the public AOSP test keys (insecure, see docs/signing.md)."
  if [ -d "$DEST" ]; then
    mv "$DEST" "$SRC/vendor/lineage-priv/keys.disabled-$(date +%Y%m%d-%H%M%S)"
    log "own keys in the source tree disabled (moved aside, nothing deleted)."
  fi
  exit 0
fi
[ "$SIGNING" = "own" ] || die "SIGNING must be 'own' or 'test' (is '$SIGNING')"

NAMES="releasekey platform shared media networkstack bluetooth sdk_sandbox verifiedboot nfc testkey"
MAKE_KEY=$SRC/development/tools/make_key
MISSING=""
for k in $NAMES; do [ -s "$KEYS_DIR/$k.pk8" ] && [ -s "$KEYS_DIR/$k.x509.pem" ] || MISSING="$MISSING $k"; done

if [ -z "$MISSING" ]; then
  log "all keys present in $KEYS_DIR - nothing created."
else
  [ -x "$MAKE_KEY" ] || die "make_key not found ($MAKE_KEY) - is the source tree complete?"
  mkdir -p "$KEYS_DIR"; chmod 700 "$KEYS_DIR"
  if [ -f "$KEYS_DIR/.subject" ]; then SUBJECT=$(cat "$KEYS_DIR/.subject")
  elif [ -n "$KEY_SUBJECT" ]; then SUBJECT=$KEY_SUBJECT
  else
    echo "Your keys get a certificate subject (public, visible in the APK signatures)."
    read -rp "Name or nickname for the certificate: " NAME
    SUBJECT="/O=${NAME}/OU=crDroid builds/CN=${NAME} camellia release"
  fi
  echo "$SUBJECT" > "$KEYS_DIR/.subject"
  for k in $MISSING; do
    # remove half-written leftovers of an interrupted run (only this pair, moved aside)
    for e in pk8 x509.pem; do if [ -f "$KEYS_DIR/$k.$e" ]; then mv -f "$KEYS_DIR/$k.$e" "$KEYS_DIR/$k.$e.broken"; fi; done
    log "creating $k ..."
    # make_key always exits with 1 (trap in the script) - success = both files exist
    ( cd "$KEYS_DIR" && printf '\n' | "$MAKE_KEY" "$k" "$SUBJECT" >/dev/null 2>&1 ) || true
    [ -s "$KEYS_DIR/$k.pk8" ] && [ -s "$KEYS_DIR/$k.x509.pem" ] || die "$k was not created"
  done
  chmod 600 "$KEYS_DIR"/*.pk8
  log "created:$MISSING"
  BACKUP=1
fi

cat > "$KEYS_DIR/keys.mk" <<'MK'
PRODUCT_DEFAULT_DEV_CERTIFICATE := vendor/lineage-priv/keys/releasekey
# The Bluetooth mainline module has its own SELinux certificate list, which defaults to the
# AOSP test keys. Without this line the Bluetooth app (signed with our "bluetooth" key) gets no
# SELinux domain and crashes: "Bluetooth keeps stopping" (seinfo default, uid 1002).
PRODUCT_MAINLINE_BLUETOOTH_SEPOLICY_DEV_CERTIFICATES := $(dir $(PRODUCT_DEFAULT_DEV_CERTIFICATE))
MK
cat > "$KEYS_DIR/BUILD.bazel" <<'BZ'
filegroup(
    name = "android_certificate_directory",
    srcs = glob([
        "*.pk8",
        "*.pem",
    ]),
    visibility = ["//visibility:public"],
)
BZ
mkdir -p "$DEST"
cp -a "$KEYS_DIR"/. "$DEST/"
log "keys installed into $DEST"

if [ $BACKUP = 1 ]; then
  mkdir -p "$KEY_BACKUP_DIR"
  F=$KEY_BACKUP_DIR/android-keys-$(date +%Y%m%d-%H%M).tar.gz.gpg
  if [ -n "${CCB_BACKUP_PASSPHRASE:-}" ]; then
    # passphrase given by build-all.sh (asked at the start)
    GPG=(gpg --batch --yes --pinentry-mode loopback --passphrase-fd 3)
    tar -C "$WORK_DIR" -czf - "$(basename "$KEYS_DIR")" | "${GPG[@]}" --symmetric --cipher-algo AES256 -o "$F" 3<<<"$CCB_BACKUP_PASSPHRASE"
    N=$("${GPG[@]}" -d "$F" 3<<<"$CCB_BACKUP_PASSPHRASE" 2>/dev/null | tar -tzf - | grep -c '\.pk8$' || true)
  else
    echo
    echo ">>> Choose a PASSPHRASE for the encrypted backup (asked twice)."
    echo ">>> Without it the backup is useless - store it in a password manager!"
    tar -C "$WORK_DIR" -czf - "$(basename "$KEYS_DIR")" | gpg --symmetric --cipher-algo AES256 --pinentry-mode loopback -o "$F"
    echo ">>> Checking the backup (enter the passphrase once more):"
    N=$(gpg --pinentry-mode loopback -d "$F" 2>/dev/null | tar -tzf - | grep -c '\.pk8$' || true)
  fi
  [ "$N" -ge 10 ] && log "backup OK: $F ($N private keys)" || die "backup check failed ($F)"
  echo ">>> Copy $(basename "$F") to a second place (USB stick, cloud) as well."
fi

log "releasekey fingerprint (public, note it down):"
openssl x509 -in "$KEYS_DIR/releasekey.x509.pem" -noout -subject -enddate -fingerprint -sha256 | tee -a "$LOG"
log "=== Keys ready - continue with scripts/06-prepare.sh ==="
