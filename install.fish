#!/usr/bin/env fish

argparse -n 'install.fish' -X 0 \
    'h/help' \
    'noconfirm' \
    'btop' \
    'neovim' \
    'tmux' \
    'mpv' \
    'spotify' \
    'vscode=?!contains -- "$_flag_value" codium code' \
    'discord' \
    'zen' \
    'cursor' \
    'opencode' \
    'claude-code' \
    'aur-helper=!contains -- "$_flag_value" yay paru' \
    -- $argv
or exit

# Print help
if set -q _flag_h
    echo 'usage: ./install.sh [-h] [--noconfirm] [--btop] [--neovim] [--tmux] [--mpv] [--spotify] [--vscode] [--discord] [--zen] [--cursor] [--opencode] [--claude-code] [--aur-helper]'
    echo
    echo 'options:'
    echo '  -h, --help                  show this help message and exit'
    echo '  --noconfirm                 do not confirm package installation'
    echo '  --btop                      install btop (with --noconfirm)'
    echo '  --neovim                    install neovim (with --noconfirm)'
    echo '  --tmux                      install tmux (with --noconfirm)'
    echo '  --mpv                       install mpv media player'
    echo '  --spotify                   install Spotify (Spicetify)'
    echo '  --vscode=[codium|code]      install VSCodium (or VSCode)'
    echo '  --discord                   install Discord (OpenAsar + Equicord)'
    echo '  --zen                       install Zen browser'
    echo '  --cursor                    install Cursor AI editor'
    echo '  --opencode                  install OpenCode AI CLI'
    echo '  --claude-code               install Claude Code CLI'
    echo '  --aur-helper=[yay|paru]     the AUR helper to use'

    exit
end


# Helper funcs
function _out -a colour text
    set_color $colour
    # Pass arguments other than text to echo
    echo $argv[3..] -- ":: $text"
    set_color normal
    # Also write to log file (no colour codes)
    echo $argv[3..] -- ":: $text" >> $logfile
end

function log -a text
    _out cyan $text $argv[2..]
end

function input -a text
    _out blue $text $argv[2..]
end

function sh-read
    sh -c 'read a && echo -n "$a"' || exit 1
end

function select_optional -d 'Interactive multi-select TUI for optional packages'
    # Usage: select_optional item1 item2 ...
    # Sets global $selected_optional with chosen items
    set -g selected_optional
    set -l items $argv
    set -l count (count $items)
    set -l cursor 1
    # All items start unchecked (0)
    set -l checked
    for i in (seq $count)
        set -a checked 0
    end

    # Note: terminal is in raw mode, so all output must use \r\n (not just \n)

    printf '  \e[36m:: Select optional packages to install:\e[0m\r\n'

    # Initial draw
    for i in (seq $count)
        if test $i -eq $cursor
            printf '\e[1;33m> '
        else
            printf '  '
        end
        if test $checked[$i] -eq 1
            printf '\e[1;32m[x] '
        else
            printf '\e[0m[ ] '
        end
        printf '\e[0m%s\r\n' $items[$i]
    end
    printf '\r\n  (↑/↓ navigate, Space toggle, Enter confirm)'

    # Read keypresses via stty raw
    while true
        # Read a single byte
        set -l byte (dd bs=1 count=1 2>/dev/null | od -An -tx1 | string trim)

        if test "$byte" = '1b' # Escape sequence
            set -l b2 (dd bs=1 count=1 2>/dev/null | od -An -tx1 | string trim)
            if test "$b2" = '5b' # CSI [
                set -l b3 (dd bs=1 count=1 2>/dev/null | od -An -tx1 | string trim)
                if test "$b3" = '41' # Up arrow
                    test $cursor -gt 1 && set cursor (math $cursor - 1)
                else if test "$b3" = '42' # Down arrow
                    test $cursor -lt $count && set cursor (math $cursor + 1)
                end
            end
        else if test "$byte" = '20' # Space - toggle
            if test $checked[$cursor] -eq 0
                set checked[$cursor] 1
            else
                set checked[$cursor] 0
            end
        else if test "$byte" = '0a' -o "$byte" = '0d' # Enter
            break
        end

        # Redraw: move cursor up (count + 1 for the hint line) and clear
        printf '\e[%dA\r' (math $count + 1)
        for i in (seq (math $count + 1))
            printf '\e[2K\r\n'
        end
        printf '\e[%dA\r' (math $count + 1)

        # Redraw menu
        for i in (seq $count)
            if test $i -eq $cursor
                printf '\e[1;33m> '
            else
                printf '  '
            end
            if test $checked[$i] -eq 1
                printf '\e[1;32m[x] '
            else
                printf '\e[0m[ ] '
            end
            printf '\e[0m%s\r\n' $items[$i]
        end
        printf '\r\n  (↑/↓ navigate, Space toggle, Enter confirm)'
    end

    # Collect selected items
    for i in (seq $count)
        if test $checked[$i] -eq 1
            set -a selected_optional $items[$i]
        end
    end

    # Clear hint line and show summary (still in raw mode)
    printf '\r\n'
    if test (count $selected_optional) -eq 0
        printf '  \e[36m:: No optional packages selected.\e[0m\r\n'
    else
        printf '  \e[36m:: Selected: %s\e[0m\r\n' "$selected_optional"
    end
