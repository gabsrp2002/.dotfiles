# Path to oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

# Do not use case sensitive completion
CASE_SENSITIVE="false"

plugins=(git zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

if [[ $(uname) == "Darwin" ]]; then
    # skim alias
    alias skim="open -a Skim"

    # preview alias
    alias prev="open -a Preview"
fi

# nvim alias
alias vim="nvim"

# Function to fast add, commit and push
function acp() {
  git add .
  git commit -m "$1"
  git push
}

# Basic paths
if [[ $(uname) == "Darwin" ]]; then
    export HOMEBREW_NO_ENV_HINTS=1
    export PATH=/bin
    export PATH=/sbin:$PATH
    export PATH=/usr/bin:$PATH
    export PATH=/usr/sbin:$PATH

    # TeX path
    export PATH=/Library/TeX/texbin:$PATH

    # Homebrew paths
    export PATH=/opt/homebrew/opt/llvm/bin:$PATH
    export PATH=/opt/homebrew/bin:$PATH
    export PATH=/opt/homebrew/sbin:$PATH

    # Scripts path
    export PATH=$HOME/scripts:$PATH
    export PATH=$HOME/eda/oss-cad-suite/bin:$PATH
    export PATH=/usr/local/bin:$PATH

    # The following lines have been added by Docker Desktop to enable Docker CLI completions.
    fpath=(/Users/gabriel/.docker/completions $fpath)
    autoload -Uz compinit
    compinit
    # End of Docker CLI completions
    # eval "$(rbenv init -)"
fi

if [[ $(uname) == "Linux" ]]; then
    function open() {
        xdg-open "$@" > /dev/null 2>&1 &!
    }
fi

export PATH="$HOME/.deno/bin:$PATH"

# uv
export PATH="$HOME/.local/bin:$PATH"
