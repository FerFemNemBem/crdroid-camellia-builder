# Installing the example build - complete guide

This page takes you from a phone with stock MIUI to the ready-made **example build** from the
[Releases](https://github.com/FerFemNemBem/crdroid-camellia-builder/releases) page - for Windows and
Linux. If you build the ROM yourself, use [flash.md](flash.md) instead.

> [!WARNING]
> **No warranty. Use at your own risk.** Unlocking the bootloader and the installation **erase
> everything on the phone**. Back up your photos, files and chats first.
> **Never re-lock the bootloader** while a custom ROM is installed - the phone would no longer boot.

> [!NOTE]
> The example build is a snapshot: crDroid 12.14 (Android 16), security patch November 2026, built
> with this guide and the default settings (public test keys, ViPER4AndroidFX, Widevine L3). It gets
> **no regular updates**. See [What has been tested](../README.md#what-has-been-tested) and the
> known problems (Netflix does not work, Disney+ & co. only in SD).

## Overview

| step | what | time |
|---|---|---|
| 1 | check the phone model and firmware | 2 min |
| 2 | unlock the bootloader | 7 days waiting, then 5 min |
| 3 | install adb/fastboot on the PC | 5 min |
| 4 | download and check the release files | 5 min |
| 5 | install | 15 min |
| 6 | first start | 5 min |

## 1. Check model and firmware

On the phone: *Settings -> About phone*.

- **Model**: the build is made for **Redmi Note 10 5G, Redmi Note 10T 5G, Redmi Note 11 SE and
  POCO M3 Pro 5G** (camellia / camellian). I have only tested **M2103K19G** (Redmi Note 10 5G Global).
- **MIUI version** must be **MIUI 14** (Android 13). Recommended: **MIUI 14.0.6.0 Global**, the
  version the vendor files of the build come from. **HyperOS is not supported.** Other MIUI 14
  versions should work too (my phone first ran EEA 14.0.4.0). How to install 14.0.6.0 Global:
  [flash.md -> Firmware](flash.md#firmware-miui-14060-global) (needs step 3 first).

## 2. Unlock the bootloader

Already unlocked? Then the phone shows "Unlocked" on the boot screen - skip to step 3.

### Windows (official way - this is how I did it)

1. Create a **Xiaomi account** (if you do not have one) and sign in on the phone.
2. Enable the developer options: *Settings -> About phone*, tap **MIUI version** seven times.
3. *Settings -> Additional settings -> Developer options*: enable **OEM unlocking** and **USB
   debugging**, then open **Mi Unlock status** and **Add account and device**. Xiaomi may ask you to
   use mobile data (a SIM card) for this step.
4. **Wait.** Xiaomi enforces a waiting period - for me it was **7 days (168 hours)**; depending on the
   account it can be shorter or longer. Do not sign out of the Xiaomi account and do not reset the
   phone during that time, otherwise the waiting period starts again.
5. Download **Mi Unlock** for Windows **only from Xiaomi**: <https://en.miui.com/unlock/>
   (copies on other download sites are often bundled with malware). Unpack it and start
   `miflash_unlock.exe`, sign in with the same Xiaomi account.
6. Power off the phone, hold **Volume down + Power** until *FASTBOOT* appears, connect it by USB.
   If Mi Unlock does not find the phone, install the driver first (step 3, Windows, item 4).
7. Click **Unlock** and confirm. If the waiting time is not over yet, the tool tells you how long it
   still is. After unlocking, the phone erases itself and starts MIUI again.

### Linux (unofficial - hints only)

Xiaomi's Mi Unlock only exists for Windows. On Linux there are unofficial tools, for example
**MiUnlockTool** (<https://github.com/offici5l/MiUnlockTool>, Python, `pip install miunlock`).
The requirements and the waiting period are the same as above (steps 1-4). Another way is the
official Mi Unlock in a Windows virtual machine with USB passthrough.

> [!CAUTION]
> I have **not tested** the Linux way. These are only pointers - read the tool's own documentation,
> inform yourself and decide yourself whether you trust a third-party tool with your Xiaomi login.

## 3. Install adb and fastboot

Two small programs from Google (the *platform-tools*) talk to the phone over USB: `fastboot` in
fastboot mode, `adb` in the running system and in the recovery. Always use the **current official
version** - old ones often fail.

### Windows

1. Download *SDK Platform-Tools for Windows*: <https://developer.android.com/tools/releases/platform-tools>
2. Unpack the ZIP to `C:\platform-tools`.
3. Open **PowerShell** and make the tools available in that window:
   ```powershell
   $env:Path = "C:\platform-tools;$env:Path"
   adb version
   fastboot --version
   ```
4. Driver: if the phone in fastboot mode is not found later (`fastboot devices` shows nothing),
   open the *Device Manager*, right-click the unknown "Android" device and install the
   **Google USB Driver** (<https://developer.android.com/studio/run/win-usb>).

### Linux

```bash
cd ~ && curl -fLO https://dl.google.com/android/repository/platform-tools-latest-linux.zip
unzip -o platform-tools-latest-linux.zip            # creates ~/platform-tools
echo 'export PATH="$HOME/platform-tools:$PATH"' >> ~/.bashrc && . ~/.bashrc
sudo apt-get install -y android-sdk-platform-tools-common   # USB access without root (Debian/Ubuntu)
adb version
```

Unplug and replug the phone afterwards.

### Test the connection

With MIUI running and **USB debugging** enabled (step 2, item 3), connect the phone and run:

```
adb devices
```

Allow the prompt on the phone ("Allow USB debugging?"). The phone must be listed as `device`.

## 4. Download and check the release files

From the [Releases](https://github.com/FerFemNemBem/crdroid-camellia-builder/releases) page download
into one folder (below: your *Downloads* folder):

| file | what |
|---|---|
| `crDroidAndroid-16.0-20261118-camellia-v12.14.zip` | the ROM (1.3 GB) |
| `boot.img` | boot image with the recovery - must be from the **same** release |
| `sha256sums.txt` | checksums |

Optional, for Google apps (Play Store): `MindTheGapps-16.0.0-arm64-20261023_034858.zip` from
<https://github.com/MindTheGapps/16.0.0-arm64/releases> - not included in the release, it is
Google's software.

Check that the downloads are complete and unchanged:

**Windows (PowerShell):**
```powershell
cd $HOME\Downloads
Get-FileHash crDroidAndroid-16.0-20261118-camellia-v12.14.zip, boot.img -Algorithm SHA256 | Format-List
Get-Content sha256sums.txt
```
The `Hash` values must match the lines in `sha256sums.txt` (upper/lower case does not matter).

**Linux:**
```bash
cd ~/Downloads
sha256sum -c sha256sums.txt
```
Both lines must end with `OK`.

## 5. Install

Before you start:

- the battery is charged to **at least 50 %**
- on the phone: **remove your Google account** (*Settings -> Accounts*), otherwise the factory reset
  protection may ask for it after formatting
- USB debugging is on and `adb devices` shows the phone (step 3)
- PowerShell / terminal is open **in the download folder** (`cd $HOME\Downloads` or `cd ~/Downloads`)

Two different tools: **`boot.img` is flashed with `fastboot`**, the **ZIP files are installed with
`adb sideload`**. The commands are the same on Windows and Linux.

**5.1 Flash the boot image** (it contains the recovery):

```
adb reboot bootloader
fastboot flash boot boot.img
fastboot reboot recovery
```

If `adb reboot bootloader` does not work: power off, hold **Volume down + Power** for fastboot mode.
If `fastboot` waits forever on Windows ("waiting for any device"), install the driver (step 3, Windows, item 4).

**5.2 Erase the phone** - in the recovery (volume keys move, power selects, or tap):
**Factory reset -> Format data / factory reset**, confirm.

**5.3 Install the ROM** - in the recovery: **Apply update -> Apply from ADB**, then on the PC:

```
adb sideload crDroidAndroid-16.0-20261118-camellia-v12.14.zip
```

The PC may stop at **47 %** and report an error or success - both are normal, the phone shows the
real result. A warning that the package "will downgrade your system" can be accepted.

**5.4 Optional: Google apps** - in the recovery: **Advanced -> Reboot to recovery** (important: the
ROM was installed to the other slot), then **Apply update -> Apply from ADB** and:

```
adb sideload MindTheGapps-16.0.0-arm64-20261023_034858.zip
```

If the recovery warns about a signature, confirm with *Yes*.

**5.5 Start** - **Reboot system now**.

## 6. First start

The first start takes a few minutes. Then the setup wizard appears (with Google apps: sign in with
your Google account there). Things worth checking:

- *Settings -> About phone*: crDroid 12.14, Android 16, security patch November 2026
- the app *DRM Info* (Play Store) shows Widevine **L3** - that is intended, see the README
- *Settings -> System -> Updater* says *"The update check failed"* - expected, there is no update
  server for the example build

## Updates

The example build gets **no regular updates**. To stay current, build crDroid yourself with this
repository ([README](../README.md#quick-start)) - with the default **test keys** you can install your
own build over the example build **without erasing the phone** (sideload as described in
[flash.md -> Updating later](flash.md#updating-later), Google apps again in the same recovery session).

## If something goes wrong

Fastboot mode (*Volume down + Power*) is always reachable. Ways back - to the previous slot, to a
working build or to stock MIUI - are in [flash.md -> If something goes wrong](flash.md#if-something-goes-wrong).
