#!/usr/bin/env bash
# privacy-check.sh - make sure nothing personal or secret is about to be committed.
# Checks every tracked or staged file (or the files given as arguments) for
#   - signing keys and personal config files
#   - private IPv4 addresses, home-network host names, e-mail addresses (except noreply/example)
#   - your own patterns from .private-patterns (one extended regex per line, ignored by git)
# Use it as a git pre-commit hook:
#   ln -s ../../scripts/dev/privacy-check.sh .git/hooks/pre-commit
set -uo pipefail
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not inside a git repository"; exit 2; }
cd "$ROOT" || exit 2
if [ $# -gt 0 ]; then FILES=("$@"); else mapfile -t FILES < <(git ls-files; git diff --cached --name-only --diff-filter=AM); fi
mapfile -t FILES < <(printf '%s\n' "${FILES[@]}" | sort -u | while read -r f; do [ -f "$f" ] && echo "$f"; done)
HIT=0
report() { echo "PRIVACY: $1"; HIT=1; }

for f in "${FILES[@]}"; do
  case $f in
    config.env|.private-patterns|*.pk8|*.x509.pem|*.key|keys/*|*/keys/*) report "$f must not be committed" ;;
  esac
done

GENERIC=(
  '\b(10|127)\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b'
  '\b192\.168\.[0-9]{1,3}\.[0-9]{1,3}\b'
  '\b172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}\b'
  '\.(fritz\.box|lan|home\.arpa|localdomain)\b'
  'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY'
)
for re in "${GENERIC[@]}"; do
  out=$(grep -nIE "$re" -- "${FILES[@]}" 2>/dev/null | grep -v 'scripts/dev/privacy-check.sh')
  [ -n "$out" ] && report "pattern '$re':"$'\n'"$out"
done
# e-mail addresses other than GitHub noreply / example domains / the license
out=$(grep -noIE '[A-Za-z0-9._%+-]+@[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}' -- "${FILES[@]}" 2>/dev/null \
      | grep -vE '@users\.noreply\.github\.com|@example\.(com|org|invalid)|@anthropic\.com|^LICENSE:')
[ -n "$out" ] && report "e-mail address:"$'\n'"$out"

if [ -f .private-patterns ]; then
  while IFS= read -r re; do
    [ -z "$re" ] || [[ $re == \#* ]] && continue
    out=$(grep -niIE -- "$re" "${FILES[@]}" 2>/dev/null)
    [ -n "$out" ] && report "private pattern '$re':"$'\n'"$out"
  done < .private-patterns
fi

if [ $HIT = 0 ]; then echo "privacy check: OK (${#FILES[@]} files)"; else echo "privacy check: FAILED"; fi
exit $HIT
