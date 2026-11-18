# Troubleshooting

Logs: `$OUTPUT_DIR/logs/<step>.log`. Search them for `FAILED:`, `error:` or `!!!`.

## Downloads

**The stock ROM download is very slow** - `03-download.sh` already picks the fastest Xiaomi mirror
(see the measured speeds in `$OUTPUT_DIR/logs/03-download.log`). If all are slow, try again later
(evenings are often busy) or set your own mirror list with `STOCK_MIRRORS` in `config.env`.
Interrupting is safe: running the script again resumes the download.

## Sync

**`429 Too Many Requests` / `RESOURCE_EXHAUSTED`** - the Google/GitHub servers limit downloads.
`04-sync.sh` waits and retries five times. Lower `SYNC_JOBS` (e.g. 4) if it keeps happening, or try
later.

**`remove-project ... not found`** - your `repo` tool is too old for `optional="true"`. `repo` updates
itself on the next sync; or reinstall it with `scripts/01-setup-host.sh`.

**The progress shows "51h left" (or similar)** - normal in the first minutes; the estimate settles
once more data has been processed.

## Prepare

**`!!! ... does not apply`** - upstream changed the code a patch touches. See
[updates.md](updates.md#when-a-patch-no-longer-applies).

**`stock ROM missing or not verified`** - run `scripts/03-download.sh`. If the checksum keeps failing,
delete the ZIP in `$OUTPUT_DIR/downloads` and download again.

**`wifi.cfg: SapCheckPmkidInDriver 2x instead of 1x`** - should not happen anymore (the file is
removed before extraction); run `06-prepare.sh` again.

## Build

**Killed / out of memory / the PC freezes** - not enough RAM. On WSL raise `memory=` and `swap=`
in `.wslconfig` (then `wsl --shutdown`), or lower `JOBS` in `config.env`.

**Build fails in `CellBroadcastReceiver` (CellBroadcastMetrics constants missing)** - the LineageOS
CellBroadcastService fork is missing; make sure `.repo/local_manifests/camellia.xml` is the one from
this repository and sync again.

**Disk full** - the tree needs ~300 GB.

**WSL: deleted files, but the disk file on Windows stays big** - the virtual disk (`ext4.vhdx`) grows
automatically but does not shrink by itself. Automatic reclaiming for "sparse" disks is still
experimental in WSL and often does nothing. Reliable way (PowerShell **as administrator**;
`wsl --shutdown` stops **all** WSL distributions):

```powershell
wsl -d <distribution> -- sudo fstrim -av
wsl --shutdown
wsl --manage <distribution> --set-sparse false
diskpart
```
```
select vdisk file="<folder>\ext4.vhdx"
attach vdisk readonly
compact vdisk
detach vdisk
exit
```
`compact vdisk` takes up to half an hour for a large disk. diskpart refuses sparse files ("must not be
set as sparse"), hence switching it off first. **Leave sparse switched off afterwards**: the author's
disk was damaged shortly after switching it back on (see the next entry), and Microsoft itself had
disabled sparse disks for a while because of data loss. Compact by hand when needed instead.

**Build fails with syntax errors in files that are fine on GitHub, or git reports `index file corrupt`,
`bad signature 0x00000000`, `bad shallow line`** - the ext4 file system inside the WSL disk lost
writes, typically after the WSL VM was stopped hard (crash, forced shutdown, sleep during a build).
Files that were written shortly before are cut off or full of zeros. `dmesg | grep EXT4-fs` shows
errors and "Remounting filesystem read-only". Repair it from **another** distribution (PowerShell as
administrator; `wsl --shutdown` stops all distributions):

```powershell
wsl --shutdown
wsl --manage <distribution> --set-sparse false
wsl --mount --vhd "<folder>\ext4.vhdx" --bare
wsl -d <other distribution>
```
```bash
lsblk -o NAME,SIZE,MOUNTPOINT          # the disk of the right size WITHOUT mount point
sudo e2fsck -f -y -D /dev/sdX
exit
```
```powershell
wsl --unmount "<folder>\ext4.vhdx"
```

e2fsck repairs the structure, not file contents. Afterwards, in the damaged distribution, repair the
source tree and throw away the build output (it may contain zeroed files that end up in the image
unnoticed; ccache checks its own entries and can stay):

```bash
cd "$WORK_DIR/crdroid"            # your WORK_DIR from config.env
repo list -p | while read -r p; do
  g=$(git -C "$p" rev-parse --absolute-git-dir 2>/dev/null) || { echo "BROKEN: $p"; continue; }
  rm -f "$g/index.lock"
  git -C "$p" status >/dev/null 2>&1 || { rm -f "$g/index"; git -C "$p" reset -q 2>/dev/null || { echo "BROKEN: $p"; continue; }; }
  git -C "$p" ls-tree -r HEAD >/dev/null 2>&1 || { echo "BROKEN: $p"; continue; }
  git -C "$p" checkout -q -- .
done
rm -rf out
```
Projects listed as `BROKEN` (usually a zeroed `.git/shallow`): delete them and fetch them again with
`rm -rf <path> .repo/projects/<path>.git` and `repo sync -c -d --force-sync <path>`. Then run the
build again; `06` re-applies all patches. Signing keys live outside the source tree - check them with
`openssl x509 -noout -in <key>.x509.pem` and restore from your backup if needed.

## Phone

**"Bluetooth keeps stopping", the switch flips back** - own keys without the Bluetooth line in
`keys.mk`. Run `bash scripts/05-keys.sh` (adds it), rebuild, install. Details: [signing.md](signing.md).
Check with `adb logcat | grep "No match for app"` - no output means every system app got its
SELinux domain.

**Disney+ (or another DRM video app) shows "something went wrong" when playing** - the MediaTek
secure video path does not work with the source-built kernel (details in the README, "Known
problems"). Workaround: set `WIDEVINE_L3=true` in `config.env`, rebuild and install the update.
Widevine then reports L3 (check with the app *DRM Info*) and videos play in SD. Some apps remember
the old security level - clear their app data once. Expected in *DRM Info*: Security Level L3, a different
system ID, Max HDCP Level "None". Set it back to `false` when the kernel is fixed.

**Updater still shows the installed build as "download complete" and offers to install it again** -
the updater keeps downloaded files until they are deleted. Harmless; delete the entry in the updater
to free the space (about 1.3 GB). Installing it again would just rewrite the same version.

**GitHub answers `429 Too Many Requests`** - many syncs and API checks in a short time. Wait an hour
and run the step again. The build itself does not depend on it: all patches are in this repository.

**ViPER app missing** - `WITH_VIPER=false`, or `packages/apps/ViPER4AndroidFX` was not synced
(the build stops with an error in that case). Sync again.

**Sideload stops at 47 %** - normal. The phone shows the real result.

**Updater finds nothing** - the installed build is the newest (expected), `os_sdk_level` is missing
in the JSON (use `08-publish.sh`), the URL in the build differs from `OTA_URL` (build and install
once more), or the phone cannot reach the server (open the JSON URL in the phone's browser).

**Phone does not boot after an update** - after a few failed attempts it switches back to the
previous slot. Otherwise see [flash.md](flash.md#if-something-goes-wrong).

## Collecting a log from the phone

```
adb logcat -b all -c
(reproduce the problem)
adb logcat -b all -d > logcat.txt
```
