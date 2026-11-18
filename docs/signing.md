# Signing

Every Android build is signed. The signatures decide which updates the phone accepts and which
system apps get special rights.

## Which one?

| | test keys (`SIGNING=test`, **default**) | own keys (`SIGNING=own`, **recommended for daily use**) |
|---|---|---|
| effort | none | keys are created once, you must keep a backup |
| security | anybody can build packages your recovery accepts | only you can create accepted updates |
| apps / integrity checks | some apps treat "test-keys" builds as suspicious | no such hint |
| OTA updates from your server | work, but anybody on the way could inject a package | recommended |

> [!IMPORTANT]
> **Decide before the first installation.** Switching between test keys and own keys later (in either
> direction) requires **Format data** - everything on the phone is erased.

## Test keys (`SIGNING=test`, default)

Without own keys the build system signs with the AOSP test keys, whose **private keys are public**
(they are part of the Android source code). Many unofficial ROMs are distributed like this.
It works, but:

- the recovery accepts any update signed with these public keys - anybody can build one
- some apps and integrity checks treat "test-keys" builds as suspicious

This is the default because it works without any preparation - good for a first try. For a phone you
use every day, and especially with your own OTA server, switch to own keys **before** the first
installation. If you had own keys installed and go back to `SIGNING=test`, `bash scripts/05-keys.sh`
moves them aside (deletes nothing).

## Own keys (`SIGNING=own`, recommended)

Set `SIGNING="own"` in `config.env`. `scripts/05-keys.sh` (or `build-all.sh`) then creates your private release keys once, installs them into the source tree and
makes an encrypted backup. Each person who builds with this project has their own keys - nobody
else can create updates your phone would accept. I build my own phone with own keys.

- Keys are created **without** a password in `$WORK_DIR/keys` (needed for unattended builds).
  Protect that folder like a password.
- The encrypted backup lands in `$OUTPUT_DIR/key-backup/android-keys-<date>.tar.gz.gpg`.
  Copy it to a second place (USB stick) and keep the passphrase in a password manager.
  Restore: `gpg -d <file> | tar -xzf - -C "$WORK_DIR"`, then `bash scripts/05-keys.sh`.
- **Never** commit keys: `.gitignore` and `scripts/dev/privacy-check.sh` guard against it.
- The script never overwrites existing keys. `bash scripts/05-keys.sh --backup` creates a new backup.

> [!IMPORTANT]
> **If you lose your keys**, builds with new keys can only be installed with **Format data** -
> all data on the phone is lost. The same applies when switching between your builds and builds
> of other people.

### The Bluetooth trap

Android 16's Bluetooth module checks its app against its own certificate list, which defaults to the
AOSP *test* keys. With own keys the Bluetooth app then gets no SELinux domain and crashes
("Bluetooth keeps stopping"). `05-keys.sh` therefore adds

```make
PRODUCT_MAINLINE_BLUETOOTH_SEPOLICY_DEV_CERTIFICATES := $(dir $(PRODUCT_DEFAULT_DEV_CERTIFICATE))
```

to `keys.mk`. All other roles (platform, media, shared, networkstack, NFC, sdk sandbox) follow your
keys automatically.

### What is signed with what

APKs, the OTA package and the SELinux certificate lists use your keys. The APEX modules (system
components like ART, Bluetooth, Wi-Fi) keep their AOSP signing keys - fully re-signing them needs
`sign_target_files_apks` and is not part of this project. Everything works this way; it is just
less strict than a fully re-signed build.

## How do other ROMs do it?

Official LineageOS builds are signed with the LineageOS project's private keys. For other ROMs
and unofficial builds it varies; many use the test keys. The build fingerprint shown in the phone
settings often imitates the stock ROM, so it is not a reliable hint.
