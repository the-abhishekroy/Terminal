#!/bin/sh
# Runs inside Alpine (as root, under proot). Prints only "@@BAR done total name" lines on stdout;
# everything else goes to /root/setup.log so the host script can show a friendly UI.
exec 2>>/root/setup.log
echo "--- setup.sh $(date)" >>/root/setup.log

apk update >>/root/setup.log 2>&1 || exit 1

CORE="bash bash-completion coreutils curl wget ca-certificates openssh-client mosh tmux git less
      neovim nano jq yq ripgrep fd fzf htop rsync tzdata unzip tar gzip file
      libgcc libstdc++ nodejs npm python3 py3-pip"
OPS="aws-cli kubectl helm docker-cli docker-cli-compose github-cli postgresql-client"
ALL="$CORE $OPS"
T=$(echo $ALL | wc -w); N=0; : > /root/.cli-skipped
for p in $ALL; do
    echo "@@BAR $N $T $p"
    apk add --no-cache -q "$p" >>/root/setup.log 2>&1 || echo "$p" >> /root/.cli-skipped
    N=$((N+1))
done
echo "@@BAR $T $T done"

sed -i 's#^root:\(.*\):/bin/ash#root:\1:/bin/bash#' /etc/passwd
cp /opt/cli/profile-cli.sh /etc/profile.d/cli.sh
cp /opt/cli/tmux.conf /etc/tmux.conf
for f in cli-add; do install -m 755 /opt/cli/$f /usr/local/bin/$f; done
[ -f /root/.bashrc ] || printf '[ -f /etc/profile.d/cli.sh ] && . /etc/profile.d/cli.sh\n' > /root/.bashrc
[ -f /root/.bash_profile ] || printf '[ -f /root/.bashrc ] && . /root/.bashrc\n' > /root/.bash_profile
mkdir -p /root/.ssh /root/.kube /root/.aws /root/.local/bin /root/work
chmod 700 /root/.ssh /root/.aws
# ngrok (static arm64 binary)
[ -x /usr/local/bin/ngrok ] || curl -fsSL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz 2>>/root/setup.log | tar xz -C /usr/local/bin ngrok 2>>/root/setup.log
touch /root/.cli-setup-ok
