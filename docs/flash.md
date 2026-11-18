# Installing the ROM

> [!WARNING]
> The first installation **erases everything on the phone** (Format data). Back up your data.
> Never re-lock the bootloader (see [requirements.md](requirements.md)).

## platform-tools: adb and fastboot

Flashing is done from your PC over USB with two small programs from Google, the **platform-tools**:

| tool | talks to the phone when it is ... | used for |
|---|---|---|
| `adb` | running Android (USB debugging on) or in the recovery | rebooting into bootloader/recovery, *sideloading* the ROM ZIP, reading logs |
| `fastboot` | in fastboot mode (*Volume down + Power*) | flashing `boot.img`, switching A/B slots |

Always use the **current official version** - old versions (e.g. from Linux package managers or
random download sites) often fail with sideloading or with A/B devices.

### Windows

1. Download *SDK Platform-Tools for Windows* from Google:
   <https://developer.android.com/tools/releases/platform-tools>
2. Unpack the ZIP, for example to `C:\platform-tools` (the folder then contains `adb.exe` and `fastboot.exe`).
3. Make the tools available in a PowerShell window (only for this window):
   ```powershell
   $env:Path = "C:\platform-tools;$env:Path"
   adb version
   fastboot --version
   ```
   To make it permanent, add `C:\platform-tools` to *Path* in *System -> About -> Advanced system
   settings -> Environment variables*.
