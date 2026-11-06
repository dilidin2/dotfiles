#!/usr/bin/env bash
# install.sh — crea i symlink ~/dotfiles → sistema.
# Idempotente: se il target esiste già lo sposta in .bak-<timestamp>.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"

# symlink_file <dest> <source>
# - dest è già un symlink corretto → ok
# - dest è un symlink sbagliato    → rimosso
# - dest è file/directory          → spostato in dest.bak-TS
# - poi crea il symlink
symlink_file() {
    local dest="$1" src="$2"
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        echo "ok    $dest"
        return
    fi
    mkdir -p "$(dirname "$dest")"
    if [ -e "$dest" ]; then
        mv "$dest" "$dest.bak-$TS"
        echo "backup $dest → $dest.bak-$TS"
    fi
    ln -s "$src" "$dest"
    echo "link  $dest → $src"
}

# --- file ---
symlink_file "$HOME/.bashrc"                     "$DOTFILES/bashrc"
symlink_file "$HOME/.zshrc"                      "$DOTFILES/zshrc"
symlink_file "$HOME/.profile"                    "$DOTFILES/profile"
symlink_file "$HOME/.gitconfig"                  "$DOTFILES/gitconfig"
symlink_file "$HOME/.inputrc"                    "$DOTFILES/inputrc"
symlink_file "$HOME/.local/bin/env"              "$DOTFILES/env"
symlink_file "$HOME/.local/bin/env.fish"         "$DOTFILES/env.fish"
symlink_file "$HOME/.config/niri/config.kdl"     "$DOTFILES/niri/config.kdl"
symlink_file "$HOME/.config/niri/basicsettings.kdl" "$DOTFILES/niri/basicsettings.kdl"
symlink_file "$HOME/.config/niri/keybinds.kdl"   "$DOTFILES/niri/keybinds.kdl"
symlink_file "$HOME/.config/ghostty/config"      "$DOTFILES/ghostty/config"

# --- directory ---
symlink_file "$HOME/.config/fish"                "$DOTFILES/fish"
symlink_file "$HOME/.config/quickshell"          "$DOTFILES/quickshell"
symlink_file "$HOME/.config/systemd/user"        "$DOTFILES/systemd/user"

echo
echo "Fatto. Ricarica niri: niri msg action load-config-file"