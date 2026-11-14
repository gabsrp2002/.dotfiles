# Path to oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

# Do not use case sensitive completion
CASE_SENSITIVE="false"

# Docker CLI completions (added before oh-my-zsh compinit)
if [[ -d "$HOME/.docker/completions" ]]; then
  fpath=("$HOME/.docker/completions" $fpath)
fi

plugins=(git zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# Disable XON/XOFF flow control so C-s works as tmux prefix
if [[ -t 0 && $- == *i* ]]; then
  stty -ixon
fi

if [[ $(uname) == "Darwin" ]]; then
    # skim alias
    alias skim="open -a Skim"

    # preview alias
    alias prev="open -a Preview"
fi

# nvim alias (if installed)
if command -v nvim >/dev/null 2>&1; then
  alias vim="nvim"
fi

# Function to fast add, commit and push
function acp() {
  if [[ -z "${1:-}" ]]; then
    echo "Usage: acp <commit message>" >&2
    return 1
  fi
  git add . && git commit -m "$1" && git push
}

# Deduplicate PATH entries automatically across reloads
typeset -U path PATH

# Basic paths
if [[ $(uname) == "Darwin" ]]; then
    export HOMEBREW_NO_ENV_HINTS=1
    path=(
        "$HOME/.ob1/bin"
        "$HOME/.local/bin"
        "$HOME/.deno/bin"
        /usr/local/bin
        "$HOME/eda/oss-cad-suite/bin"
        "$HOME/scripts"
        /opt/homebrew/sbin
        /opt/homebrew/bin
        /opt/homebrew/opt/llvm/bin
        "$HOME/.rbenv/shims"
        /Library/TeX/texbin
        /usr/sbin
        /usr/bin
        /sbin
        /bin
    )
    export PATH

    # eval "$(rbenv init -)"
fi

if [[ $(uname) == "Linux" ]]; then
    function open() {
        xdg-open "$@" > /dev/null 2>&1 &!
    }
    path=(
        "$HOME/.ob1/bin"
        "$HOME/.local/bin"
        "$HOME/.deno/bin"
        $path
    )
    export PATH
fi
