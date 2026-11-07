# Terminal: environment for every interactive session; runs the first-time setup once.
case $- in *i*) ;; *) return 0 2>/dev/null || true ;; esac
export TZ=Asia/Kolkata EDITOR=nano USE_BUILTIN_RIPGREP=0 DISABLE_AUTOUPDATER=1
export PATH="$HOME/.local/bin:$PATH"
# one tiny line in ~/.bashrc loads the Terminal prompt + aliases (bash reads it after the system files)
if [ -n "$BASH_VERSION" ] && ! grep -qs terminal.bashrc "$HOME/.bashrc" 2>/dev/null; then
    echo '[ -f "$PREFIX/etc/terminal.bashrc" ] && . "$PREFIX/etc/terminal.bashrc"' >> "$HOME/.bashrc"
fi
# first session after install: make the bundled scripts (npm, etc.) executable
if [ -f "$PREFIX/etc/terminal-exec.list" ] && [ ! -f "$PREFIX/etc/.terminal-exec-done" ]; then
    while IFS= read -r f; do [ -n "$f" ] && chmod 700 "$PREFIX/$f" 2>/dev/null; done < "$PREFIX/etc/terminal-exec.list"
    touch "$PREFIX/etc/.terminal-exec-done"
fi
[ -x "$PREFIX/bin/terminal" ] || return 0 2>/dev/null
[ -f "$HOME/.terminal/.ready" ] || "$PREFIX/bin/terminal" setup
# ssh server: starts quietly only if you have added a key to ~/.ssh/authorized_keys (keys only, no passwords)
if [ -s "$HOME/.ssh/authorized_keys" ] && [ -x "$PREFIX/bin/sshd" ] && ! pgrep -x sshd >/dev/null 2>&1; then
    mkdir -p "$PREFIX/etc/ssh/sshd_config.d"
    [ -f "$PREFIX/etc/ssh/sshd_config.d/terminal.conf" ] || printf 'Port 8022\nPasswordAuthentication no\nKbdInteractiveAuthentication no\n' > "$PREFIX/etc/ssh/sshd_config.d/terminal.conf"
    ssh-keygen -A >/dev/null 2>&1
    sshd >/dev/null 2>&1 </dev/null
fi
[ -f "$HOME/.terminal/user.sh" ] && . "$HOME/.terminal/user.sh"