end

function confirm-overwrite -a path
    if test -e $path -o -L $path
        if set -q overwrite_all; or set -q noconfirm
            rm -rf $path
        else
            input "$path already exists. Overwrite? [Y/n] " -n
            set -l confirm (sh-read)

            if test "$confirm" = 'n' -o "$confirm" = 'N'
                log 'Skipping...'
                return 1
            else
                rm -rf $path
            end
        end
    end

    return 0
end


# Log file (must be set before the begin block so 'end 2>> $logfile' can expand it)
if set -q XDG_STATE_HOME
    set -g logfile $XDG_STATE_HOME/caelestia/install-(date +%Y%m%d-%H%M%S).log
else
    set -g logfile $HOME/.local/state/caelestia/install-(date +%Y%m%d-%H%M%S).log
end
mkdir -p (dirname $logfile)
echo "=== Caelestia install log - $(date) ===" > $logfile

begin # stderr from all commands is redirected to the log file

# Save absolute repo path before any cd commands (status filename may be relative)
set -l repo_dir (builtin realpath (dirname (status filename)))

# Variables
set -q _flag_noconfirm && set noconfirm '--noconfirm'
set -q XDG_CONFIG_HOME && set -l config $XDG_CONFIG_HOME || set -l config $HOME/.config
set -q XDG_STATE_HOME && set -l state $XDG_STATE_HOME || set -l state $HOME/.local/state
set -q XDG_DATA_HOME && set -l data $XDG_DATA_HOME || set -l data $HOME/.local/share

# Startup prompt
set_color magenta
echo '╭─────────────────────────────────────────────────╮'
echo '│      ______           __          __  _         │'
echo '│     / ____/___ ____  / /__  _____/ /_(_)___ _   │'
echo '│    / /   / __ `/ _ \/ / _ \/ ___/ __/ / __ `/   │'
echo '│   / /___/ /_/ /  __/ /  __(__  ) /_/ / /_/ /    │'
echo '│   \____/\__,_/\___/_/\___/____/\__/_/\__,_/     │'
echo '│                                                 │'
echo '╰─────────────────────────────────────────────────╯'
set_color normal
log 'Welcome to the Caelestia dotfiles installer!'
log 'Before continuing, please ensure you have made a backup of your config directory.'

