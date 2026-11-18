# crdroid-camellia-builder

Build **crDroid 12 (Android 16)** yourself for the **Redmi Note 10 5G / POCO M3 Pro 5G**
(codename `camellia` / `camellian`, MediaTek Dimensity 700) - on Ubuntu 24.04 or Windows with WSL2,
step by step, optionally signed with your own keys and with updates from your own OTA server.

> [!WARNING]
> **No warranty. Use at your own risk.**
> Flashing a custom ROM can erase all your data and, if something goes wrong, can leave your phone
> unable to boot. You alone are responsible for your device.
>
> This project is meant as a **test base for your own builds and experiments**. The author does
> **not** use the phone as a daily driver - only as a test device.
>
> This project has only been tested **rudimentarily, on a single phone (M2103K19G) without a SIM card**.
> See [What has been tested](#what-has-been-tested). There is **no support** - please do not expect
> answers to questions or issues. Discussions among users are welcome.

## Credits

This project stands on the shoulders of others - without their work it would not exist:

- **[dm700-devs](https://github.com/dm700-devs/device_xiaomi_camellia)** - the original camellia
  device tree everything is based on (power HAL, SELinux policy, init files, overlays, build scaffolding)
- **[cristidclxvi](https://github.com/cristidclxvi)** - the Android 16 port: the patches that let
  Android 16 run on the 4.14 kernel, one build for all models, hardware fixes, kernel and kernel modules
- **Sushrut1101** (dm700-devs) - chose the "gold" connectivity firmware back in 2023
- **[fieldmar](https://github.com/fieldmar/android_device_xiaomi_camellia)** - the VoLTE fix and
  restoring the gold firmware, which also fixes the Bluetooth headset microphone
- **MiCode** (Xiaomi) - the camellia kernel source drop
- **[crDroid](https://github.com/crdroidandroid)** and **[LineageOS](https://github.com/LineageOS)** -
  the ROM itself
- **[TogoFire](https://github.com/TogoFire/packages_apps_ViPER4AndroidFX)** - ViPER4AndroidFX
  integration, **[MindTheGapps](https://github.com/MindTheGapps)** - the optional Google apps

Details in [NOTICE](NOTICE).

If you only want a ready LineageOS build with these fixes rather than building crDroid yourself,
look at fieldmar's releases: <https://github.com/fieldmar/android_device_xiaomi_camellia/releases>.

> [!NOTE]
> This project was created together with **Claude**, an AI assistant by Anthropic - from finding the
> required fixes to writing the scripts and this documentation. Commits carry a `Co-Authored-By: Claude` line.

## What you get

- crDroid 12.x (Android 16, based on LineageOS 23.2), built from source on your own computer
- signed with the public test keys (default, nothing to manage) or with **your own release keys** (one setting, recommended for daily use)
- optional: **ViPER4AndroidFX** audio effects (on by default)
- optional: OTA updates from **your own web server** through the built-in crDroid updater
- one command (or one double-click on Windows) to check for upstream changes and rebuild

What you do **not** get: a ready-made ROM. This repository only contains scripts, a manifest and
patches. All source code, the proprietary vendor files and the optional Google apps are downloaded
from their original sources while you build.

## What has been tested

On one Redmi Note 10 5G Global (M2103K19G), used **without a SIM card**, WLAN only:

| Works | Not tested |
|---|---|
| WLAN, Bluetooth audio (pairing, music, pause/resume) | phone calls, SMS, mobile data, VoLTE, dual SIM |
| audio, local video playback, Spotify, Disney+ (in SD, see below) | camera (beyond a quick look), NFC, GPS |
| display, fingerprint sensor | other models / variants (see [requirements](docs/requirements.md)) |
| ViPER4AndroidFX, OTA updates from an own server | long-term battery life |

**Known problems:**
- **Widevine L1 / HD streaming**: with Widevine L1, Disney+ refuses playback ("something went wrong"): the licence is obtained (Widevine L1 works,
  HDCP 2.3), but the MediaTek *secure video path* fails - the protected memory in the TEE
  (GenieZone/MTEE) cannot be set up, so the secure video decoder stops. Stock MIUI with the same
  firmware (and an unlocked bootloader) plays fine, so the cause is on the kernel side, not the
  firmware. Reported upstream / under investigation. **Therefore the build uses Widevine L3 by
  default** (`WIDEVINE_L3=true` in `config.env`): Disney+ and similar apps play, but only in SD
  (tested with crDroid 12.14: DRM Info shows L3, HDCP "None", Disney+ plays). Set it to `false`
  once the kernel is fixed.
- **Netflix** refuses the login. The app queries Google's Play Integrity, and a phone with an
  unlocked bootloader only passes *basic integrity*, not *device integrity* - this part affects
  practically every custom ROM.
- Apps without these requirements work (tested: Spotify).

## Requirements in short

- a PC with **8+ CPU threads (16 recommended), 32+ GB RAM (64 recommended), ~400 GB free SSD space**
- **Ubuntu 24.04** (native) or **Windows 10/11 with WSL2**
- a phone with an **unlocked bootloader** and **MIUI 14 firmware**
- patience: the first download takes 1-3 hours, the first build 2-4 hours

**For reference, the author's numbers** (one PC: 16 threads, 62 GB RAM of which 50 GB for WSL2,
SATA SSD, a 250-400 Mbit/s download rate during the sync):

| | time | disk space |
|---|---|---|
| first download of the sources | 45-75 min | 125-150 GB |
| first build, empty compiler cache | **4 h 14 min** | |
| everything after the first build (sources, build output, cache) | | **about 280 GB** |
| later builds (cache warm, few changes) | 7-15 min | +1.3 GB per finished build |

So: plan for **350-400 GB of free disk space, a fast internet connection and a fast computer**.
With less RAM, fewer threads or a hard disk, everything takes considerably longer.

Details: [docs/requirements.md](docs/requirements.md)

## Quick start

After the one-time setup ([docs/setup.md](docs/setup.md): WSL or Ubuntu, `scripts/01-setup-host.sh`,
optionally `config.env`) **one command does everything**:

```bash
bash scripts/build-all.sh        # Windows: double-click scripts\windows\build-all.bat
```

**Then wait about 4-7 hours** (first time; author's PC: about 5.5 hours) - no need to watch it.
With the default test keys it asks nothing (with own keys: a backup passphrase at the start), then runs checks, downloads, sync, keys,
preparation and build unattended for several hours inside tmux, with a status bar showing the
current step, elapsed time and disk usage. Close the window any time - it keeps running; start it
again to see it or to resume after an interruption.

**Alternatively, step by step** - if you prefer to run each step yourself instead of `build-all.sh`
(details in [docs/build.md](docs/build.md)):

```bash
git clone https://github.com/FerFemNemBem/crdroid-camellia-builder.git
cd crdroid-camellia-builder
cp config.env.example config.env     # optional: adjust paths and options
bash scripts/01-setup-host.sh        # packages, repo tool, ccache   (once)
bash scripts/02-check-host.sh        # is this computer ready?
bash scripts/03-download.sh          # stock ROM for the vendor files (+ GApps if enabled)
tmux new -s build                    # recommended for the long steps
bash scripts/04-sync.sh              # source code, ~150 GB         (1-3 h)
bash scripts/05-keys.sh              # own signing keys - only with SIGNING=own
bash scripts/06-prepare.sh           # patches, firmware, vendor files
bash scripts/07-build.sh             # build                        (2-4 h the first time)
```

Then flash it: [docs/flash.md](docs/flash.md). Later updates: `bash scripts/update.sh` -
see [docs/updates.md](docs/updates.md).

On Windows, start with [docs/setup.md](docs/setup.md) (creating the WSL distribution).

## Documentation

| | |
|---|---|
| [requirements.md](docs/requirements.md) | hardware, phone models, firmware, bootloader |
| [setup.md](docs/setup.md) | preparing Ubuntu or WSL2 |
| [build.md](docs/build.md) | the build, step by step |
| [flash.md](docs/flash.md) | installing the ROM, GApps, rescue |
| [updates.md](docs/updates.md) | staying up to date, known-good states |
| [signing.md](docs/signing.md) | own keys vs. test keys, backups |
| [ota-server.md](docs/ota-server.md) | optional: updates from your own server |
| [how-it-works.md](docs/how-it-works.md) | what the manifest and every patch do and why |
| [troubleshooting.md](docs/troubleshooting.md) | known problems and their solutions |

## Working on it with Claude

The repository contains notes for the AI assistant Claude, so you can continue where this project
left off - debugging a failed build, adapting a patch after an upstream change, analysing a phone
log or preparing a new release:

- [`CLAUDE.md`](CLAUDE.md) - project overview and hard rules (Claude Code reads it automatically)
- [`.claude/skills/crdroid-camellia-builder/SKILL.md`](.claude/skills/crdroid-camellia-builder/SKILL.md) -
  the known pitfalls with their fixes and step-by-step procedures for maintenance

Open the repository with [Claude Code](https://claude.com/claude-code) and describe your problem.
Without Claude these files are still a readable summary of everything learned while building this.

## Configuration

Everything that differs between computers lives in `config.env` (copy of
[config.env.example](config.env.example), ignored by git): directories, number of jobs, ViPER and
GApps switches, signing mode, OTA server. Without a `config.env` sensible defaults are used.

## License

[Apache License 2.0](LICENSE). This project is not affiliated with crDroid, LineageOS or Xiaomi.
