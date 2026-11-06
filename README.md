<p align="center"><img src="art/cli-icon.png" width="120" alt="Terminal icon"></p>

# Terminal

**A fast, light Linux terminal for Android, ready for cloud and DevOps work.**
Open the app, press Enter once, and in a couple of minutes you have Claude Code, AWS CLI, kubectl, helm, GitHub CLI, git, ssh and tmux, all running natively on the phone. There is no emulation layer, so it starts instantly and never freezes in the background.

Terminal is a fork of [Termux](https://github.com/termux/termux-app) (GPLv3) with its own name, first-run setup and package set.

## Why

- **Native speed.** Everything runs directly on Android. A new shell opens in well under a second.
- **Claude Code that works.** It runs on Node (JavaScript), about 50 MB, instead of a 337 MB binary that froze under emulation.
- **Friendly first run.** A step-by-step screen with progress bars, plain-language errors and a "what to do next" list.
- **Sessions are independent.** Every new session is its own shell, with no shared state.
- **Light.** The app is about 90 MB. Everything else is downloaded on demand, so you only keep what you use.

## What you get

| Area | Tools |
|---|---|
| AI | `claude` (Claude Code 2.1.112, on Node) |
| Cloud | `aws` (AWS CLI v1), `kubectl`, `helm`, `gh`, `docker-compose` (via `terminal-add`) |
| Access | `ssh`, `mosh`, `rsync`, `curl`, `wget` |
| Dev | `git`, `node` + `npm`, `python` + `pip`, `psql` client, `jq`, `yq`, `ripgrep`, `fd`, `fzf`, `nano`, `tmux`, `htop` |
| More | `terminal-add <tool>`: thousands of packages from the Termux repository (neovim, terraform, k9s, ...) |

Handy aliases: `c` (claude), `cc` (claude --continue), `k` (kubectl), `g` (git), `gs`, `gl`, `kgp`.

## Install

1. Download `Terminal.apk` from the [Releases](../../releases) page.
2. Allow installing from unknown sources. On Samsung phones, turn off **Auto Blocker** first (Settings → Security and privacy → Auto Blocker). If Google Play Protect warns, choose **Install anyway**.
3. Open **Terminal**, stay on Wi-Fi, and press Enter. The setup takes about 2 to 4 minutes and downloads about 400 MB, once.

Requirements: Android 7 or newer, 64-bit ARM phone (`arm64-v8a`). Tested on a Samsung Galaxy F14 5G with Android 15.

## First steps

```sh
claude              # sign in with the link it prints
terminal doctor     # check that everything is installed
terminal-add neovim # install anything else you need
```

Your projects go in `~/work`. If an SD card is present, that folder is created on the card to keep phone storage free.

## Commands

```sh
terminal setup      # install / repair everything
terminal doctor     # health check
terminal reset      # run the first-time setup again (your files stay)
terminal-add <tool> # install more tools
```

## About Claude Code's version

Claude Code stopped shipping as plain JavaScript after version **2.1.112**. Newer releases are a 337 MB native binary that needs Linux compatibility layers, and those froze on Android. Terminal installs 2.1.112 (about 50 MB, runs on Node, no freezes). You can try a different version with `TERMINAL_CLAUDE_VERSION=<version> terminal setup`, but newer ones will not run natively on Android.

## Limits

- `ngrok`, `docker` (daemon) and `eksctl` are not in the Termux repository. For Docker, use the `docker-compose` / `docker-cli` client against a remote host.
- AWS CLI is v1 (installed with pip). It supports everything a day-to-day workflow needs, including `aws eks get-token`.
- A normal (FAT/exFAT) SD card cannot hold programs, only your files. That is an Android rule.
- The APK is signed with the public Termux test key. That is fine for personal use, not for a store.

## Keeping sessions alive (Android 12+ / Samsung One UI)

- Settings → Battery → Terminal → **Unrestricted**.
- Developer options → **Disable child process restrictions**.

## Build from source

Needs JDK 17, the Android SDK (platform 36, build-tools 35.0.0 and 36.0.0), NDK 29.0.14206865, `python3` and `curl`.

```sh
echo "sdk.dir=$ANDROID_HOME" > local.properties
./gradlew assembleDebug
# app/build/outputs/apk/debug/termux-app_apt-android-7-debug_universal.apk
```

The package id is `app.clipod`. `tools/make-bootstrap.py` builds the base system at build time: the upstream Termux bootstrap plus Node, git, ssh and ripgrep, with the hardcoded app path rewritten to `/data/data/app.clipod` (same length, so binaries stay valid). `terminal-add` applies the same rewrite on the phone to every package it installs. After changing the bootstrap, delete `app/build` and `app/.cxx` so the native library is rebuilt.

Where the changes live:

- `app/src/main/assets/terminal/`: `bin/terminal` (setup UI, doctor), `bin/terminal-add` (package installer), `profile.d/terminal-boot.sh`, `terminal.bashrc` (prompt, aliases), font and tmux config.
- `app/src/main/java/com/termux/app/TermuxInstaller.java`: installs those files and lists SD card paths.
- `app/build.gradle`: arm64-only build, package id, bootstrap generation.

## Tests

```sh
tools/test-app.sh path/to/Terminal.apk   # static + APK + on-device checks (needs adb and a USB-debugging phone)
```

The suite checks syntax, APK contents, every tool, internet, file operations, `npm`, `terminal-add`, upgrade from the old layout, two concurrent sessions, 12 parallel processes with no deadlock, `claude`, five force-stop and relaunch cycles, and memory use. It does not tap the screen.

## License

GPLv3, inherited from Termux. See [LICENSE.md](LICENSE.md). Termux is a project of the Termux developers; Terminal is not affiliated with it.
