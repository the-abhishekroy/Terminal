#!/bin/sh
# Runs once inside Alpine (as root, under proot). Re-runnable.
say() { printf '\033[1;36m[alpine]\033[0m %s\n' "$*"; }

apk update || exit 1

# ---- core: shell, network, ssh, editors ------------------------------------
CORE="bash bash-completion coreutils curl wget ca-certificates openssh-client mosh tmux git less
      neovim nano jq yq ripgrep fd fzf htop rsync tzdata unzip tar gzip file
      libgcc libstdc++ nodejs npm python3 py3-pip"
# ---- your stack: AWS, Kubernetes, Docker (client only), GitHub, Postgres ---
OPS="aws-cli kubectl helm docker-cli docker-cli-compose github-cli postgresql-client"

bar() { # bar <done> <total> <label>
    w=24; f=$(( $1 * w / $2 )); pct=$(( $1 * 100 / $2 ))
    b=$(printf '%*s' "$f" '' | tr ' ' '#')$(printf '%*s' "$((w-f))" '' | tr ' ' '-')
    printf '\r\033[K[%s] %3d%% (%s/%s) %s' "$b" "$pct" "$1" "$2" "$3"
}
N=0; T=$(echo $CORE $OPS | wc -w); SKIPPED=""
for p in $CORE $OPS; do
    bar "$N" "$T" "$p"
    apk add --no-cache -q "$p" >/dev/null 2>&1 || SKIPPED="$SKIPPED $p"
    N=$((N+1))
done
bar "$T" "$T" "done"; echo
[ -n "$SKIPPED" ] && say "not available on this Alpine, skipped:$SKIPPED"
say "base packages installed"

# ---- config -----------------------------------------------------------------
sed -i 's#^root:\(.*\):/bin/ash#root:\1:/bin/bash#' /etc/passwd
cp /opt/cli/profile-cli.sh /etc/profile.d/cli.sh
cp /opt/cli/tmux.conf /etc/tmux.conf
install -m 755 /opt/cli/mac-init /usr/local/bin/mac-init
install -m 755 /opt/cli/pull-creds /usr/local/bin/pull-creds
install -m 755 /opt/cli/cli-add /usr/local/bin/cli-add
[ -f /root/.bashrc ] || printf '[ -f /etc/profile.d/cli.sh ] && . /etc/profile.d/cli.sh\n' > /root/.bashrc
[ -f /root/.bash_profile ] || printf '[ -f /root/.bashrc ] && . /root/.bashrc\n' > /root/.bash_profile
mkdir -p /root/.ssh /root/.kube /root/.aws /root/.local/bin /root/work
chmod 700 /root/.ssh /root/.aws

# ---- Claude Code: native binary (musl build), no npm needed ------------------
say "installing Claude Code (native)…"
export USE_BUILTIN_RIPGREP=0
if curl -fsSL https://claude.ai/install.sh | bash; then
    say "Claude Code installed natively"
else
    say "native installer failed -> falling back to npm"
    npm install -g @anthropic-ai/claude-code && say "Claude Code installed via npm" || say "Claude Code install FAILED; retry later: cli-add claude"
fi
say "all done"
