# Setting up the build computer

You need a Linux environment: either **Ubuntu 24.04 directly** or **Ubuntu 24.04 in WSL2** on Windows.
Afterwards both ways are identical.

## A) Ubuntu 24.04 (native)

```bash
sudo apt-get install -y git
git clone https://github.com/FerFemNemBem/crdroid-camellia-builder.git
cd crdroid-camellia-builder
bash scripts/01-setup-host.sh
```

Open a new terminal afterwards. The setup installs the shortcut `ccb`, which jumps into the
repository folder - all commands of this guide are run from there. Continue with
[Configuration](#configuration).

## B) Windows with WSL2

### 1. Install WSL (once)

If WSL is not installed yet, open **PowerShell as administrator** and run

```powershell
wsl --install --no-distribution
```

then restart Windows.

### 2. Get this repository on Windows

Download it as ZIP from GitHub and unpack it, or clone it with Git for Windows, e.g. to
`D:\crdroid-camellia-builder`. Keeping the repository on a Windows drive lets you edit
`config.env` with any editor and use the double-click update later.

### 3. Create a dedicated WSL distribution

In a normal PowerShell window (adapt the folder; it needs ~350 GB, ideally on an SSD):

```powershell
powershell -ExecutionPolicy Bypass -File D:\crdroid-camellia-builder\scripts\windows\create-wsl.ps1 -Location D:\WSL\crdroid
```

This creates the distribution `crdroid` (change with `-Name`) and does not touch your other WSL
distributions. When Ubuntu opens, choose a user name and password, then type `exit`.

### 4. Give WSL enough memory

WSL only uses half of your RAM by default, which is too little. The script prints a recommendation;
put it into `C:\Users\<you>\.wslconfig`, for example on a 64 GB PC:

```ini
[wsl2]
memory=52GB
processors=16
swap=16GB
swapFile=D:\\WSL\\crdroid\\swap.vhdx
```

Then run `wsl --shutdown` once. **This stops all running WSL distributions**, so save your work in
them first. The settings apply to every distribution.

### 5. Install the build tools

Open the distribution from PowerShell:

```powershell
wsl -d crdroid
```

You are now in Ubuntu, but still in your **Windows user folder** (`/mnt/c/Users/<you>`) - that is where
WSL starts. Change into the repository folder. Windows drives appear under `/mnt/` with a
**lower-case letter**: `D:\crdroid-camellia-builder` is `/mnt/d/crdroid-camellia-builder`
(`/mnt/D/...` does not exist).

```bash
cd /mnt/d/crdroid-camellia-builder
bash scripts/01-setup-host.sh
```

If the distribution was imported (older WSL), the script first asks you to create a user and to
restart the distribution - just follow the instructions and run it again.

At the end the script prints the next steps. Restart the distribution once:

1. `exit` - leaves Ubuntu, you are back in PowerShell
2. `wsl --terminate crdroid`
3. `wsl -d crdroid` - opens it again (again in your Windows user folder)
4. `ccb` - **new shortcut** installed by the setup script: jumps into the repository folder

> [!IMPORTANT]
> **Every command of this guide is run inside the repository folder.** Each time you open the
> distribution, type `ccb` first. A message like `scripts/02-check-host.sh: No such file or directory`
> means you are in the wrong folder.

> [!IMPORTANT]
> The **source tree must live inside the Linux file system** (the default `WORK_DIR=$HOME/android`).
> On a Windows drive (`/mnt/c`, `/mnt/d`, ...) the build is extremely slow and fails.
> Finished builds (`OUTPUT_DIR`) may be on a Windows drive, which is convenient.

## Configuration

Optional - without a `config.env` the defaults are used (test keys, GApps download, ViPER, results in
`~/crdroid-out`). To change something:

**Windows (repository on a Windows drive):** in Explorer open the repository folder, copy
`config.env.example` and rename the copy to **`config.env`**. Turn on *View -> Show -> File name
extensions* first, otherwise Windows may silently name it `config.env.txt`. Open it with Notepad
(right-click -> *Open with*) and edit it. Windows line endings are fine.

**Linux / inside Ubuntu:**

```bash
ccb
cp config.env.example config.env
nano config.env          # save: Ctrl+O, Enter; quit: Ctrl+X
```

All settings are explained in the file. The most important ones:

| setting | meaning |
|---|---|
| `WORK_DIR` | source tree, cache and keys (~300 GB, Linux file system) |
| `OUTPUT_DIR` | finished builds, downloads, logs; on WSL a Windows drive is handy, e.g. `/mnt/d/crdroid` (= `D:\crdroid`, lower-case letter!) |
| `WITH_VIPER` / `WITH_GAPPS` | ViPER4AndroidFX on/off (default on), download MindTheGapps on/off (default on) |
| `SIGNING` | `test` (default, nothing to manage) or `own` (recommended for daily use and OTA), see [signing.md](signing.md) - decide before the first installation |
| `OTA_URL` / `OTA_UPLOAD` | only for your own update server, see [ota-server.md](ota-server.md) |

Then check everything (inside the repository folder - `ccb`):

```bash
bash scripts/02-check-host.sh
```

All lines should say `OK` (a `NOTE` is fine). Continue with [build.md](build.md).
