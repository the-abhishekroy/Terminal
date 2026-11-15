<p align="center"><img src="art/cli-icon.png" width="120" alt="Terminal icon"></p>

<h1 align="center">Terminal</h1>

<p align="center"><b>A fast, light Linux terminal for Android, ready for cloud and DevOps work.</b></p>

<p align="center">
  <a href="../../releases/latest"><img alt="Download" src="https://img.shields.io/badge/Download-Terminal.apk-87D787?style=for-the-badge&labelColor=000000"></a>
  <img alt="Android 7+" src="https://img.shields.io/badge/Android-7%2B%20(arm64)-87AFFF?style=for-the-badge&labelColor=000000">
  <img alt="License GPLv3" src="https://img.shields.io/badge/License-GPLv3-8C8C8C?style=for-the-badge&labelColor=000000">
</p>

<p align="center">
  <a href="#why">Why</a> · <a href="#what-you-get">What you get</a> · <a href="#install">Install</a> · <a href="#first-steps">First steps</a> · <a href="#connect-your-computer-over-ssh-optional">SSH</a> · <a href="#pair-it-with-your-mac-andromac">Andromac</a> · <a href="#limits">Limits</a>
</p>

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
| Cloud | `aws` (AWS CLI v1), `kubectl`, `helm`, `gh`, `ngrok`, `vercel` |
| Access | `ssh`, `mosh`, `rsync`, `curl`, `wget` |
| Dev | `git`, `node` + `npm`, `python` + `pip`, `psql` client, `jq`, `yq`, `ripgrep`, `fd`, `fzf`, `nano`, `tmux`, `htop` |
| More | `terminal-add <tool>`: `bun`, `neovim`, `k9s`, `postgresql`, `redis`, `docker-cli`, `docker-compose`, `sqlite` and thousands more from the Termux repository |

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

## Connect your computer over ssh (optional)

Terminal starts an ssh server on port 8022 as soon as `~/.ssh/authorized_keys` has a key in it (keys only, no passwords). To reach the phone from anywhere, not just the same Wi-Fi, install [Tailscale](https://tailscale.com) on both devices and log in with the same account, or use [Andromac](https://github.com/the-abhishekroy/andromac), which has the private network built in and needs no extra app. Then add your computer's public key to the phone's `~/.ssh/authorized_keys` and run `ssh -p 8022 <phone-user>@<tailscale-address>` (`whoami` shows the user). Without a key, no ssh server runs.

## Pair it with your Mac: Andromac

Terminal is the phone half of a pair. **[Andromac](https://github.com/the-abhishekroy/andromac)** is the other half: a free, open-source app that links a Mac and an Android phone from anywhere (no cable, no shared Wi-Fi, no separate VPN app), and carries notifications, one-time codes, clipboard, screen view and control, and **terminal shortcuts**.

With both installed:

```sh
ssh m5     # on the phone, in Terminal: opens a shell on your Mac
ssh f14    # on the Mac: opens Terminal on your phone
```

Andromac builds the private connection for you, and Terminal's ssh server (port 8022, keys only) is what the Mac reaches. Setup steps are in Andromac's [Terminal shortcuts](https://github.com/the-abhishekroy/andromac#-features) section.

## Commands

```sh
terminal setup      # install / repair everything
terminal doctor     # health check
terminal reset      # run the first-time setup again (your files stay)
terminal-add <tool> # install more tools
```

## Auto mode (no permission prompts)

By default Terminal sets Claude Code to **bypass permissions**: it runs commands and edits files without asking each time. This suits a phone, where tapping "yes" all day is slow. Be aware that Claude can then run anything your credentials allow, for example `kubectl` or `aws` against production. Turn it off any time with `terminal auto off`, and check with `terminal auto status`.

## About Claude Code's version

Claude Code stopped shipping as plain JavaScript after version **2.1.112**. Newer releases are a 337 MB native binary that needs Linux compatibility layers, and those froze on Android. Terminal installs 2.1.112 (about 50 MB, runs on Node, no freezes). You can try a different version with `TERMINAL_CLAUDE_VERSION=<version> terminal setup`, but newer ones will not run natively on Android.

## Limits

- There is no Docker daemon on a phone: use the Docker client against a remote host. `eksctl` and `terraform` are not available natively.
- `ngrok` runs through a small wrapper (`termux-chroot`) because Android has no `/etc/resolv.conf`. Add your token with `ngrok config add-authtoken <token>`.
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
