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
[ -f "$HOME/.terminal/user.sh" ] && . "$HOME/.terminal/user.sh"
