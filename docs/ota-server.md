# Optional: updates from your own server

With an OTA server the phone finds new builds itself: *Updater -> check for updates -> install*.
Data and settings stay. Without it you install every update by sideloading.

```
build PC  --rsync over SSH (key limited to rsync)-->  web server  --HTTP(S)-->  phone (crDroid updater)
```

Any always-on machine with a web server works: a Raspberry Pi, a NAS, a VPS.
Only static files are served; there is no server-side software.

## Layout on the server

```
<web root>/crdroid/camellia.json                    <- OTA_URL points here ({device} = camellia)
<web root>/crdroid/camellia/<crDroid ZIPs>          <- the last OTA_KEEP builds
```

## config.env

```bash
OTA_URL="https://ota.example.org/crdroid/{device}.json"   # must end with /{device}.json
OTA_UPLOAD="ota-server:crdroid"     # rsync target of the folder that contains camellia.json
OTA_KEEP=3
MAINTAINER=""                       # shown in the updater as "by ..."; empty = no name
```

`06-prepare.sh` writes the URL into the updater (only then - with an empty `OTA_URL` the stock
updater is left alone). After changing `OTA_URL` you need a new build, and the phone needs that
build once (sideload or OTA from the old URL).

### HTTP or HTTPS?

- **HTTPS** is recommended and needs no changes to the updater apart from the URL.
- **HTTP** is allowed for exactly the one host in `OTA_URL` (useful in a home network without
  certificates): `06-prepare.sh` adds a network security config that permits cleartext traffic for
  that host only and relaxes the updater's HTTPS check for that host only.

Either way the phone installs only packages signed with **your release key**; a manipulated
download is rejected. This protection only exists with own keys (`SIGNING=own`) - with the public
test keys anybody could build a package your phone accepts, so use own keys together with OTA. HTTPS additionally hides what you download and from where.

## Example: Caddy on a Raspberry Pi (Debian / Raspberry Pi OS)

```bash
sudo apt install caddy
sudo mkdir -p /srv/ota && sudo chown "$USER": /srv/ota
sudo cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.orig
sudo tee /etc/caddy/Caddyfile >/dev/null <<'CADDY'
:80 {
    handle /ota/* {
        root * /srv
        file_server
    }
    handle {
        respond "Nothing here." 404
    }
}
CADDY
sudo systemctl reload caddy
```

This serves `/srv/ota/...` as `http://<pi>/ota/...`, so
`OTA_URL="http://<pi-hostname>/ota/crdroid/{device}.json"`. For HTTPS with a public domain, replace
`:80` with your domain name - Caddy then obtains a certificate automatically. Port 80 may already be
used by another service; pick a free one (`:8090`) and add it to the URL.

## Upload key (on the build PC)

A dedicated SSH key that can only run rsync inside the OTA folder:

```bash
ssh-keygen -t ed25519 -N "" -C "crdroid-ota-upload" -f ~/.ssh/ota_upload
cat >> ~/.ssh/config <<'CFG'
Host ota-server
    HostName <pi-hostname>
    User <user on the pi>
    IdentityFile ~/.ssh/ota_upload
    IdentitiesOnly yes
CFG
# install it on the server, restricted to rsync in /srv/ota (asks once for the password):
printf 'command="/usr/bin/rrsync /srv/ota",restrict %s\n' "$(cat ~/.ssh/ota_upload.pub)" | \
  ssh -o PubkeyAuthentication=no <user>@<pi-hostname> \
  'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys'
```

`rrsync` is part of the rsync package (Debian: `/usr/bin/rrsync`). With `OTA_UPLOAD="ota-server:crdroid"`
the files end up in `/srv/ota/crdroid/`.

Test:

```bash
ssh -o BatchMode=yes ota-server ls        # must be refused ("does not run rsync")
echo hello > /tmp/t.txt && rsync /tmp/t.txt ota-server:crdroid/ && curl -s http://<pi-hostname>/ota/crdroid/t.txt
```

If ssh asks for a password, the key was not accepted: it must be in the `authorized_keys` of the
user from `~/.ssh/config` (not root), and that user's home folder must not be writable by others.

## Publishing

```bash
bash scripts/08-publish.sh        # newest build; -n = dry run (only writes the JSON)
```

`update.sh build` does this automatically. The script uploads the ZIP first and the JSON last,
checks both through the web server and removes builds older than the last `OTA_KEEP` local builds.

## Notes on the updater

- It offers a build only if its timestamp is newer than the installed one. Every new build counts,
  even without code changes.
- `os_sdk_level` in the JSON is mandatory; without it the updater assumes 0 and silently ignores
  every build. `08-publish.sh` reads it from the ZIP.
- Builds of the same day have the same file name and replace each other on the server.
