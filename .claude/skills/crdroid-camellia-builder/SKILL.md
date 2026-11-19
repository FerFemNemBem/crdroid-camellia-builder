---
name: crdroid-camellia-builder
description: Debug, maintain and release crdroid-camellia-builder (crDroid 16.0 / Android 16 for Xiaomi camellia). Use when a build step fails, a patch no longer applies, crDroid or LineageOS publish a new version or security patch, the phone misbehaves after flashing (Bluetooth, ViPER, updater, SELinux), a tested build should become a known-good release, or the Android 17 watch in update.sh fires.
---

# Working on crdroid-camellia-builder

Read `CLAUDE.md` first (hard rules). User docs live in `docs/`; link to them instead of repeating.

## 1. Orientation

Pipeline (each step is a script in `scripts/`, all idempotent):

| step | script | does | typical duration |
|---|---|---|---|
| check | `02-check-host.sh` | RAM, threads, disk, tools, network | seconds |
| download | `03-download.sh` | stock MIUI 14 Global recovery ZIP (MD5), optional MindTheGapps (SHA-256) | 10-30 min |
| sync | `04-sync.sh [--known-good TAG]` | `repo init` crDroid 16.0, local manifest, `repo sync -c -d ...` in a retry loop, saves `repo manifest -r` to `$SRC/.ccb-source-state.xml` | 45 min - 3 h |
| keys | `05-keys.sh` | own keys via `development/tools/make_key`, `keys.mk` incl. Bluetooth line, encrypted backup | minutes |
| prepare | `06-prepare.sh` | A) device patches, B) 7 required patches (+replacements), C) gold firmware, D) `extract-files.py`, E) updater URL, F) signing check | 5-15 min |
| build | `07-build.sh` | `lunch lineage_camellia-bp4a-userdebug && m bacon`, copies ZIP/boot.img/state to `$BUILDS_DIR/<date-time>/` | 3-4 h first, 7-15 min later |
| publish | `08-publish.sh [-n]` | JSON for the crDroid updater, rsync ZIP then JSON, verify over HTTP, keep `OTA_KEEP` | minutes |

`build-all.sh` chains them (state in `$LOG_DIR/build-all.state`, status line `$LOG_DIR/build-all.status`,
tmux session `crdroid-build`). `update.sh check|build [--force]` compares the tree with GitHub
(exit 0 nothing new / 10 new / 1 error) and rebuilds. Paths come from `lib.sh` + `config.env`.

First questions when helping: which step failed, the last ~50 lines of `$LOG_DIR/<step>.log`,
`config.env` values that matter (never ask for keys), WSL or native, RAM.

## 2. Known pitfalls (symptom -> cause -> fix)

