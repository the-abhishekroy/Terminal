# Terminal prompt and aliases (loaded from ~/.bashrc)
[ -n "$PS1" ] || return 0
[ -f "$PREFIX/share/bash-completion/bash_completion" ] && . "$PREFIX/share/bash-completion/bash_completion"
HISTSIZE=5000; HISTCONTROL=ignoredups:erasedups; shopt -s histappend checkwinsize 2>/dev/null
__git() { b=$(git branch --show-current 2>/dev/null) && [ -n "$b" ] && printf ' (%s)' "$b"; }
PS1='\[\e[38;5;111m\]\w\[\e[38;5;176m\]$(__git)\[\e[0m\] \[\e[38;5;114m\]❯\[\e[0m\] '
command -v kubectl >/dev/null 2>&1 && source <(kubectl completion bash 2>/dev/null) 2>/dev/null && complete -o default -F __start_kubectl k 2>/dev/null
alias ll='ls -lah --color=auto' ls='ls --color=auto' g=git k=kubectl v=nano c=claude cc='claude --continue'
alias gs='git status -sb' gl='git log --oneline -15' kgp='kubectl get pods' kgs='kubectl get svc' kctx='kubectl config use-context'
