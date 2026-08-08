#!/usr/bin/env bash
# theme-switcher.sh - Switch themes using wofi
# Usage: theme-switcher.sh (interactive) or theme-switcher.sh <theme-name>

set -e

THEMES_DIR="$HOME/.themes"
CURRENT_THEME_FILE="$THEMES_DIR/.current-theme"
SCRIPTS_DIR="$THEMES_DIR/_scripts"

# List available themes
list_themes() {
    for dir in "$THEMES_DIR"/*/; do
        if [[ -f "$dir/theme.json" ]]; then
            basename "$dir"
        fi
    done
}

# Get current theme
get_current_theme() {
    if [[ -f "$CURRENT_THEME_FILE" ]]; then
        cat "$CURRENT_THEME_FILE"
    fi
}

# Apply colors from theme.json to all configs
apply_theme() {
    local theme="$1"
    local theme_dir="$THEMES_DIR/$theme"
    local json_file="$theme_dir/theme.json"

    if [[ ! -f "$json_file" ]]; then
        echo "Error: Theme '$theme' not found or missing theme.json" >&2
        exit 1
    fi

    echo "Applying theme: $theme"

    # Save current theme
    echo "$theme" > "$CURRENT_THEME_FILE"

    # Apply colors using Python (more reliable for JSON parsing)
    python3 << PYEOF
import json
import os
import re
import subprocess
from pathlib import Path

THEMES_DIR = Path("$THEMES_DIR")
HOME = Path("$HOME")
THEME = "$theme"
THEME_DIR = THEMES_DIR / THEME

with open(THEME_DIR / "theme.json") as f:
    theme = json.load(f)

C = theme["colors"]

def rgb(c):
    return f"{int(c[1:3], 16)}, {int(c[3:5], 16)}, {int(c[5:7], 16)}"

def hex_raw(c):
    """Return hex color without # prefix (for foot, fish, swaylock)."""
    return c[1:] if c.startswith("#") else c

# ─── Sway ───
config = HOME / ".config" / "sway" / "config"
if config.exists():
    content = config.read_text()
    lines = content.split("\n")
    new_lines = []
    for line in lines:
        s = line.strip()
        if s.startswith("client.focused           "):
            new_lines.append(f"client.focused           {C['bg']}   {C['bg']}     {C['text']}    {C['bg']}     {C['bg']}")
        elif s.startswith("client.focused_inactive"):
            new_lines.append(f"client.focused_inactive  {C['text-muted']}   {C['bg-secondary']}     {C['text-muted']}    {C['text-muted']}     {C['text-muted']}")
        elif s.startswith("client.unfocused         "):
            new_lines.append(f"client.unfocused         {C['bg-hover']}   {C['bg']}     {C['text-muted']}    {C['bg-hover']}     {C['bg-hover']}")
        elif s.startswith("client.urgent            "):
            new_lines.append(f"client.urgent             {C['accent']}  {C['bg']}     {C['text']}    {C['accent']}     {C['accent']}")
        elif s.startswith("client.placeholder        "):
            new_lines.append(f"client.placeholder        {C['bg-hover']}  {C['bg']}     {C['text-muted']}    {C['bg-hover']}     {C['bg-hover']}")
        else:
            new_lines.append(line)
    config.write_text("\n".join(new_lines))
    print("  ✓ Sway colors updated")

# ─── Waybar CSS ───
css = HOME / ".config" / "waybar" / "style.css"
if css.exists():
    content = css.read_text()
    replacements = {
        r'@define-color bg-primary\s+[^;]+': f"@define-color bg-primary       {C['bg']}",
        r'@define-color bg-secondary\s+[^;]+': f"@define-color bg-secondary     {C['bg-secondary']}",
        r'@define-color bg-hover\s+[^;]+': f"@define-color bg-hover         {C['bg-hover']}",
        r'@define-color salmon-primary\s+[^;]+': f"@define-color salmon-primary   {C['primary']}",
        r'@define-color salmon-light\s+[^;]+': f"@define-color salmon-light     {C['primary-light']}",
        r'@define-color salmon-dark\s+[^;]+': f"@define-color salmon-dark      {C['primary-dark']}",
        r'@define-color salmon-muted\s+[^;]+': f"@define-color salmon-muted     {C['primary-dark']}",
        r'@define-color salmon-urgent\s+[^;]+': f"@define-color salmon-urgent    {C['accent-urgent']}",
        r'@define-color text-white\s+[^;]+': f"@define-color text-white       {C['text']}",
        r'@define-color text-primary\s+[^;]+': f"@define-color text-primary     {C['text-primary']}",
        r'@define-color text-secondary\s+[^;]+': f"@define-color text-secondary   {C['text-secondary']}",
        r'@define-color text-dim\s+[^;]+': f"@define-color text-dim         {C['text-muted']}",
    }
    for pattern, replacement in replacements.items():
        content = re.sub(pattern, replacement, content)
    css.write_text(content)
    print("  ✓ Waybar colors updated")

# ─── Wofi CSS ───
# NOTA: richiede che ~/.config/wofi/style.css definisca queste @define-color
# (bg-92, bg-80, bg-60, border-25, primary, text, muted) invece di valori
# hardcoded. Match per NOME, non per valore -> funziona ad ogni switch.
css = HOME / ".config" / "wofi" / "style.css"
if css.exists():
    content = css.read_text()
    replacements = {
        r'@define-color bg-92\s+[^;]+': f"@define-color bg-92      rgba({rgb(C['bg'])}, 0.92)",
        r'@define-color bg-80\s+[^;]+': f"@define-color bg-80      rgba({rgb(C['bg'])}, 0.80)",
        r'@define-color bg-60\s+[^;]+': f"@define-color bg-60      rgba({rgb(C['bg'])}, 0.60)",
        r'@define-color border-25\s+[^;]+': f"@define-color border-25  rgba({rgb(C['primary'])}, 0.25)",
        r'@define-color primary\s+[^;]+': f"@define-color primary    {C['primary']}",
        r'@define-color text\s+[^;]+': f"@define-color text       {C['text']}",
        r'@define-color muted\s+[^;]+': f"@define-color muted      {C['text-muted']}",
    }
    for pattern, replacement in replacements.items():
        content = re.sub(pattern, replacement, content)
    css.write_text(content)
    print("  ✓ Wofi colors updated")

# ─── SwayNC CSS ───
# NOTA: richiede che ~/.config/swaync/style.css definisca anche
# bg-hover, bg-active, border-active, muted-20, primary-30, primary-50
# come @define-color (prima erano scritte a mano e non venivano MAI
# aggiornate dallo switch).
css = HOME / ".config" / "swaync" / "style.css"
if css.exists():
    content = css.read_text()
    replacements = {
        r'@define-color bg\s+[^;]+': f"@define-color bg               rgba({rgb(C['bg'])}, 0.95)",
        r'@define-color bg-secondary\s+[^;]+': f"@define-color bg-secondary     rgba({rgb(C['bg-secondary'])}, 0.8)",
        r'@define-color bg-hover\s+[^;]+': f"@define-color bg-hover         rgba({rgb(C['primary-light'])}, 0.1)",
        r'@define-color bg-active\s+[^;]+': f"@define-color bg-active        rgba({rgb(C['primary-light'])}, 0.15)",
        r'@define-color primary\s+[^;]+': f"@define-color primary          {C['lavender']}",
        r'@define-color secondary\s+[^;]+': f"@define-color secondary        {C['lavender-dark']}",
        r'@define-color accent\s+[^;]+': f"@define-color accent           {C['accent']}",
        r'@define-color light\s+[^;]+': f"@define-color light            {C['primary-light']}",
        r'@define-color border\s+[^;]+': f"@define-color border           rgba({rgb(C['lavender'])}, 0.25)",
        r'@define-color border-active\s+[^;]+': f"@define-color border-active    {C['lavender']}",
        r'@define-color text\s+[^;]+': f"@define-color text             {C['text']}",
        r'@define-color text-secondary\s+[^;]+': f"@define-color text-secondary   {C['text-muted']}",
        r'@define-color muted-20\s+[^;]+': f"@define-color muted-20         rgba({rgb(C['text-muted'])}, 0.2)",
        r'@define-color primary-30\s+[^;]+': f"@define-color primary-30       rgba({rgb(C['primary'])}, 0.3)",
        r'@define-color primary-50\s+[^;]+': f"@define-color primary-50       rgba({rgb(C['primary'])}, 0.5)",
    }
    for pattern, replacement in replacements.items():
        content = re.sub(pattern, replacement, content)
    css.write_text(content)
    print("  ✓ SwayNC colors updated")

# ─── Foot ───
config = HOME / ".config" / "foot" / "foot.ini"
if config.exists():
    content = config.read_text()
    lines = content.split("\n")
    new_lines = []
    in_colors = False
    for line in lines:
        if line.strip() == "[colors]":
            in_colors = True
            new_lines.append(line)
            continue
        if line.strip().startswith("[") and in_colors:
            in_colors = False
        if in_colors:
            s = line.strip()
            if s.startswith("background="):
                new_lines.append(f"background={hex_raw(C['bg'])}")
            elif s.startswith("foreground="):
                new_lines.append(f"foreground={hex_raw(C['text-primary'])}")
            elif s.startswith("regular0="):
                new_lines.append(f"regular0={hex_raw(C['bg-secondary'])}")
            elif s.startswith("regular1="):
                new_lines.append(f"regular1={hex_raw(C['accent'])}")
            elif s.startswith("regular2="):
                new_lines.append(f"regular2={hex_raw(C['terminal-green'])}")
            elif s.startswith("regular3="):
                new_lines.append(f"regular3={hex_raw(C['terminal-yellow'])}")
            elif s.startswith("regular4="):
                new_lines.append(f"regular4={hex_raw(C['terminal-blue'])}")
            elif s.startswith("regular5="):
                new_lines.append(f"regular5={hex_raw(C['lavender'])}")
            elif s.startswith("regular6="):
                new_lines.append(f"regular6={hex_raw(C['terminal-cyan'])}")
            elif s.startswith("regular7="):
                new_lines.append(f"regular7={hex_raw(C['text-primary'])}")
            elif s.startswith("bright0="):
                new_lines.append(f"bright0={hex_raw(C['bg-hover'])}")
            elif s.startswith("bright1="):
                new_lines.append(f"bright1={hex_raw(C['primary-light'])}")
            elif s.startswith("bright5="):
                new_lines.append(f"bright5={hex_raw(C['primary-light'])}")
            elif s.startswith("selection-background="):
                new_lines.append(f"selection-background={hex_raw(C['lavender'])}")
            elif s.startswith("urls="):
                new_lines.append(f"urls={hex_raw(C['lavender'])}")
            else:
                new_lines.append(line)
        else:
            new_lines.append(line)
    config.write_text("\n".join(new_lines))
    print("  ✓ Foot colors updated")

# ─── Swaylock ───
config = HOME / ".config" / "swaylock" / "config"
if config.exists():
    content = config.read_text()
    content = re.sub(r'--color=\w+', f'--color={C["bg"][1:]}', content)
    content = re.sub(r'--key-hl-color=\w+', f'--key-hl-color={C["lavender"][1:]}', content)
    content = re.sub(r'--caps-lock-bs-hl-color=\w+', f'--caps-lock-bs-hl-color={C["accent"][1:]}', content)
    content = re.sub(r'--caps-lock-key-hl-color=\w+', f'--caps-lock-key-hl-color={C["accent"][1:]}', content)
    content = re.sub(r'--text-color=\w+', f'--text-color={C["text"][1:]}', content)
    config.write_text(content)
    print("  ✓ Swaylock colors updated")

# ─── Wlogout CSS ───
# NOTA: richiede @define-color in ~/.config/wlogout/style.css
# (bg-92, bg-60, border-25, primary-18, primary, text, muted).
css = HOME / ".config" / "wlogout" / "style.css"
if css.exists():
    content = css.read_text()
    replacements = {
        r'@define-color bg-92\s+[^;]+': f"@define-color bg-92      rgba({rgb(C['bg'])}, 0.92)",
        r'@define-color bg-60\s+[^;]+': f"@define-color bg-60      rgba({rgb(C['bg'])}, 0.60)",
        r'@define-color border-25\s+[^;]+': f"@define-color border-25  rgba({rgb(C['primary'])}, 0.25)",
        r'@define-color primary-18\s+[^;]+': f"@define-color primary-18 rgba({rgb(C['primary'])}, 0.18)",
        r'@define-color primary\s+[^;]+': f"@define-color primary    {C['primary']}",
        r'@define-color text\s+[^;]+': f"@define-color text       {C['text']}",
        r'@define-color muted\s+[^;]+': f"@define-color muted      {C['text-muted']}",
    }
    for pattern, replacement in replacements.items():
        content = re.sub(pattern, replacement, content)
    css.write_text(content)
    print("  ✓ Wlogout colors updated")

# ─── Fish prompt ───
# IMPORTANTE: config.fish viene RIGENERATO ogni volta a partire dal
# template ~/.themes/_templates/config.fish.template, che contiene i
# marker THEME_* e non viene mai toccato. Prima lo script faceva
# replace+restore sullo STESSO file che fish legge: il restore annullava
# la sostituzione prima ancora di scrivere, quindi i colori non
# cambiavano mai davvero.
template = THEMES_DIR / "_templates" / "config.fish.template"
config = HOME / ".config" / "fish" / "config.fish"
if template.exists():
    content = template.read_text()
    # Marker più lunghi PRIMA (es. THEME_LAVENDER_DARK contiene THEME_LAVENDER)
    content = content.replace("THEME_LAVENDER_DARK", hex_raw(C["lavender-dark"]))
    content = content.replace("THEME_TEXT_PRIMARY", hex_raw(C["text-primary"]))
    content = content.replace("THEME_LAVENDER", hex_raw(C["lavender"]))
    content = content.replace("THEME_ACCENT", hex_raw(C["accent"]))
    content = content.replace("THEME_ERROR", hex_raw(C["accent-urgent"]))
    content = content.replace("THEME_USER", hex_raw(C["primary-light"]))
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text(content)
    print("  ✓ Fish colors updated")
elif config.exists():
    print("  ⚠ Fish template not found, skipping (~/.themes/_templates/config.fish.template)")

# ─── Fastfetch ───
# Pattern generico sul formato "38;2;R;G;B" invece che sul valore
# hardcoded del tema light-pink originale: matcha qualsiasi colore
# attualmente presente, quindi funziona ad ogni switch successivo.
config = HOME / ".config" / "fastfetch" / "config.jsonc"
if config.exists():
    content = config.read_text()
    primary_rgb = f"{int(C['primary'][1:3], 16)};{int(C['primary'][3:5], 16)};{int(C['primary'][5:7], 16)}"
    content = re.sub(r'38;2;\d+;\d+;\d+', f'38;2;{primary_rgb}', content)
    config.write_text(content)
    print("  ✓ Fastfetch colors updated")

# ─── Set wallpaper ───
bg_path = THEMES_DIR / "backgrounds" / THEME / "background.png"
if bg_path.exists():
    # Update sway config wallpaper path
    sway_config = HOME / ".config" / "sway" / "config"
    if sway_config.exists():
        content = sway_config.read_text()
        content = re.sub(
            r'output \* bg .+ fill',
            f'output * bg {bg_path} fill',
            content
        )
        sway_config.write_text(content)
        print(f"  ✓ Wallpaper set: {bg_path}")
else:
    print(f"  ⚠ No wallpaper found for theme '{THEME}'")

PYEOF

    # Restart services that pick up changes immediately
    echo ""
    echo "Restarting services..."

    if pgrep -x waybar &>/dev/null; then
        pkill waybar 2>/dev/null
        sleep 0.3
        waybar --config "$HOME/.config/waybar/config.json" &>/dev/null &
        echo "  ✓ Waybar restarted"
    fi

    if pgrep -x swaync &>/dev/null; then
        pkill swaync 2>/dev/null
        sleep 0.3
        swaync &>/dev/null &
        echo "  ✓ SwayNC restarted"
    fi

    # Reload sway and apply wallpaper
    echo ""
    echo "Reloading Sway..."
    if command -v swaymsg &>/dev/null; then
        swaymsg reload 2>/dev/null && echo "  ✓ Sway reloaded"
        # Apply wallpaper explicitly (reload doesn't re-run output commands)
        bg_file="$THEMES_DIR/backgrounds/$theme/background.png"
        if [[ -f "$bg_file" ]]; then
            swaymsg "output * bg $bg_file fill" 2>/dev/null && echo "  ✓ Wallpaper applied" || echo "  ⚠ Wallpaper apply failed"
        fi
    fi

    echo ""
    echo "Theme '$theme' applied!"
    echo "Open a new terminal for foot colors."
}

# Interactive picker with wofi
interactive_pick() {
    local themes
    themes=$(list_themes)

    if [[ -z "$themes" ]]; then
        echo "No themes found in $THEMES_DIR" >&2
        exit 1
    fi

    local current
    current=$(get_current_theme)

    local selected
    selected=$(printf '%s\n' "$themes" | wofi --show dmenu --prompt "Select theme: ")

    if [[ -n "$selected" ]]; then
        apply_theme "$selected"
    fi
}

# Entry point
case "$1" in
    "")
        interactive_pick
        ;;
    list)
        list_themes
        ;;
    *)
        apply_theme "$1"
        ;;
esac
