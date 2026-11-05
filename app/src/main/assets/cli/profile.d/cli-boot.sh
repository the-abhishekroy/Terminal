# Cli: every new terminal session drops straight into the Alpine environment.
# Escape hatch: `touch ~/.cli-no-auto` (or run `CLI_HOST=1 bash -l`) to stay in the bare host shell.
case $- in *i*) ;; *) return 0 2>/dev/null || true ;; esac
[ -n "$CLI_HOST" ] && return 0 2>/dev/null
[ -f "$HOME/.cli-no-auto" ] && return 0 2>/dev/null
[ -x "$PREFIX/bin/cli" ] || return 0 2>/dev/null

if [ ! -f "$HOME/.cli/alpine/.ready" ]; then
    "$PREFIX/bin/cli" setup || { echo "Setup did not finish. Run 'cli setup' to retry."; return 0 2>/dev/null; }
fi
"$PREFIX/bin/cli" enter && exit 0
echo "Could not start Alpine (see above). You are in the host shell; try 'cli doctor'."
