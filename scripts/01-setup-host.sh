#!/usr/bin/env bash
# 01-setup-host.sh - install everything needed to build crDroid on Ubuntu 24.04 (native or WSL2).
# Asks once for your sudo password and, if git has no identity yet, for a name/e-mail
# (only used locally inside the source tree, never published).
#   bash scripts/01-setup-host.sh
set -euo pipefail
. "$(dirname "$0")/lib.sh"
init_log 01-setup-host

log "=== Host setup ==="
grep -q '24.04' /etc/os-release || warn "This is not Ubuntu 24.04 - other versions may work but are untested."

# WSL image imported with "wsl --import" only has root: create a normal user first.
if [ "$(id -u)" -eq 0 ]; then
  if is_wsl; then
    echo "You are root (imported WSL image). Create your normal user now."
    read -rp "Linux user name: " NU
    adduser --gecos "" "$NU"
    usermod -aG sudo "$NU"
    printf '[boot]\nsystemd=true\n\n[interop]\nappendWindowsPath=false\n\n[user]\ndefault=%s\n' "$NU" > /etc/wsl.conf
    echo
    echo ">>> User '$NU' created. In Windows PowerShell run:  wsl --terminate <distribution>"
    echo ">>> then open the distribution again and start this script once more."
    exit 0
  fi
  die "Please run this script as a normal user with sudo rights, not as root."
fi

if is_wsl; then
  log "WSL detected: writing /etc/wsl.conf (systemd on, no Windows PATH, default user $USER)"
  printf '[boot]\nsystemd=true\n\n[interop]\nappendWindowsPath=false\n\n[user]\ndefault=%s\n' "$USER" \
    | sudo tee /etc/wsl.conf >/dev/null
fi

log "--- packages ---"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  bc bison build-essential ccache curl flex g++-multilib gcc-multilib git git-lfs gnupg gperf \
  imagemagick protobuf-compiler python3-protobuf lib32readline-dev lib32z1-dev libdw-dev libelf-dev \
  libgnutls28-dev lz4 libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool \
  squashfs-tools xsltproc xxd zip unzip zlib1g-dev python-is-python3 openssl \
  tmux htop jq wget

log "--- repo tool ---"
mkdir -p "$HOME/bin" "$WORK_DIR" "$OUTPUT_DIR"
curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o "$HOME/bin/repo"
chmod a+x "$HOME/bin/repo"

log "--- ~/.bashrc ---"
if ! grep -q '# >>> crdroid-camellia-builder >>>' "$HOME/.bashrc"; then
  cat >> "$HOME/.bashrc" <<'RC'
# >>> crdroid-camellia-builder >>>
export PATH="$HOME/bin:$PATH"
# <<< crdroid-camellia-builder <<<
RC
fi
# "ccb" = jump into this repository folder from anywhere
sed -i '/^alias ccb=/d' "$HOME/.bashrc"
printf 'alias ccb=%q\n' "cd $(printf %q "$CCB_ROOT")" >> "$HOME/.bashrc"

log "--- ccache ($CCACHE_SIZE in $CCACHE_DIR) ---"
mkdir -p "$CCACHE_DIR"
ccache -M "$CCACHE_SIZE"
ccache -o compression=true

log "--- git ---"
if [ -z "$(git config --global user.name || true)" ]; then
  echo "git needs a name and e-mail to apply patches. They stay on this computer."
  read -rp "Name for git: " GN
  read -rp "E-mail for git (anything, e.g. you@example.invalid): " GE
  git config --global user.name "$GN"
  git config --global user.email "$GE"
fi
git lfs install
git config --global color.ui auto

log "=== Done ==="
echo
echo "New command: type  ccb  to jump into this repository folder ($CCB_ROOT)."
echo "All commands of the guide must be run from there."
echo
if is_wsl; then
  D=${WSL_DISTRO_NAME:-<distribution>}
  echo "Next: restart the distribution once."
  echo "  1. type  exit  to leave Ubuntu"
  echo "  2. in PowerShell:  wsl --terminate $D"
  echo "  3. in PowerShell:  wsl -d $D"
  echo "  4. in Ubuntu:      ccb"
  echo "  5. in Ubuntu:      bash scripts/02-check-host.sh"
else
  echo "Next: open a new terminal, then:  ccb  and  bash scripts/02-check-host.sh"
fi
