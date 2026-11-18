# Requirements

## Computer

| | minimum | recommended |
|---|---|---|
| CPU | 8 threads | 16 threads or more |
| RAM | 32 GB | 64 GB |
| free disk space | ~350 GB for the source tree and cache, ~15 GB for the results | an SSD; a hard disk works but is very slow |
| operating system | Ubuntu 24.04 (native) | or Windows 10/11 with WSL2 |
| internet | the first download is about 100 GB | a stable connection |

Other Linux distributions may work but are not tested.

### Measured on my PC

16 CPU threads, 62 GB RAM (50 GB assigned to WSL2), SATA SSD, internet via a **100 Mbit/s DSL line**:

| step | time | disk space |
|---|---|---|
| first download of the sources (`04-sync.sh`) | 40-75 min (test run 18.11.2026: 42 min) | 125-150 GB |
| first build with an empty compiler cache (`07-build.sh`) | 4 h 14 min | |
| after the first build: sources + build output + cache | | about 280 GB |
| later builds | 7-15 min | +1.3 GB per finished build in `OUTPUT_DIR` |

Breakdown of the 280 GB: sources ~125 GB, build output (`out/`) ~125 GB, compiler cache 23 GB
(grows up to `CCACHE_SIZE`, default 50 GB). Add ~4 GB of downloads. On a slower computer, a hard
disk or a slower connection, multiply the times accordingly - and plan for 350-400 GB.

## Phone

The device tree covers **camellia / camellian**:
Redmi Note 10 5G, Redmi Note 10T 5G, Redmi Note 11 SE and POCO M3 Pro 5G (MediaTek Dimensity 700, MT6833).

> [!IMPORTANT]
> I have only tested **M2103K19G (Redmi Note 10 5G Global)**, and only without a SIM card.
> Other variants should work with the same build, but nobody has confirmed it yet - test results are welcome.

Find your model number in *Settings -> About phone -> All specs* or on the box. NFC models are
"camellian"; the ROM detects the variant itself.

### Firmware

The phone must run **MIUI 14 firmware (Android 13)**. The custom ROM only replaces the system;
modem, bootloader, TEE and other firmware stay as they are. Do not install HyperOS firmware - it is
not supported by this device tree.

**Recommended: MIUI V14.0.6.0 Global**, the version the vendor files of the build are extracted
from - firmware and vendor files then match. How to put it on the phone:
[flash.md -> Firmware](flash.md#firmware-miui-1406-global). My phone first ran the EEA V14.0.4.0
firmware - crDroid booted and worked with it too. I then switched to V14.0.6.0 Global, which my
current builds run on. Other MIUI 14 versions should also work, but I have not tried them.

### Unlocked bootloader

The bootloader must be unlocked. Xiaomi does this with its official **Mi Unlock** tool and a Xiaomi
account; depending on the account there is a waiting period of several days. This project does not
cover unlocking - search for a current guide for your model (XDA forums, the device's Telegram
groups).

> [!CAUTION]
> **Never re-lock the bootloader** while a custom ROM is installed. On this phone that leads to a
> device that no longer boots and can only be rescued with special tools. In Xiaomi's Mi Flash tool
> never use "clean all and lock", and never run `flash_all_lock.bat` or `fastboot oem lock` /
> `fastboot flashing lock`.

### Backups

Installing the ROM the first time requires **Format data**: everything on the phone, including
photos and internal storage, is erased. Back up what you need first.

## Tools on the PC

- **platform-tools** (adb and fastboot) from Google to flash the phone - what they are and how to
  install them: [flash.md](flash.md#platform-tools-adb-and-fastboot)
- everything needed for building is installed by `scripts/01-setup-host.sh`
- no account is needed; GitHub is only used anonymously
