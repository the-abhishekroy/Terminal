#!/bin/bash
# Terminal app test suite. Usage: tools/test-app.sh <path-to.apk>
# Static + APK checks run anywhere; device checks need `adb` and a USB-debugging phone with the app set up.
# Device tests run commands inside the app's own environment (no taps on the screen, no input events).
APK="${1:-app/build/outputs/apk/debug/termux-app_apt-android-7-debug_universal.apk}"
ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
ADB="$ANDROID_HOME/platform-tools/adb"; AAPT=$(ls "$ANDROID_HOME"/build-tools/*/aapt2 | tail -1)
PKG=app.clipod; P=/data/data/$PKG/files; A=app/src/main/assets/terminal
PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %s  %s\n' "$1" "$2"; }
skip() { SKIP=$((SKIP+1)); printf '  \033[33mSKIP\033[0m %s  %s\n' "$1" "$2"; }
chk()  { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1" "${3:-}"; fi; }
# T '<command>' -> runs in a login shell with the same environment a terminal session has
ENVV="PREFIX=$P/usr HOME=$P/home TMPDIR=$P/usr/tmp PATH=$P/usr/bin LD_PRELOAD=$P/usr/lib/libtermux-exec-ld-preload.so TERM=xterm-256color LANG=en_US.UTF-8 ANDROID_ROOT=/system ANDROID_DATA=/data SHELL=$P/usr/bin/bash"
T() { "$ADB" shell "run-as $PKG env -i $ENVV $P/usr/bin/bash -lc '$1' </dev/null" 2>&1 | tr -d '\r'; }

echo "== 1. Static checks"
for f in $A/bin/terminal $A/bin/terminal-add $A/profile.d/terminal-boot.sh; do chk "sh syntax: ${f#$A/}" "sh -n $f"; done
chk "bash syntax: terminal.bashrc" "bash -n $A/terminal.bashrc"
chk "no leftover 'Alpine/proot/mac-init/Welcome to Termux' in app scripts" "! grep -rEIq 'alpine_run|proot_run|mac-init|pull-creds|Welcome to Termux' $A --include=terminal --include=terminal-add --include=terminal-boot.sh --include=terminal.bashrc | grep -v migrate"
chk "no visible 'Cli' branding in assets/strings" "! grep -rwq 'Cli' $A app/src/main/res/values/strings.xml"
chk "no auto-tmux (sessions must be independent)" "! grep -rq 'exec tmux' $A"
chk "setup never blocks forever (retry-or-quit prompts)" "grep -q retry_or_quit $A/bin/terminal"

echo "== 2. APK"
BADGE=$("$AAPT" dump badging "$APK" 2>/dev/null)
chk "label is Terminal"              "echo \"\$BADGE\" | grep -q \"application-label:'Terminal'\""
chk "package id app.clipod"          "echo \"\$BADGE\" | grep -q \"package: name='app.clipod'\""
chk "arm64-v8a only"                 "echo \"\$BADGE\" | grep -q \"native-code: 'arm64-v8a'\""
chk "adaptive launcher icon"         "echo \"\$BADGE\" | grep -q 'mipmap-anydpi-v26/ic_launcher.xml'"
chk "size under 120 MB"              "[ \$(stat -f %z \"$APK\" 2>/dev/null || stat -c %s \"$APK\") -lt 125829120 ]"
chk "no dangerous permissions (READ_LOGS, DUMP, SYSTEM_ALERT_WINDOW)" "! echo \"\$BADGE\" | grep -Eq 'READ_LOGS|\\.DUMP|SYSTEM_ALERT_WINDOW'"
for f in terminal/bin/terminal terminal/bin/terminal-add terminal/profile.d/terminal-boot.sh terminal/terminal.bashrc terminal/termux/font.ttf; do chk "asset in APK: $f" "unzip -l \"$APK\" | grep -q assets/$f"; done

echo "== 3. Device"
if ! "$ADB" get-state >/dev/null 2>&1; then skip "device tests" "no adb device"; else
chk "app installed" "$ADB shell pm list packages | grep -q $PKG"
chk "launcher installed" "$ADB shell run-as $PKG test -x $P/usr/bin/terminal"
chk "package installer installed" "$ADB shell run-as $PKG test -x $P/usr/bin/terminal-add"
chk "boot hook installed" "$ADB shell run-as $PKG test -f $P/usr/etc/profile.d/terminal-boot.sh"
chk "no files left from older versions (cli/proot launcher)" "! $ADB shell run-as $PKG sh -c 'test -e $P/usr/bin/cli || test -e $P/usr/etc/profile.d/cli-boot.sh'"
chk "bootstrap fully re-pathed (nothing points to /data/data/com.termux)" "! $ADB shell run-as $PKG grep -rlI /data/data/com.termux $P/usr/etc $P/usr/bin | grep -v terminal-add | grep -q ."
chk "first-time setup finished" "$ADB shell run-as $PKG test -f $P/home/.terminal/.ready" "open the app once, finish the setup, then re-run"
if "$ADB" shell run-as $PKG test -f $P/home/.terminal/.ready 2>/dev/null; then
  OUT=$("$ADB" shell "run-as $PKG env -i $ENVV $P/usr/bin/bash -lic 'echo ENV:\$TZ:\$USE_BUILTIN_RIPGREP:\${TMUX:-none}' </dev/null" 2>/dev/null | tr -d '\r'); echo "$OUT" | grep -q 'ENV:Asia/Kolkata:0:none' && ok "session environment (IST, rg, no auto-tmux)" || bad "session environment" "$OUT"
  for t in claude node npm git ssh rg kubectl helm gh aws jq yq tmux python pip fzf fd rsync mosh curl wget nano; do chk "tool: $t" "T 'command -v $t' | grep -q /"; done
  chk "claude runs (Node, native)"  "T 'claude --version' | grep -q 'Claude Code'"
  chk "node runs"     "T 'node -v' | grep -q ^v"
  chk "git runs"      "T 'git --version' | grep -q git"
  chk "kubectl runs"  "T 'kubectl version --client' | grep -qi client"
  chk "helm runs"     "T 'helm version --short' | grep -q v"
  chk "aws runs"      "T 'aws --version' | grep -q aws-cli"
  chk "gh runs"       "T 'gh --version' | grep -q gh"
  chk "npm can install a package" "T 'cd \$TMPDIR && rm -rf npmt && mkdir npmt && cd npmt && npm init -y >/dev/null 2>&1 && npm install --no-audit --no-fund left-pad >/dev/null 2>&1; test -d node_modules/left-pad && echo NPMOK; rm -rf \$TMPDIR/npmt' | grep -q NPMOK"
  chk "terminal-add installs a package" "T 'terminal-add tree >/dev/null 2>&1; tree --version' | grep -qi tree"
  chk "internet + DNS" "T 'for i in 1 2 3 4 5 6; do curl -sI -m 15 https://registry.npmjs.org | head -1 | grep -q 200 && echo NET200 && break; sleep 2; done' | grep -q NET200"
  chk "file ops: write, symlink, exec in home" "T 'cd \$HOME && echo hi > t.txt && ln -sf t.txt l && printf \"#!/bin/sh\necho EXEC\n\" > x.sh && chmod +x x.sh && ./x.sh && cat l; rm -f t.txt l x.sh' | grep -q EXEC"
  chk "~/work exists and is writable" "T 'touch \$HOME/work/.t && rm \$HOME/work/.t && echo W' | grep -q W"
  chk "terminal doctor shows no missing tool" "! T 'terminal doctor' | grep -q missing"
  chk "no proot / emulation processes anywhere" "! $ADB shell ps -A -o NAME | grep -qx proot"
  # migration from the old Alpine layout (settings copied, big folder removed)
  M=$(T 'mkdir -p $HOME/.terminal/alpine/root/.aws && echo "[default]" > $HOME/.terminal/alpine/root/.aws/config && echo "alias zz=true" > $HOME/.terminal/alpine/root/.bashrc && terminal __migrate; test -f $HOME/.aws/config && test ! -d $HOME/.terminal/alpine && grep -q "alias zz" $HOME/.terminal/user.sh && echo MIGOK; rm -f $HOME/.terminal/user.sh')
  echo "$M" | grep -q MIGOK && ok "upgrade from old Alpine layout: settings moved, space freed" || bad "migration" "$M"
  # concurrency: two sessions at once, 12 parallel node/git/gh runs, nothing may freeze
  ( T 'echo A:$$; sleep 3; echo A-done' > /tmp/sessA.$$ ) & ( T 'echo B:$$; sleep 3; echo B-done' > /tmp/sessB.$$ ) & wait
  chk "two concurrent sessions run independently" "grep -q A-done /tmp/sessA.$$ && grep -q B-done /tmp/sessB.$$ && ! diff -q <(grep -o '^A:[0-9]*' /tmp/sessA.$$ | cut -d: -f2) <(grep -o '^B:[0-9]*' /tmp/sessB.$$ | cut -d: -f2)"
  rm -f /tmp/sessA.$$ /tmp/sessB.$$
  S=$(T 'for i in 1 2 3 4 5 6 7 8 9 10 11 12; do (node -e "setTimeout(()=>{},300)" & git --version >/dev/null & gh --version >/dev/null & wait) & done; wait; echo STRESS-DONE')
  echo "$S" | grep -q STRESS-DONE && ok "12 parallel node+git+gh runs finish (no deadlock)" || bad "stress" "$S"
  chk "no process stuck in a frozen state afterwards" "! $ADB shell ps -A -o STAT | grep -q '^t'"
  R=$(T 'timeout 90 claude -p "reply with exactly: PONG" < /dev/null 2>&1'); if echo "$R" | grep -q PONG; then ok "claude answers a prompt"; elif echo "$R" | grep -qiE 'login|log in|auth|api key|sign'; then skip "claude prompt" "not signed in yet"; else bad "claude answers a prompt" "$(echo "$R" | tail -2)"; fi
  # lifecycle: force-stop / relaunch x5 -> the shell must always answer (the old 'blank screen after reopen' bug)
  for i in 1 2 3 4 5; do
     "$ADB" shell am force-stop $PKG; "$ADB" shell am start -n $PKG/com.termux.app.TermuxActivity >/dev/null 2>&1; sleep 4
     chk "relaunch #$i: app foreground + shell answers" "$ADB shell dumpsys activity activities | grep -m1 topResumedActivity | grep -q $PKG && T 'echo alive' | grep -q alive"
  done
  PSS=$("$ADB" shell dumpsys meminfo $PKG | awk '/TOTAL PSS:/{print $3}'); [ -n "$PSS" ] && [ "$PSS" -lt 300000 ] && ok "app memory ${PSS} KB < 300 MB" || bad "app memory" "PSS=$PSS"
  T0=$(python3 -c 'import time;print(time.time())'); T 'true' >/dev/null; T1=$(python3 -c 'import time;print(time.time())'); python3 -c "d=$T1-$T0; print('  INFO  shell start %.2fs' % d)"
fi; fi
echo; echo "RESULT: $PASS passed, $FAIL failed, $SKIP skipped"; [ $FAIL -eq 0 ]