# Prompt for backup
if ! set -q _flag_noconfirm
    log '[1] Two steps ahead of you!  [2] Make one for me please!'
    input '=> ' -n
    set -l choice (sh-read)

    if contains -- "$choice" 1 2
        if test $choice = 2
            log "Backing up $config..."

            if test -e $config.bak -o -L $config.bak
                input 'Backup already exists. Overwrite? [Y/n] ' -n
                set -l overwrite (sh-read)

                if test "$overwrite" = 'n' -o "$overwrite" = 'N'
                    log 'Skipping...'
                else
                    rm -rf $config.bak
                    cp -r $config $config.bak
                end
            else
                cp -r $config $config.bak
            end
        end
    else
        log 'No choice selected. Exiting...'
        exit 1
    end

    # Ask once: overwrite all existing configs?
    input 'Overwrite all existing configs without asking? [Y/n] ' -n
    set -l ow (sh-read)
    if test "$ow" != 'n' -a "$ow" != 'N'
        set -g overwrite_all
    end
end

# Detect or select AUR helper
if set -q _flag_aur_helper
    set aur_helper $_flag_aur_helper
else if command -q paru
    set aur_helper paru
    log "Detected $aur_helper."
else if command -q yay
    set aur_helper yay
    log "Detected $aur_helper."
else if set -q _flag_noconfirm
    set aur_helper paru
else
    log '[1] paru  [2] yay'
    input 'Choose AUR helper: ' -n
    set -l aur_choice (sh-read)
    if test "$aur_choice" = 2
        set aur_helper yay
    else
        set aur_helper paru
    end
end

# Install AUR helper if not already installed
if ! pacman -Q $aur_helper &> /dev/null
    log "$aur_helper not installed. Installing..."

    # Install
    sudo pacman -S --needed git base-devel $noconfirm

    # Set rustup default toolchain (required to compile paru/yay)
    if command -q rustup
        rustup default stable
    end

    cd /tmp
    git clone https://aur.archlinux.org/$aur_helper.git
    cd $aur_helper
    makepkg -si
    cd ..
    rm -rf $aur_helper

    # Setup
    if test $aur_helper = yay
        $aur_helper -Y --gendb
        $aur_helper -Y --devel --save
    else
        $aur_helper --gendb
    end
end

# Cd into repo dir
cd $repo_dir || exit 1

# Sync package database (required on fresh installs where the DB may be stale)
log 'Syncing package database...'
sudo pacman -Sy $noconfirm

# Install metapackage for deps
log 'Installing metapackage...'
if test $aur_helper = yay
    $aur_helper -Bi . $noconfirm
else
    $aur_helper -Ui $noconfirm
end

if test $status -ne 0
    log 'ERROR: Metapackage installation failed. Cannot continue without dependencies.'
    log 'Check the log for details and try running the installer again.'
    exit 1
end

fish -c 'rm -f caelestia-meta-*.pkg.tar.zst' 2> /dev/null

# Setup greetd login manager
if systemctl is-enabled greetd &>/dev/null
    log 'greetd already enabled, skipping login manager setup.'
else
    log 'Setting up greetd login manager...'

    # Disable any other display manager if active
    for dm in sddm gdm lightdm lxdm
        if systemctl is-enabled $dm &>/dev/null
            log "Disabling $dm..."
            sudo systemctl disable $dm
        end
    end

    # Install uwsm (required by greetd session launcher)
    $aur_helper -S --needed uwsm $noconfirm

    # Write config and enable
    sudo mkdir -p /etc/greetd
    sudo cp greetd/config.toml /etc/greetd/config.toml
    sudo systemctl enable greetd
    log 'greetd enabled.'
end

