# Path to oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

# Do not use case sensitive completion
CASE_SENSITIVE="false"

plugins=(git zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# skim alias
alias skim="open -a Skim"

# preview alias
alias prev="open -a Preview"

# nvim alias
alias vim="nvim"

# config files repo
alias config='git --git-dir=$HOME/.configfiles/ --work-tree=$HOME'

# Function to fast add, commit and push
function acp() {
  git add .
  git commit -m "$1"
  git push
}

export HOMEBREW_NO_ENV_HINTS=1

# Basic paths
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

export LDFLAGS="-L/opt/homebrew/opt/llvm/lib -Wl,-rpath,/opt/homebrew/opt/llvm/lib"
export CPPFLAGS="-I/opt/homebrew/opt/llvm/include"
