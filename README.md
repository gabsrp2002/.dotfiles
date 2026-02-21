# .dotfiles

My dotfiles managed with `stow`

## Packages

| Package      | Platform       | Description                                 |
| ------------ | -------------- | ------------------------------------------- |
| `aerospace`  | macOS          | Aerospace window manager configuration      |
| `git`        | Cross-platform | Git configuration and aliases               |
| `hypr`       | Linux          | Hyprland (Wayland compositor) configuration |
| `kitty`      | Cross-platform | Kitty terminal emulator configuration       |
| `latex`      | Cross-platform | LaTeX configuration for writing documents   |
| `nvim`       | Cross-platform | Neovim text editor configuration            |
| `rofi`       | Cross-platform | Rofi application launcher configuration     |
| `sketchybar` | macOS          | Sketchybar (macOS status bar) configuration |
| `tmux`       | Cross-platform | Tmux terminal multiplexer configuration     |
| `utils`      | macOS          | macOS utility scripts                       |
| `utils-arch` | Linux          | Arch Linux-specific utility scripts         |
| `waybar`     | Linux          | Waybar (Wayland status bar) configuration   |
| `wlogout`    | Linux          | Wlogout (Wayland logout menu) configuration |
| `zsh`        | Cross-platform | Zsh shell configuration                     |

## Installation

1. Install `git` with your package manager (if not already installed).

Using homebrew (macOS):

```sh
brew install git
```

Using pacman (Arch Linux):

```sh
sudo pacman -S git
```

2. Clone the repository in your home directory:

```sh
git clone https://github.com/gabsrp2002/.dotfiles.git
```

3. Install `stow` with your package manager.

Using homebrew (macOS):

```sh
brew install stow
```

Using pacman (Arch Linux):

```sh
sudo pacman -S stow
```

4. Go to the repository directory:

```sh
cd .dotfiles
```

5. Install the dotfiles:

### macOS

Install all macOS packages:

```sh
stow aerospace git kitty latex nvim rofi sketchybar tmux utils zsh
```

### Arch Linux

Install all Arch Linux packages:

```sh
stow git hypr kitty latex nvim rofi tmux utils-arch waybar wlogout zsh
```

If you want to install a specific package, for example `zsh`:

```sh
stow zsh
```
