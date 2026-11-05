# Cli Alpine profile (sourced for login/interactive shells)
export LANG=C.UTF-8 EDITOR=nvim PAGER=less
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
export USE_BUILTIN_RIPGREP=0          # Claude Code: use Alpine's ripgrep (musl)
export DISABLE_TELEMETRY=1

# bash-only niceties
if [ -n "$BASH_VERSION" ]; then
    [ -f /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion
    HISTSIZE=5000; HISTCONTROL=ignoredups:erasedups; shopt -s histappend checkwinsize 2>/dev/null
    __git() { b=$(git branch --show-current 2>/dev/null) && [ -n "$b" ] && printf ' (%s)' "$b"; }
    PS1='\[\e[38;5;111m\]\w\[\e[38;5;176m\]$(__git)\[\e[0m\] \[\e[38;5;114m\]❯\[\e[0m\] '
    command -v kubectl >/dev/null && source <(kubectl completion bash) 2>/dev/null && complete -o default -F __start_kubectl k
fi

alias ll='ls -lah --color=auto' ls='ls --color=auto' g=git k=kubectl dc='docker compose' v=nvim
alias c=claude cc='claude --continue' gs='git status -sb' gl='git log --oneline -15'
alias kgp='kubectl get pods' kgs='kubectl get svc' kctx='kubectl config use-context'

# one tmux session that survives disconnects; skip with CLI_NO_TMUX=1
if [ -z "$TMUX" ] && [ -z "$CLI_NO_TMUX" ] && [ -t 0 ] && command -v tmux >/dev/null; then
    exec tmux new-session -A -s main
fi

if [ -n "$PS1" ] && [ -z "$CLI_MOTD_SHOWN" ] && [ -n "$TMUX" ]; then
    export CLI_MOTD_SHOWN=1
    printf '\033[1;36mCli\033[0m · Alpine %s · claude  aws  kubectl  helm  gh  docker(client)  ssh/mosh\n' "$(cat /etc/alpine-release)"
    [ -f /root/.cli-configured ] || printf '  first time? run: \033[1mmac-init\033[0m (link your Mac)  then  \033[1mpull-creds\033[0m (AWS/kube/ssh)\n'
fi
