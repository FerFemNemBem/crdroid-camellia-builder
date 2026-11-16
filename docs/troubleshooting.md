# Troubleshooting

Logs: `$OUTPUT_DIR/logs/<step>.log`. Search them for `FAILED:`, `error:` or `!!!`.

## Sync

**`429 Too Many Requests` / `RESOURCE_EXHAUSTED`** - the Google/GitHub servers limit downloads.
`04-sync.sh` waits and retries five times. Lower `SYNC_JOBS` (e.g. 4) if it keeps happening, or try
later.

**`remove-project ... not found`** - your `repo` tool is too old for `optional="true"`. `repo` updates
itself on the next sync; or reinstall it with `scripts/01-setup-host.sh`.

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

**Disk full** - the tree needs ~300 GB. On WSL the virtual disk grows automatically; space freed
inside Linux returns to Windows after `sudo fstrim -av` (the distribution is created "sparse").

## Phone

**"Bluetooth keeps stopping", the switch flips back** - own keys without the Bluetooth line in
`keys.mk`. Run `bash scripts/05-keys.sh` (adds it), rebuild, install. Details: [signing.md](signing.md).
Check with `adb logcat | grep "No match for app"` - no output means every system app got its
SELinux domain.

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
