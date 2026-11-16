# Building

All commands run in the repository folder, in Ubuntu or in the WSL distribution.
Logs of every step are written to `$OUTPUT_DIR/logs/`.

The long steps (sync, build) are best run inside **tmux**, so they keep running if the terminal
window closes:

```bash
tmux new -s build      # start a session
#  ... run the commands ...
#  detach: Ctrl+B, then D        re-attach later: tmux attach -t build
```

## 1. Download the stock ROM

```bash
bash scripts/03-download.sh
```

Downloads the official MIUI 14 Global recovery ROM (3.6 GB) from Xiaomi and verifies its checksum.
The build extracts the proprietary vendor files (drivers, firmware) from it - they are not allowed
to be redistributed, so everybody extracts them on their own computer. With `WITH_GAPPS=true` the latest
MindTheGapps for Android 16 is downloaded as well (for flashing, not for building).

## 2. Download the source code

```bash
bash scripts/04-sync.sh
```

Initializes crDroid 16.0 and adds the camellia parts from `manifests/crdroid-16.0/camellia.xml`
(device tree, kernel, LineageOS forks, ViPER). About 150 GB, 1-3 hours. If it stops with
`429` / `RESOURCE_EXHAUSTED` errors, the servers are rate limiting: the script waits and retries by
itself; you can also lower `SYNC_JOBS`. Interrupting with Ctrl+C and starting again is safe.

To build exactly the state of a tested release instead of the latest one, see
[updates.md](updates.md#known-good-states).

## 3. Create your signing keys (once)

```bash
bash scripts/05-keys.sh
```

Creates your own release keys in `$WORK_DIR/keys`, installs them into the source tree and makes an
**encrypted backup** in `$OUTPUT_DIR/key-backup` (you choose a passphrase). Copy that backup to a
second place. Read [signing.md](signing.md) - losing the keys has consequences.

## 4. Prepare the source tree

```bash
bash scripts/06-prepare.sh
```

Applies all patches, downloads the 8 connectivity firmware files, extracts the vendor files from the
stock ROM and - if configured - points the updater to your own server. It must end with
`Everything prepared`. Any line marked `!!!` is an error; see [troubleshooting.md](troubleshooting.md).
The script can be run again at any time.

## 5. Build

```bash
bash scripts/07-build.sh
```

The first build takes 2-4 hours. The result lands in `$OUTPUT_DIR/builds/<date-time>/`:

| file | |
|---|---|
| `crDroidAndroid-16.0-<date>-camellia-v12.xx.zip` | the ROM |
| `boot.img` | kernel + recovery, needed for the first installation |
| `sha256sums.txt` | checksums |
| `source-state.xml`, `device-tree.txt`, `build-info.txt` | exact source state, to rebuild it later |

Continue with [flash.md](flash.md).
