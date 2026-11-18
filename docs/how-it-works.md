# How it works

crDroid 12 is based on LineageOS 23.2 (Android 16). Neither knows the camellia hardware;
that comes from the **device tree**, **kernel** and **kernel modules** maintained by
[cristidclxvi](https://github.com/cristidclxvi), who ported the original camellia device tree of
[dm700-devs](https://github.com/dm700-devs/device_xiaomi_camellia) to Android 16. Android 16 officially needs a newer kernel than
camellia's 4.14 - the device tree therefore ships patches that adapt parts of Android to the old
kernel. This builder adds the parts needed to build all of that as crDroid.

## Local manifest (`manifests/crdroid-16.0/camellia.xml`)

| project | why |
|---|---|
| `cristidclxvi/android_device_xiaomi_camellia` | device tree: partitions, HALs, SELinux, the list of proprietary files, the 7 required patches |
| `cristidclxvi/android_kernel_xiaomi_camellia` | kernel 4.14 with backports |
| `cristidclxvi/android_kernel_modules_xiaomi_camellia` | Wi-Fi, Bluetooth and other drivers for that kernel |
| `LineageOS/android_hardware_mediatek`, `_device_mediatek_sepolicy_vndr`, `_hardware_xiaomi` | shared MediaTek / Xiaomi code |
| `cristidclxvi/android_vendor_mediatek_ims` | MediaTek IMS (VoLTE), pinned to a known commit |
| AOSP `prebuilts/clang/host/linux-x86` at `android-12.1.0_r27` | clang r383902, the compiler the kernel needs |
| 7 LineageOS forks (CellBroadcastService, Telephony, Iwlan, NeuralNetworks, keymint, aac, tremolo) | crDroid 16.0 still used the plain AOSP versions while LineageOS 23.2 carries forks with fixes; without the CellBroadcastService fork the build fails. Removed with `optional="true"`, so nothing breaks once crDroid forks them itself (`update.sh` reports that). Since crDroid 12.14 crDroid ships the hplip and broadcom wlan forks itself, so those two were dropped here. |
| `TogoFire/packages_apps_ViPER4AndroidFX` | ViPER4AndroidFX |

## Patches

Applied by `scripts/06-prepare.sh`, idempotently (already applied ones are detected).

### `patches/device/` - on the device tree

| patch | what |
|---|---|
| `0001-camellia-disable-ViLTE-...` | by fieldmar (pull request #7): disables ViLTE so that the modem brings up IMS - fixes VoLTE |
| `0002-camellia-ship-the-gold-connectivity-firmware` | by fieldmar (pull request #8): restores the "gold" Bluetooth/Wi-Fi firmware set (chosen by Sushrut1101 of dm700-devs in 2023 and shipped by crDroid 14, lost in the move to Android 16); fixes music dropping after a pause and the silent headset microphone |
| `0003-camellia-include-ViPER4AndroidFX` | builds ViPER, registers its audio effect, SELinux `execmem` for the audio HAL; skipped with `WITH_VIPER=false` |
| `0004-camellia-leave-out-liboemcrypto-Widevine-L3` | on by default (`WIDEVINE_L3=true`, switch off with `false`): leaves `liboemcrypto.so` out of the vendor files, so Widevine cannot reach the TEE and falls back to L3. DRM video apps then use the normal decoder instead of the broken secure one and play in SD |

Optional patches follow their switch in both directions: switching one off and running
`06-prepare.sh` again removes it from the device tree (a commit "Remove: ...").

The pull requests are included as files so the build does not depend on them staying open on GitHub.
fieldmar's own branch (`camellian-23.2`) additionally carries a few stock modem files; they are not
part of this builder, which has only been tested without a SIM card.

### Required patches from the device tree

The device tree ships 7 patches for Android projects (Bluetooth sniff subrating, Connectivity on
kernel 4.14, FM radio, LiveDisplay, sensors, two Wi-Fi fixes). `06-prepare.sh` applies them.

### `patches/crdroid-16.0/` - replacements

`connectivity_android16_on_kernel414.patch` replaces the device tree's version: crDroid already
relaxed the 4.19/5.4 kernel checks in `packages/modules/Connectivity`, so those parts are dropped.
What remains: no abort on 4.14 in `NetBpfLoad.cpp`, no reboot loop in `netbpfload.35rc`, and
`SingleWriterBpfMap.java` tolerating `ENOTSUPP` for LPM_TRIE maps on pre-4.20 kernels.

## Other steps in `06-prepare.sh`

- **gold firmware**: the 8 `soc2_2_*` connectivity firmware files are not in the stock ROM; they are
  downloaded from crDroid's camellia vendor repository and checked against the SHA-1 values in the
  device tree's `proprietary-files.txt`.
- **vendor files**: `extract-files.py` extracts ~1300 proprietary files from the stock MIUI 14
  recovery ROM. `wifi.cfg` is removed first, otherwise its fixup line would be appended on every run.
- **updater**: only with `OTA_URL` (see [ota-server.md](ota-server.md)).
- **signing**: checks that own keys (with the Bluetooth line) are installed, or none with `SIGNING=test`.

## Source state

Right after every sync `04-sync.sh` saves `repo manifest -r` - the exact upstream revision of every
project, before our patches. `07-build.sh` copies it next to each build (`source-state.xml`) together
with the version of this repository (`build-info.txt`). Release tags of this repository carry such a
file as `manifests/known-good/<tag>.xml` ([updates.md](updates.md#known-good-states)).