| symptom | cause | fix |
|---|---|---|
| sync: `429` / `RESOURCE_EXHAUSTED` | server rate limit | retry loop handles it; lower `SYNC_JOBS` |
| build: CellBroadcastReceiver, missing `CellBroadcastMetrics` constants | AOSP CellBroadcastService instead of the LineageOS fork (crDroid before 12.14) | crDroid >= 12.14 ships the fork; the local manifest no longer replaces it (removed 2026-11-19). If it ever comes back: `remove-project` (path, `optional="true"`) + `project` with the fork in the local manifest |
| prepare B: connectivity patch does not apply | crDroid already relaxed the 4.19/5.4 checks | `patches/crdroid-16.0/connectivity_android16_on_kernel414.patch` replaces it (same file name = replacement) |
| `wifi.cfg: SapCheckPmkidInDriver Nx` | extract-utils restores the already fixed pinned file and re-applies the fixup | `06` deletes `wifi.cfg` before extracting; count must be 1 |
| a check reports "not found" although the commit is there | `git log | grep -q` + `pipefail` = SIGPIPE | use `grep -xF ... >/dev/null`, never `grep -q` at the end of a pipe |
| folded `Subject:` lines break patch detection | long subjects wrap in format-patch | `patch_subject()` in `lib.sh` joins them |
| ViPER missing on the phone | project not synced; formerly `inherit-product-if-exists` hid it | patch 0003 uses `inherit-product` -> build fails loudly; sync again |
| "Bluetooth keeps stopping", switch flips back; logcat `SELinux: No match for app with uid 1002, seinfo default ... com.android.bluetooth` | Bluetooth mainline module uses `MAINLINE_BLUETOOTH_SEPOLICY_DEV_CERTIFICATES`, default AOSP testkey dir | `keys.mk`: `PRODUCT_MAINLINE_BLUETOOTH_SEPOLICY_DEV_CERTIFICATES := $(dir $(PRODUCT_DEFAULT_DEV_CERTIFICATE))` (05 writes it). Other roles follow `PRODUCT_DEFAULT_DEV_CERTIFICATE` / `MAINLINE_SEPOLICY_DEV_CERTIFICATES` (see `build/make/core/config.mk`, `system/sepolicy/private/keys.conf`) |
| updater shows nothing although a newer build is on the server | JSON without `os_sdk_level` -> updater assumes 0 and drops it; or timestamp not newer than `ro.build.date.utc` | `08-publish.sh` reads `post-sdk-level`/`post-timestamp` from `META-INF/com/android/metadata` |
| updater refuses the server | it requires HTTPS (`require(base.startsWith("https://"))` in `UpdatesNetworkDataSource.kt`) | `06` E: HTTP is allowed for exactly the `OTA_URL` host via network security config + relaxed check |
| updater banner shows "by <name>" | `maintainer` field of the server JSON | `MAINTAINER` in `config.env` (empty = hidden) |
| upload asks for a password / lands in the home folder | key not in the target user's `authorized_keys` (e.g. root's) | see `docs/ota-server.md`; `ssh -v` shows "Offering public key" vs "denied" |
| JSON upload `could not make way for new regular file` under rrsync | uploading to a file path | upload into the directory (`$OTA_UPLOAD/`), the local file already has the right name |
| sideload stops at 47 % | normal | check the phone's screen |
| Disney+ "something went wrong" on play; log: `KREE_OpenFd: Failed to connect to service, ret = -107`, `m4u_gz_sec_init: init fail`, `Decoder failed: c2.mtk.avc.decoder.secure` | MediaTek secure video path (GenieZone/MTEE protected memory) not available; Widevine licence itself works. NOT the firmware: same 14.0.6.0 Global firmware works on stock MIUI (kernel 4.14.186) but fails with the source-built 4.14.357 kernel (pseudo M4U -> GenieZone connect ENOTCONN). /dev/trusty-ipc-dev0, gz_kree, trusty threads, vpud, widevine HAL all present on both | real fix belongs in the kernel (report to cristidclxvi); workaround `WIDEVINE_L3=true` = default (patch 0004, SD playback; verified with 12.14: DRM Info L3, HDCP None, Disney+ plays) |
| Netflix refuses login | Play Integrity: unlocked bootloader passes only basic integrity | no clean fix; root/keybox spoofing not part of this project |
| stock ROM download crawls (kB/s) | Xiaomi mirrors vary hugely; the first one is not always fast | `03-download.sh` measures all `STOCK_MIRRORS` (10 MB sample) and uses the fastest; list can be set in config.env |
| `scripts/...: No such file or directory` | WSL starts in `/mnt/c/Users/<name>`, not in the repository | `ccb` (alias from 01) or `cd /mnt/<lower-case drive>/...`; Windows drives are lower-case under `/mnt/` |
| a config value is ignored or contains `\r` | `config.env` edited on Windows | `lib.sh` strips CRLF/BOM; check the file is really named `config.env`, not `config.env.txt` |
| WSL disk file stays big after deleting files / `fstrim` | sparse auto-reclaim is experimental and often does nothing | `wsl --shutdown`, `--set-sparse false`, diskpart `compact vdisk`; leave sparse OFF afterwards (docs/troubleshooting.md) |
| syntax error in a file that is fine upstream (`unexpected end of input`), git `index file corrupt` / `bad signature 0x00000000` / `bad shallow line`, dmesg `EXT4-fs error ... Remounting filesystem read-only` | ext4 in the WSL disk lost writes after a hard VM stop (seen with sparse VHDX on) | `e2fsck -f -y -D` from another distro (`wsl --mount --vhd ... --bare`), repair git per project (index/reset/checkout), re-fetch broken shallow projects, `rm -rf out`; sparse off. Steps: docs/troubleshooting.md |
| GitHub `429 Too Many Requests` | too many syncs/API calls in a short time | wait; never make the build depend on downloads from github.com PR URLs - keep patches in the repo |
| after a script edit, a running script errors with "unexpected EOF" | script modified while running | never edit running scripts |