# Detect and install Nvidia drivers
if lspci -k | grep -qiE "(VGA|3D).*nvidia"
    log (string join '' 'Nvidia GPU detected: ' (lspci -k | grep -iE "(VGA|3D).*nvidia" | awk -F ': ' '{print $NF}' | head -1))

    # Check if Nvidia is already fully set up
    if pacman -Q nvidia-dkms nvidia-utils egl-wayland &>/dev/null
        and grep -q 'nvidia' /etc/mkinitcpio.conf 2>/dev/null
        and test -f /etc/modprobe.d/nvidia.conf
        and grep -q 'modeset=1' /etc/modprobe.d/nvidia.conf 2>/dev/null
        log 'Nvidia drivers already fully set up, skipping.'
    else
        log 'Installing Nvidia drivers...'

        # Kernel headers for all running kernels
        set -l kbases (string match -r '.*' /usr/lib/modules/*/pkgbase 2>/dev/null)
        if test (count $kbases) -eq 0
            log 'Warning: no kernel pkgbase files found in /usr/lib/modules — skipping header install.'
        else
            for kbase in $kbases
                if test -f $kbase
                    set -l hdr_pkg (cat $kbase)-headers
                    log "Installing kernel headers: $hdr_pkg"
                    $aur_helper -S --needed $hdr_pkg $noconfirm 2>> $logfile
                end
            end
        end

        # Driver + Wayland support packages
        log 'Installing nvidia-dkms, nvidia-utils, egl-wayland...'
        $aur_helper -S --needed nvidia-dkms nvidia-utils egl-wayland $noconfirm 2>> $logfile

        # Wait for DKMS to finish building the nvidia module before running mkinitcpio
        log 'Running dkms autoinstall to build nvidia kernel modules...'
        if ! sudo dkms autoinstall 2>> $logfile
            log 'Warning: dkms autoinstall reported errors — check log for details.'
        end

        # Verify the module was actually built before touching mkinitcpio
        if ! sudo modinfo nvidia &>> $logfile
            log 'Warning: nvidia module not found after DKMS build. Skipping mkinitcpio step to avoid a broken initramfs.'
            log 'You may need to reboot and re-run this script, or install the correct kernel headers manually.'
        else
            # Early module loading (needed for Wayland DRM)
            if ! grep -q 'nvidia' /etc/mkinitcpio.conf
                log 'Adding nvidia modules to mkinitcpio.conf...'
                sudo sed -i '/MODULES=/ s/)$/ nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
                log 'Regenerating initramfs (mkinitcpio -P)...'
                sudo mkinitcpio -P 2>> $logfile
            end
        end

        # DRM modeset kernel parameter
        if ! test -f /etc/modprobe.d/nvidia.conf; or ! grep -q 'modeset=1' /etc/modprobe.d/nvidia.conf
            log 'Setting nvidia-drm modeset=1...'
            echo 'options nvidia-drm modeset=1 fbdev=1' | sudo tee -a /etc/modprobe.d/nvidia.conf >> $logfile
        end

        # Source nvidia.conf in Hyprland via user config
        set -l user_conf $HOME/.config/caelestia/hypr-user.conf
        mkdir -p (dirname $user_conf)
        touch -a $user_conf
        if ! grep -q 'nvidia.conf' $user_conf
            echo 'source = $hl/nvidia.conf' >> $user_conf
        end

        log 'Nvidia setup complete.'
    end
else
    log 'No Nvidia GPU detected, skipping driver installation.'
end

# Install hypr* configs
if confirm-overwrite $config/hypr
    log 'Installing hypr* configs...'
    cp -r hypr $config/hypr
    hyprctl reload
end

# Create user hypr config stubs so Hyprland doesn't error on missing source files
mkdir -p $config/caelestia
touch -a $config/caelestia/hypr-vars.conf
touch -a $config/caelestia/hypr-user.conf

# Monitor layout configuration
set -l user_conf $config/caelestia/hypr-user.conf

if command -q hyprctl && hyprctl monitors -j &>/dev/null
    # Hyprland is running — offer to save current layout
    set -l mon_json (hyprctl monitors -j 2>/dev/null)
    set -l mon_count (echo $mon_json | jq 'length')

    if test "$mon_count" -gt 0
        log 'Detected monitor layout:'
        for i in (seq 0 (math $mon_count - 1))
            set -l name (echo $mon_json | jq -r ".[$i].name")
            set -l width (echo $mon_json | jq -r ".[$i].width")
            set -l height (echo $mon_json | jq -r ".[$i].height")
            set -l rate (echo $mon_json | jq -r ".[$i].refreshRate" | cut -d. -f1)
            set -l x (echo $mon_json | jq -r ".[$i].x")
            set -l y (echo $mon_json | jq -r ".[$i].y")
            set -l scale (echo $mon_json | jq -r ".[$i].scale")
            set -l transform (echo $mon_json | jq -r ".[$i].transform")

            if test "$transform" != "0"
                log "  $name: {$width}x{$height}@{$rate}Hz at {$x},{$y} scale=$scale transform=$transform (portrait)"
            else
                log "  $name: {$width}x{$height}@{$rate}Hz at {$x},{$y} scale=$scale"
            end
        end

        set -l save_monitors yes
        if ! set -q _flag_noconfirm
            input 'Save this monitor layout to hypr-user.conf? [Y/n] ' -n
            set -l confirm (sh-read)
            if test "$confirm" = 'n' -o "$confirm" = 'N'
                set save_monitors no
            end
        end

        if test "$save_monitors" = yes
            log 'Saving monitor layout...'
            sed -i '/^monitor\s*=/d' $user_conf

            for i in (seq 0 (math $mon_count - 1))
                set -l name (echo $mon_json | jq -r ".[$i].name")
                set -l width (echo $mon_json | jq -r ".[$i].width")
                set -l height (echo $mon_json | jq -r ".[$i].height")
                set -l rate (echo $mon_json | jq -r ".[$i].refreshRate" | cut -d. -f1)
                set -l x (echo $mon_json | jq -r ".[$i].x")
                set -l y (echo $mon_json | jq -r ".[$i].y")
                set -l scale (echo $mon_json | jq -r ".[$i].scale")
                set -l transform (echo $mon_json | jq -r ".[$i].transform")

                if test "$transform" != "0"
                    echo "monitor = $name, {$width}x{$height}@$rate, {$x}x{$y}, $scale, transform, $transform" >> $user_conf
                else
                    echo "monitor = $name, {$width}x{$height}@$rate, {$x}x{$y}, $scale" >> $user_conf
                end
            end

            log 'Monitor layout saved.'
        end
    end
else
    # Hyprland not running — offer preset monitor configs
    log 'Hyprland is not running. Choose a monitor configuration:'
    log '[1] Default (auto-detect all monitors)'
    log '    monitor = , preferred, auto, 1'
    log "[2] Author's config (eDP-1 + HDMI portrait)"
    log '    monitor = eDP-1, 2560x1600@120, 0x0, 1.60'
    log '    monitor = HDMI-A-1, 1920x1080@60, 1600x-920, 1.00, transform, 3'
    log '    WARNING: If you are not the author, this will likely break your monitor layout!'
    log '[3] Skip (configure manually later in ~/.config/caelestia/hypr-user.conf)'

    set -l mon_choice 1
    if set -q _flag_noconfirm
        set mon_choice 1
    else
        input 'Choose [1/2/3]: ' -n
        set mon_choice (sh-read)
    end

    sed -i '/^monitor\s*=/d' $user_conf

    switch "$mon_choice"
        case 1
            log 'Applying default monitor config...'
            echo 'monitor = , preferred, auto, 1' >> $user_conf
        case 2
            log "Applying author's monitor config..."
            echo 'monitor = eDP-1, 2560x1600@120, 0x0, 1.60' >> $user_conf
            echo 'monitor = HDMI-A-1, 1920x1080@60, 1600x-920, 1.00, transform, 3' >> $user_conf
        case 3 '*'
            log 'Skipping monitor config.'
    end
end

# Starship
if confirm-overwrite $config/starship.toml
    log 'Installing starship config...'
    cp starship.toml $config/starship.toml
end

# Maple Mono NF (custom build, bundled in repo)
set -l font_dir $HOME/.local/share/fonts/MapleMono-NF
if ! test -d $font_dir
    if test -f fonts/MapleMono-NF/MapleMono-NF-Regular.ttf
        log 'Installing Maple Mono NF fonts...'
        mkdir -p $font_dir
        cp fonts/MapleMono-NF/*.ttf $font_dir/
        fc-cache -f $font_dir
    else
        log 'Warning: Maple Mono NF font files not found, skipping.'
    end
end

# Kitty
if confirm-overwrite $config/kitty
    log 'Installing kitty config...'
    cp -r kitty $config/kitty
end

# Fish
if confirm-overwrite $config/fish
    log 'Installing fish config...'
    cp -r fish $config/fish
end

# Fastfetch
if confirm-overwrite $config/fastfetch
    log 'Installing fastfetch config...'
    cp -r fastfetch $config/fastfetch
end

# Uwsm
if confirm-overwrite $config/uwsm
    log 'Installing uwsm config...'
    cp -r uwsm $config/uwsm
end

# Kvantum
mkdir -p $config/Kvantum
if confirm-overwrite $config/Kvantum/kvantum.kvconfig
    log 'Installing Kvantum config...'
    cp Kvantum/kvantum.kvconfig $config/Kvantum/kvantum.kvconfig
end

# Dracula Kvantum theme (inside dracula/gtk repo under kde/kvantum/)
if ! test -d $config/Kvantum/Dracula
    log 'Installing Dracula Kvantum theme...'
    curl -sL https://github.com/dracula/gtk/archive/refs/heads/master.tar.gz \
        | tar -xz -C /tmp/ --wildcards '*/kde/kvantum/Dracula/*' --strip-components=3
    cp -r /tmp/Dracula $config/Kvantum/
    rm -rf /tmp/Dracula
end

# Qt5ct
if confirm-overwrite $config/qt5ct
    log 'Installing qt5ct config...'
    cp -r qt5ct $config/qt5ct
end

# Qt6ct
if confirm-overwrite $config/qt6ct
    log 'Installing qt6ct config...'
    cp -r qt6ct $config/qt6ct
end

# Dolphin (all dolphin files grouped under one confirm)
if confirm-overwrite $config/dolphinrc
    log 'Installing dolphin configs...'
    cp dolphinrc $config/dolphinrc
    command -q xdg-mime && xdg-mime default org.kde.dolphin.desktop inode/directory
    rm -rf $state/dolphinstaterc $data/kxmlgui5/dolphin/dolphinui.rc $data/dolphin/view_properties/global/.directory
    mkdir -p $state $data/kxmlgui5/dolphin $data/dolphin/view_properties/global
    cp dolphin/dolphinstaterc $state/dolphinstaterc
    cp dolphin/kxmlgui5/dolphinui.rc $data/kxmlgui5/dolphin/dolphinui.rc
    cp dolphin/view_properties/global/.directory $data/dolphin/view_properties/global/.directory
end

# KDE globals (transparent view, kitty terminal, Papirus icons)
if confirm-overwrite $config/kdeglobals
    log 'Installing kdeglobals...'
    cp kdeglobals $config/kdeglobals
end

# Optional packages — TUI selection or flag-based (--noconfirm)
set -l optional_items btop neovim tmux mpv spotify 'vscode (codium)' 'vscode (code)' discord zen cursor opencode claude-code

if set -q _flag_noconfirm
    # Auto-select based on CLI flags (no TUI)
    set -g selected_optional
    set -q _flag_btop && set -a selected_optional btop
    set -q _flag_neovim && set -a selected_optional neovim
    set -q _flag_tmux && set -a selected_optional tmux
    set -q _flag_mpv && set -a selected_optional mpv
    set -q _flag_spotify && set -a selected_optional spotify
    if set -q _flag_vscode
        if test -n "$_flag_vscode"
            set -a selected_optional "vscode ($_flag_vscode)"
        else
            set -a selected_optional 'vscode (codium)'
        end
    end
    set -q _flag_discord && set -a selected_optional discord
    set -q _flag_zen && set -a selected_optional zen
    set -q _flag_cursor && set -a selected_optional cursor
    set -q _flag_opencode && set -a selected_optional opencode
    set -q _flag_claude_code && set -a selected_optional claude-code
else
    # Interactive TUI
    stty raw -echo
    select_optional $optional_items
    stty sane
end

# Install selected optional packages

# Btop
if contains btop $selected_optional
    if confirm-overwrite $config/btop
        log 'Installing btop config...'
        cp -r btop $config/btop
    end
end

# Neovim
if contains neovim $selected_optional
    if confirm-overwrite $config/nvim
        log 'Installing neovim config...'
        cp -r nvim $config/nvim
    end
end

# Tmux
if contains tmux $selected_optional
    if confirm-overwrite $config/tmux/tmux.conf
        log 'Installing tmux config...'
        mkdir -p $config/tmux
        cp tmux/tmux.conf $config/tmux/tmux.conf
    end

    # TPM (tmux plugin manager)
    if ! test -d $config/tmux/plugins/tpm
        log 'Installing TPM...'
        git clone https://github.com/tmux-plugins/tpm $config/tmux/plugins/tpm
        log 'Installing tmux plugins...'
        $config/tmux/plugins/tpm/scripts/install_plugins.sh
    end
end

# Mpv
if contains mpv $selected_optional
    log 'Installing mpv...'
    $aur_helper -S --needed mpv mpv-mpris yt-dlp $noconfirm
    $aur_helper -S --needed mpv-uosc mpv-thumbfast-git mpv-quality-menu-git $noconfirm

    if confirm-overwrite $config/mpv
        log 'Installing mpv config...'
        mkdir -p $config/mpv/{scripts,script-opts,fonts}
        cp mpv/mpv.conf mpv/input.conf $config/mpv/
        cp mpv/script-opts/* $config/mpv/script-opts/

        # uosc symlinks
        ln -sf /usr/share/mpv/scripts/uosc $config/mpv/scripts/uosc
        ln -sf /usr/share/mpv/fonts/uosc_icons.otf $config/mpv/fonts/
        ln -sf /usr/share/mpv/fonts/uosc_textures.ttf $config/mpv/fonts/

        # sponsorblock
        log 'Installing mpv sponsorblock...'
        curl -fsSL -o $config/mpv/scripts/sponsorblock.lua \
            https://raw.githubusercontent.com/po5/mpv_sponsorblock/master/sponsorblock.lua
        mkdir -p $config/mpv/scripts/sponsorblock_shared
        curl -fsSL -o $config/mpv/scripts/sponsorblock_shared/main.lua \
            https://raw.githubusercontent.com/po5/mpv_sponsorblock/master/sponsorblock_shared/main.lua
        curl -fsSL -o $config/mpv/scripts/sponsorblock_shared/sponsorblock.py \
            https://raw.githubusercontent.com/po5/mpv_sponsorblock/master/sponsorblock_shared/sponsorblock.py
    end
end

# Spotify (Spicetify)
if contains spotify $selected_optional
    log 'Installing spotify (spicetify)...'

    set -l has_spicetify (pacman -Q spicetify-cli 2> /dev/null)
    $aur_helper -S --needed spotify spicetify-cli spicetify-marketplace-bin $noconfirm

    # Set permissions and init if new install
    if test -z "$has_spicetify"
        sudo chmod a+wr /opt/spotify
        sudo chmod a+wr /opt/spotify/Apps -R
        spicetify backup apply
    end

    # Install configs
    if confirm-overwrite $config/spicetify
        log 'Installing spicetify config...'
        cp -r spicetify $config/spicetify

        # Set spicetify configs
        spicetify config current_theme caelestia color_scheme caelestia custom_apps marketplace 2> /dev/null
        spicetify apply
    end
end

# VSCode / VSCodium
if contains 'vscode (codium)' $selected_optional; or contains 'vscode (code)' $selected_optional
    set -l prog codium
    set -l packages vscodium-bin vscodium-bin-marketplace
    set -l vsc_folder VSCodium
    if contains 'vscode (code)' $selected_optional
        set prog code
        set packages code
        set vsc_folder Code
    end
    set -l folder $config/$vsc_folder/User

    log "Installing vs$prog..."
    $aur_helper -S --needed $packages $noconfirm

    # Install configs
    if confirm-overwrite $folder/settings.json && confirm-overwrite $folder/keybindings.json && confirm-overwrite $config/$prog-flags.conf
        log "Installing vs$prog config..."
        mkdir -p $folder
        cp vscode/settings.json $folder/settings.json
        cp vscode/keybindings.json $folder/keybindings.json
        cp vscode/flags.conf $config/$prog-flags.conf

        # Install extension
        $prog --install-extension vscode/caelestia-vscode-integration/caelestia-vscode-integration-*.vsix
    end
end

# Discord
if contains discord $selected_optional
    log 'Installing discord...'
    $aur_helper -S --needed discord equicord-installer-bin $noconfirm

    # Install OpenAsar and Equicord
    sudo Equilotl -install -location /opt/discord
    sudo Equilotl -install-openasar -location /opt/discord

    # Remove installer
    $aur_helper -Rns equicord-installer-bin $noconfirm
end

# Zen browser
if contains zen $selected_optional
    log 'Installing zen...'
    $aur_helper -S --needed zen-browser-bin $noconfirm

    # Set as default browser
    xdg-settings set default-web-browser zen.desktop
    for mime in text/html x-scheme-handler/http x-scheme-handler/https \
                application/x-extension-html application/xhtml+xml
        xdg-mime default zen.desktop $mime
    end

    # Install userChrome css
    set -l chrome $HOME/.zen/*/chrome
    if confirm-overwrite $chrome/userChrome.css
        log 'Installing zen userChrome...'
        cp zen/userChrome.css $chrome/userChrome.css
    end

    # Install native app
    set -l hosts $HOME/.mozilla/native-messaging-hosts
    set -l lib $HOME/.local/lib/caelestia

    if confirm-overwrite $hosts/caelestiafox.json
        log 'Installing zen native app manifest...'
        mkdir -p $hosts
        cp zen/native_app/manifest.json $hosts/caelestiafox.json
        sed -i "s|{{ \$lib }}|$lib|g" $hosts/caelestiafox.json
    end

    if confirm-overwrite $lib/caelestiafox
        log 'Installing zen native app...'
        mkdir -p $lib
        cp zen/native_app/app.fish $lib/caelestiafox
    end

    # Prompt user to install extension
    log 'Please install the CaelestiaFox extension from https://addons.mozilla.org/en-US/firefox/addon/caelestiafox if you have not already done so.'
end

# Cursor
if contains cursor $selected_optional
    log 'Installing Cursor AI editor...'
    $aur_helper -S --needed cursor-bin $noconfirm
end

# OpenCode
if contains opencode $selected_optional
    log 'Installing OpenCode...'
    $aur_helper -S --needed opencode $noconfirm
end

# Claude Code
if contains claude-code $selected_optional
    log 'Installing Claude Code...'
    $aur_helper -S --needed claude-code $noconfirm
end

# Install quickshell overrides
set -l qs_overrides quickshell-overrides
set -l qs_config /etc/xdg/quickshell/caelestia

log 'Installing quickshell overrides...'
for file in (find $qs_overrides -type f)
    set -l rel (string replace "$qs_overrides/" "" $file)
    set -l target $qs_config/$rel
    sudo mkdir -p (dirname $target)
    sudo cp -f $file $target
end

# Generate scheme stuff if needed
if ! test -f $state/caelestia/scheme.json
    caelestia scheme set -n shadotheme
    sleep .5
    hyprctl reload
end

# Set default wallpaper if none is set
if ! test -f $state/caelestia/wallpaper/path.txt
    set -l wallpapers_dir $HOME/Pictures/Wallpapers
    set -l default_wall (pwd)/wallpapers/default.jpg

    # Copy bundled default to wallpapers dir
    mkdir -p $wallpapers_dir
    cp -n $default_wall $wallpapers_dir/ 2>/dev/null

    log 'Setting default wallpaper...'
    caelestia wallpaper -f $wallpapers_dir/default.jpg
end

# (Re)start the shell
pkill -x qs 2> /dev/null
sleep .5
caelestia shell -d > /dev/null

log 'Done!'
log "Install log written to: $logfile"

end 2>> $logfile
