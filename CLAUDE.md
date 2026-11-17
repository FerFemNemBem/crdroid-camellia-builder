# crdroid-camellia-builder - notes for Claude

Scripts, a local manifest and patches to build **crDroid 12 (branch 16.0, Android 16, based on
LineageOS 23.2)** for the Xiaomi Redmi Note 10 5G / POCO M3 Pro 5G (`camellia`/`camellian`, MT6833,
kernel 4.14) on Ubuntu 24.04 or WSL2. User documentation is in `README.md` and `docs/` - read the
relevant page before answering, and point users to it instead of repeating it.

For debugging, maintenance and release work use the skill in
`.claude/skills/crdroid-camellia-builder/SKILL.md` (pitfalls, procedures, where to look).

## Hard rules

- **Never suggest re-locking the bootloader** (`fastboot oem lock`, `flashing lock`,
  `flash_all_lock.bat`, Mi Flash "clean all and lock"). It bricks this device with a custom ROM.
- **Never commit or print private keys** (`*.pk8`, `$WORK_DIR/keys`, key backups) or `config.env`.
  Run `bash scripts/dev/privacy-check.sh` before every commit (it is meant as the pre-commit hook).
- **No personal data in the repository**: no host names, IPs, user names, local paths, e-mail
  addresses other than GitHub noreply. Everything machine specific belongs in `config.env`.
- **Do not edit a script while it is running** - bash reads scripts piece by piece; a long running
  `build-all.sh`/`update.sh` would execute a mix of old and new code. Check the logs/tmux first.
- Flashing and "Format data" are the user's decision; explain consequences, never hide them.
- The project is tested only on M2103K19G without a SIM card - say so when it matters.

## Layout

| path | content |
|---|---|
| `scripts/lib.sh` | defaults, `config.env` loading, derived paths (`SRC`, `BUILDS_DIR`, `LOG_DIR` ...), helpers |
| `scripts/01..08-*.sh` | setup, check, download, sync, keys, prepare, build, publish |
| `scripts/build-all.sh` / `update.sh` | complete first build / update check and rebuild |
| `scripts/windows/` | PowerShell/batch wrappers for WSL |
| `manifests/crdroid-16.0/camellia.xml` | local manifest; `manifests/known-good/<tag>.xml` pinned states |
| `patches/device/` | `git am` patches for the device tree; `patches/crdroid-16.0/` replacements for device-tree patches |
| `docs/` | user documentation (English) |

## Defaults worth knowing

`SIGNING=test` (public AOSP test keys; `own` recommended for daily use/OTA, switching needs Format data),
`WITH_GAPPS=true` (MindTheGapps downloaded, never built in), `WITH_VIPER=true`, `OTA_URL` empty.
`config.env` may have Windows line endings / BOM - `lib.sh` strips them. Users on WSL start in
`/mnt/c/Users/<name>`; the alias `ccb` (written by `01-setup-host.sh`) jumps into the repository.

## Conventions

- English, ASCII only in scripts; bash with `set -uo pipefail` (or `-euo`), helpers from `lib.sh`.
- Every script must be idempotent: detect what is already done and skip it.
- No fixed paths or values - add a variable with a default to `lib.sh` and `config.env.example`.
- Check scripts with `bash -n` and `shellcheck -S warning -e SC1091,SC2034`.
- Logs: `$OUTPUT_DIR/logs/<script>.log` (default `~/crdroid-out/logs`).