4. Drivers: `adb` usually works without extra drivers on Windows 10/11. If `fastboot devices` shows
   nothing while the phone is in fastboot mode, open the *Device Manager*, find the unknown
   "Android" device and install the **Google USB Driver**
   (<https://developer.android.com/studio/run/win-usb>) for it ("Android Bootloader Interface").

> [!NOTE]
> **Using WSL?** Flash from **Windows**, not from inside WSL - WSL cannot see USB devices without
> extra tools. That is why it is convenient to set `OUTPUT_DIR` to a Windows drive (e.g.
> `/mnt/d/crdroid` = `D:\crdroid`): the finished builds are then directly reachable from PowerShell.
> Otherwise they are under `\\wsl.localhost\<distribution>\home\<user>\crdroid-out\builds`.

### Linux

```bash
cd ~ && curl -fLO https://dl.google.com/android/repository/platform-tools-latest-linux.zip
unzip -o platform-tools-latest-linux.zip            # creates ~/platform-tools
echo 'export PATH="$HOME/platform-tools:$PATH"' >> ~/.bashrc && . ~/.bashrc
sudo apt-get install -y android-sdk-platform-tools-common   # udev rules: USB access without root
adb version
```

Unplug and replug the phone after installing the udev rules.

### Test the connection

1. On the phone enable the developer options: *Settings -> About phone*, tap **MIUI version** (or
   *Build number* on a custom ROM) seven times.
2. In *Settings -> Additional settings -> Developer options* (custom ROM: *System -> Developer
   options*) enable **USB debugging**.
3. Connect the phone with a USB cable that supports data, then on the PC:
   ```
   adb devices
   ```
   Confirm the prompt on the phone ("Allow USB debugging?"). The device must be listed as `device`
   (not `unauthorized`).

## Firmware: MIUI 14.0.6.0 Global

Recommended once before the first installation (see [requirements.md](requirements.md#firmware)).
It flashes the complete stock MIUI and **erases everything** on the phone; the bootloader stays
unlocked.

1. Download the official fastboot ROM (5.7 GB):
   `camellian_global_images_V14.0.6.0.TKSMIXM_20230919.0000.00_13.0_global_f43e2310b3.tgz`
   from a Xiaomi mirror, for example
   `https://bkt-sgp-miui-ota-update-alisgp.oss-ap-southeast-1.aliyuncs.com/V14.0.6.0.TKSMIXM/<file name>`
   (alternatives: `cdnorg.d.miui.com`, `bigota.d.miui.com` - speeds differ a lot, try another one if
   it crawls). The MD5 checksum must start with `f43e2310b3` (the part in the file name).
2. Unpack it, e.g. in PowerShell: `tar -xf camellian_global_images_V14.0.6.0*.tgz`.
3. Bring the phone into fastboot mode. If Android with USB debugging is running (any ROM):
   `adb reboot bootloader` - otherwise power off and hold *Volume down + Power*. Check with
   `fastboot devices`.
4. Flash. Xiaomi's `flash_all.bat` ends with a reboot into MIUI; without that last line the phone
   stays in fastboot mode and you can continue with the first installation right away - no MIUI
   start, no buttons. In PowerShell, in the unpacked folder:

   ```powershell
   (Get-Content flash_all.bat) | Where-Object { $_ -notmatch '^fastboot %\* reboot' } | Set-Content flash_all_noreboot.bat
   Select-String -Path flash_all_noreboot.bat -Pattern 'reboot|lock'    # must print NOTHING
   .\flash_all_noreboot.bat
   ```

   (Linux: run `flash_all.sh` without its last `reboot` line the same way.)
   > [!CAUTION]
   > **Never `flash_all_lock.bat`** - it re-locks the bootloader. Mi Flash: only "clean all",
   > never "clean all and lock".
5. Takes 5-10 minutes. The phone stays in fastboot mode: continue with
   [First installation](#first-installation), step 1, **from `fastboot flash boot boot.img`** on
   (it is already in the bootloader). If you used the original `flash_all.bat`, the phone starts
   MIUI instead (the first start is slow); then use the buttons to get back into fastboot mode,
   because fresh MIUI has USB debugging switched off.

camellia has no anti-rollback protection, so switching between MIUI 14 versions is safe.

## Before you start

- bootloader unlocked, MIUI 14 firmware on the phone ([requirements.md](requirements.md))
- platform-tools installed and `adb devices` shows the phone (see above)
- if the phone is signed into a Google account: **remove the account** in the phone's settings first,
  otherwise the factory reset protection may ask for it after formatting
- battery charged to at least 50 %
- open the terminal / PowerShell **in the build folder**, so the commands below work as they are.
  The folder is `<OUTPUT_DIR>/builds/<date>-<time>`, the Google apps are in `<OUTPUT_DIR>/downloads`.
  Example with `OUTPUT_DIR="/mnt/d/crdroid"`:

  ```powershell
  cd D:\crdroid\builds\20261118-1919          # Windows (PowerShell)
  ```
  ```bash
  cd /mnt/d/crdroid/builds/20261118-1919         # Linux / WSL path of the same folder
  ```

> [!TIP]
> Only want the ready-made example build from the Releases page? Follow
> [install-example.md](install-example.md) instead - it covers everything from unlocking the bootloader.

## First installation

Two different tools are used: **`boot.img` is flashed with `fastboot`** (step 1), the **ZIP files
are installed with `adb sideload`** from the recovery (steps 3 and 4). Do not sideload `boot.img`.

1. Reboot into the bootloader and flash the boot image (it contains the recovery):

   ```
   adb reboot bootloader
   fastboot flash boot boot.img
   fastboot reboot recovery
   ```

   `adb reboot bootloader` needs USB debugging in the running system. Without it (fresh MIUI, a
   phone that does not boot): power off, hold *Volume down + Power* for fastboot mode.
2. In the recovery: **Factory reset -> Format data / factory reset**, confirm.
3. **Apply update -> Apply from ADB**, then on the PC:

   ```
   adb sideload crDroidAndroid-16.0-20261118-camellia-v12.14.zip
   ```
   (use the exact file name from your build folder - the `Tab` key completes it)

   The PC may stop at **47 %** and report an error or success - both are normal; the phone shows
   whether the installation finished. A warning that the package "will downgrade your system" can
   be accepted: recovery compares against a build date it does not know.
4. Optional, Google apps: **Advanced -> Reboot to recovery** (important: the system was installed
   to the other slot), then **Apply update -> Apply from ADB** and

   ```
   adb sideload ../../downloads/MindTheGapps-16.0.0-arm64-20261023_034858.zip
   ```

   `03-download.sh` already downloaded it to `<OUTPUT_DIR>/downloads/` (default `WITH_GAPPS=true`);
   `../../downloads/` points there from the build folder (works in PowerShell and Linux). Again,
   use your exact file name.

   If the recovery warns about a signature, confirm with *Yes*.
5. **Reboot system now**. The first start takes a few minutes.

Without an own OTA server (`OTA_URL` empty) the updater later says *"The update check failed"* -
that is expected: camellia has no official crDroid builds, so there is nothing to check against.

## Updating later

- with your own OTA server: on the phone *Settings -> System -> Updater -> check for updates*;
  data stays ([ota-server.md](ota-server.md))
- without: same as above, but **without Format data**: boot into recovery
  (`adb reboot recovery`), *Apply update -> Apply from ADB*, sideload the new ZIP, reboot.
  This only works for builds signed with the **same keys**.
  **If you use GApps, sideload MindTheGapps again in the same recovery session, before rebooting**:
  an update replaces the whole system and the Google apps live there, not in your data. If you
  rebooted first and the Play Store crashes, go back to recovery and sideload them - no format needed.

Switching from another ROM (or from builds with other keys) always requires Format data.

## If something goes wrong

The phone keeps two system slots (A/B). Fastboot mode (*Volume down + Power*) is always reachable
because this guide never flashes the preloader or firmware.

1. **Back to the previous system** (data stays):
   ```
   fastboot getvar current-slot
   fastboot set_active a      # or b - the other one
   fastboot reboot
   ```
2. **Flash a working build again**: `fastboot flash boot boot.img` of that build, recovery, sideload its ZIP.
3. **Back to MIUI**: download the official *fastboot* ROM (MIUI 14) for your variant and run
   `flash_all.bat` (**never** `flash_all_lock.bat`), or Mi Flash with **"clean all"**
   (**never** "clean all and lock").
