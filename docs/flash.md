# Installing the ROM

> [!WARNING]
> The first installation **erases everything on the phone** (Format data). Back up your data.
> Never re-lock the bootloader (see [requirements.md](requirements.md)).

## Before you start

- bootloader unlocked, MIUI 14 firmware on the phone ([requirements.md](requirements.md))
- platform-tools (adb, fastboot) on your PC
- if the phone is signed into a Google account: **remove the account** in the phone's settings first,
  otherwise the factory reset protection may ask for it after formatting
- battery charged to at least 50 %

On Windows, open PowerShell in the build folder (e.g. `D:\crdroid\builds\20261116-1200`) and make the
platform-tools available for this window:

```powershell
$env:Path = "C:\path\to\platform-tools;$env:Path"
adb devices
```

(USB debugging must be enabled in the developer options of the current system and the PC confirmed
on the phone.)

## First installation

1. Reboot into the bootloader and flash the boot image (it contains the recovery):

   ```
   adb reboot bootloader
   fastboot flash boot boot.img
   fastboot reboot recovery
   ```

   (Or: power off, hold *Volume down + Power* for fastboot mode.)
2. In the recovery: **Factory reset -> Format data / factory reset**, confirm.
3. **Apply update -> Apply from ADB**, then on the PC:

   ```
   adb sideload crDroidAndroid-16.0-<date>-camellia-v12.xx.zip
   ```

   The PC may stop at **47 %** and report an error or success - both are normal; the phone shows
   whether the installation finished.
4. Optional, Google apps: **Advanced -> Reboot to recovery** (important: the system was installed
   to the other slot), then **Apply update -> Apply from ADB** and

   ```
   adb sideload MindTheGapps-16.0.0-arm64-<date>.zip
   ```

   If the recovery warns about a signature, confirm with *Yes*.
5. **Reboot system now**. The first start takes a few minutes.

## Updating later

- with your own OTA server: on the phone *Settings -> System -> Updater -> check for updates*;
  data stays ([ota-server.md](ota-server.md))
- without: same as above, but **without Format data**: boot into recovery
  (`adb reboot recovery`), *Apply update -> Apply from ADB*, sideload the new ZIP, reboot.
  This only works for builds signed with the **same keys**.

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