Phone logs: `adb logcat -b all -c`, reproduce, `adb logcat -b all -d > logcat.txt`. On Windows
PowerShell `>` writes UTF-16 - convert before grepping (`iconv -f UTF-16LE`) or check the BOM.
Look for `FATAL`, `Abort message`, `No match for app`, `avc: denied`, `has died`.

## 3. Procedure: a patch no longer applies

1. `06-prepare.sh` names the patch and the project (`!!! X does not apply to <path>`).
2. Find the upstream change: `git -C $SRC/<path> log --oneline refs/remotes/m/16.0 -20`, compare with
   the hunk context of the patch; `git apply --check -v` shows the failing hunk.
3. Decide: upstream already contains the fix (drop the hunk), or the context moved (rebase the hunk).
4. Device-tree patch from `device/xiaomi/camellia/patches/X.patch`: put the adapted version as
   `patches/crdroid-16.0/X.patch` (same name -> used instead). Document why in `docs/how-it-works.md`.
   Own device patches (`patches/device/`): apply, fix, `git format-patch -1`, replace the file,
   keep the subject (used for idempotency).
5. Verify against fresh upstream: clone the project at the branch (`--depth 1`), `git apply --check`
   in order 0001, 0002, 0003; then run `06-prepare.sh` twice (second run must say "already applied").
6. If pull requests #7/#8 get merged upstream, `06` detects them (subject or reverse check) and skips;
   the files can then be removed from `patches/device/`.

## 4. Procedure: upstream changes

- `update.sh` lists `NEW` sources with compare links; "LineageOS ... commits crDroid has not merged"
  are usually the next security forks - crDroid normally merges them within weeks.
- After a sync, `update.sh build` prints `NOTE: crDroid now has its own <path>` when a project of our
  `remove-project` list is no longer AOSP in crDroid's manifest. Then check whether our LineageOS fork
  is still needed; usually delete the pair from the local manifest.
- New crDroid version (12.13 -> 12.14): nothing to change in the scripts; `ZIP_PATTERN` covers it.

## 5. Procedure: known-good release

Only after a build was installed and tested on a phone:
1. `cp $BUILDS_DIR/<build>/source-state.xml manifests/known-good/vX.Y.xml`
2. Update the tested table in `README.md` if something new was tested.
3. `bash scripts/dev/privacy-check.sh`, commit, `git tag -a vX.Y -m "..."`, `git push --follow-tags`.
4. Check: `bash scripts/04-sync.sh --known-good vX.Y` must sync without the local manifest
   (the pinned file already contains those projects).
5. Optional example build (as for v1.0): a build with the defaults (`SIGNING=test`), installed and
   tested on the phone. Release assets: ROM ZIP, its `boot.img`, `sha256sums.txt`, `source-state.xml`,
   `build-info.txt` - never GApps, never keys. Release notes: version, patch level, settings,
   kernel source commit (GPL; from `source-state.xml`), "no regular updates". Update the file
   names in `docs/install-example.md` and the README section "Just want to try it?".

## 6. Android 17 watch fired

`update.sh` reports lineage-24.0 / 17.0 branches for camellia or an official crDroid 13. A port means:
`manifests/crdroid-17.0/`, branch variables in `lib.sh` (`CRDROID_BRANCH`, `LINEAGE_BRANCH`, `LUNCH_TARGET`
may change), re-check every patch, a new source tree (~250 GB). Main risk: kernel 4.14 and the
eBPF requirements of the newer Connectivity module. Treat it as a separate project; keep 16.0 working.

## 7. Editing checklist

- variables in `lib.sh` + `config.env.example`, docs updated, English, ASCII
- `bash -n`, `shellcheck -S warning -e SC1091,SC2034 scripts/*.sh scripts/dev/*.sh`
- PowerShell: parse with `[System.Management.Automation.Language.Parser]::ParseFile`; CRLF line endings
- dry runs where possible (`08-publish.sh -n`, `update.sh` check mode)
- `bash scripts/dev/privacy-check.sh` must print OK
