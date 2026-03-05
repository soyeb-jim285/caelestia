# caelestia (fork)

A personalized fork of [caelestia-dots/caelestia](https://github.com/caelestia-dots/caelestia) with an overhauled installer, additional app configs, and various fixes.

## What's different from upstream

### Overhauled Installer

- Interactive TUI for selecting optional packages (arrow keys + space to toggle)
- Automatic Nvidia GPU detection and env setup at session startup (`uwsm/env.d/01-gpu.sh`)
- Hyprland `nvidia.conf` with proper env vars and `no_hardware_cursors`
- `greetd` + `tuigreet` login manager setup out of the box
- Batched optional package installs with no invisible prompts
- Install logging to file
- Auto-clones and applies quickshell overrides
- Fixes for fresh installs: monitor config, cursor theme, wallpaper, shell restart

### New App Configs

- **Kitty** terminal (replaces foot) with Maple Mono NF, beam cursor, 0.6 opacity
- **Neovim** with LazyVim setup
- **tmux** with TPM and plugins
- **mpv** media player with custom keybinds, uosc, and thumbfast
- **Dolphin** file manager (replaces Thunar) with panel layout, kdeglobals, and view properties
- **btop** resource monitor

### Theming Changes

- Dracula Kvantum theme (replaces Catppuccin)
- Tela-circle-dracula icon theme
- Sweet-cursors-hyprcursor cursor theme
- Maple Mono NF font bundled (4 variants, no AUR dependency)
- qt5ct/qt6ct configured with Kvantum style
- Shadows disabled, tighter gaps (`6`/`5`/`8`), opaque windows by default
- Thinner window borders (`1px` vs `3px`)

### Input Changes

- Caps Lock remapped to Escape (`caps:escape`)

### Extra Install Flags

- `--cursor` - Cursor AI editor
- `--opencode` - OpenCode AI CLI
- `--claude-code` - Claude Code CLI
- `--neovim`, `--tmux`, `--mpv`, `--btop`

### Other Changes

- Quickshell overrides: custom status icons bar and network speed widget
- Custom starship prompt config
- Zen browser set as default on install
- Monitor rotation toggle script (`hypr/scripts/toggle-monitor-rotation.sh`)
- Screenshots now copy to clipboard by default
- fish config: `~/.local/bin` and `~/.npm-global/bin` added to PATH
- Nautilus transparency rule (0.95 opacity)

## Installation

Clone and run the install script (requires [`fish`](https://github.com/fish-shell/fish-shell)):

> [!WARNING]
> The install script symlinks configs into place -- do NOT move/remove the repo
> folder afterwards. Recommended location: `~/.local/share/caelestia`.

```sh
git clone https://github.com/soyeb-jim285/caelestia.git ~/.local/share/caelestia
~/.local/share/caelestia/install.fish
```

### Options

```
usage: ./install.fish [-h] [--noconfirm] [--btop] [--neovim] [--tmux] [--mpv]
                      [--spotify] [--vscode] [--discord] [--zen] [--cursor]
                      [--opencode] [--claude-code] [--aur-helper=[yay|paru]]
```

## Updating

```sh
cd ~/.local/share/caelestia
git pull
```

## Keybinds

### Apps

| Keybind | Action |
|---------|--------|
| `Super + Return` | Open terminal (kitty) |
| `Super + W` | Open browser (zen) |
| `Super + C` | Open editor (codium) |
| `Super + E` | Open file explorer (dolphin) |
| `Super + G` | Open GitHub Desktop |

### Window Management

| Keybind | Action |
|---------|--------|
| `Super + Arrow Keys` | Move focus |
| `Super + Shift + Arrow Keys` | Move window |
| `Super + -/=` | Resize split ratio |
| `Super + F` | Fullscreen |
| `Super + Q` | Close window |

### Workspaces

| Keybind | Action |
|---------|--------|
| `Super` | Open launcher |
| `Super + #` | Switch to workspace # |
| `Super + Alt + #` | Move window to workspace # |
| `Super + S` | Toggle special workspace |
| `Super + Mouse Scroll` | Switch workspace |

### Media & Utilities

| Keybind | Action |
|---------|--------|
| `Ctrl + Super + Space` | Toggle media play/pause |
| `Ctrl + Super + =/−` | Next/previous track |
| `Print` | Screenshot (full screen) |
| `Super + Shift + S` | Screenshot region (freeze) |
| `Super + Alt + R` | Record screen with sound |
| `Super + Shift + C` | Color picker |
| `Super + V` | Clipboard history |
| `Super + .` | Emoji picker |

### Session

| Keybind | Action |
|---------|--------|
| `Ctrl + Alt + Delete` | Session menu |
| `Super + Shift + L` | Suspend |
| `Ctrl + Super + Shift + R` | Kill shell |
| `Ctrl + Super + Alt + R` | Restart shell |

## Credits

Based on [caelestia-dots](https://github.com/caelestia-dots/caelestia) by the original authors.
