# Building

All commands run **in the repository folder**, in Ubuntu or in the WSL distribution - type `ccb`
first (shortcut installed by `01-setup-host.sh`). Logs of every step are written to `$OUTPUT_DIR/logs/`.

## The easy way: everything at once

```bash
bash scripts/build-all.sh          # Windows: double-click scripts\windows\build-all.bat
```

- with the default `SIGNING=test` it asks nothing at all; with `SIGNING=own` it asks at the start for
  a name for your key certificate (unless `KEY_SUBJECT` is set) and a passphrase for the key backup
- then runs steps 1-5 below (plus publishing if an OTA server is configured) without further questions
- runs inside **tmux** (session `crdroid-build`); the blue bar at the bottom shows
  `step 3/6: sync | step 0:12:34 | total 1:02:06 | disk +37 GB` and a spinner, updated every 5 seconds;
  above it you see the detailed output of the current step (download progress, build percentage
  and remaining time)
- close the window whenever you like - the build continues. `bash scripts/build-all.sh` (or the
  .bat) shows it again
- if a step fails it stops with the name of the log; fix the cause and start it again - finished
  long steps (sync, build) are skipped. `--restart` starts from scratch.

## The alternative: step by step

**Not needed if you used `build-all.sh`.** If you prefer to run and watch each step yourself, or
want to repeat a single step, run the scripts below one after another. `build-all.sh` does exactly
the same; the descriptions also explain what happens during the easy way.

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

## 3. Signing keys

```bash
bash scripts/05-keys.sh
```

With the default `SIGNING=test` this does nothing (the build uses the public test keys).
With `SIGNING=own` it creates your own release keys in `$WORK_DIR/keys`, installs them into the source tree and makes an
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
