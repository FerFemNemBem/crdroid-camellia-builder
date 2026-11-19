# Staying up to date

crDroid releases roughly once a month, usually together with the monthly Android security patch.
The device tree and kernel receive fixes from time to time.

## Check

```bash
bash scripts/update.sh
```

Changes nothing. It compares your source tree with GitHub and prints, for every watched repository,
`=` (unchanged) or `NEW` with a link that shows exactly the new commits. Watched are the most
important crDroid repositories (manifest, version, build system, framework, settings, updater) and
every GitHub project of the local manifest (device tree, kernel, modules, ViPER).
Additionally it shows

- the crDroid version on GitHub vs. yours (e.g. `12.13` -> `12.14`)
- LineageOS commits crDroid has not merged yet (usually upcoming security fixes; information only)
- whether an **Android 17** device tree or an official crDroid 13 for camellia has appeared

A new crDroid version can also be spotted by hand: a commit "Bump to version" in
[crdroidandroid/android_vendor_crdroid](https://github.com/crdroidandroid/android_vendor_crdroid/commits/16.0).

## Build

```bash
tmux new -s update
bash scripts/update.sh build          # only if something is new
bash scripts/update.sh build --force  # always
```

Runs sync, prepare, build and - if `OTA_URL` and `OTA_UPLOAD` are set - publish. Afterwards install
the update with the updater on the phone, or sideload it ([flash.md](flash.md#updating-later)).

### On Windows: double-click

`scripts\windows\update.bat` starts the WSL distribution, runs the check, asks whether to build
and runs the build inside tmux. Keep the window open (minimizing is fine); if you close it by
accident, start it again - it re-attaches to the running build. Options for PowerShell:
`update.ps1 -Build`, `-Force`, `-Distro <name>`.

The distribution name is taken from `WSL_DISTRO` in `config.env`.

## When a patch no longer applies

Upstream projects change. If `06-prepare.sh` reports `!!! ... does not apply`, the latest sources
and the patches of this repository no longer match. Options:

1. wait for an update of this repository, or adapt the patch yourself
2. build the last **known-good** state (see below) - it builds reliably, but is not the newest

## Known-good states

Every release tag of this repository (e.g. `v1.0`) comes with `manifests/known-good/<tag>.xml`:
the exact revision of every project of a build that I installed and tested on my phone.

```bash
git checkout v1.0                         # scripts and patches of that release
bash scripts/04-sync.sh --known-good v1.0 # exactly the sources of that release
bash scripts/06-prepare.sh && bash scripts/07-build.sh
```

`update.sh build` always switches back to the latest state.
