# .dotfiles
My dotfiles managed with `stow`

## Installation

1. Install `git` with your package manager (if not already installed).

Using homebrew:

```sh
brew install git
```

2. Clone the repository in your root directory:

```sh
git clone https://github.com/gabsrp2002/.dotfiles.git
```

3. Install `stow` with your package manager.

Using homebrew:

```sh
brew install stow
```
4. Go to the repository directory:

```sh
cd .dotfiles
```

5. Install the dotfiles:

```sh
stow */
```

If you want to install a specific package, for example `zsh`:

```sh
stow zsh
```
