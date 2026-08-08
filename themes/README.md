# Theme Switcher

A dynamic theming system that applies colors from a single `theme.json` to all major configs (SwayFX, Waybar, Wofi, Foot, SwayNC, Swaylock, Wlogout, Fish prompt, and GTK).

## Structure

```
themes/
├── .current-theme          # Name of the active theme
├── scripts/
│   ├── theme-switcher.sh   # Interactive theme switcher via Wofi
│   └── new_theme.py        # Create a new theme from a background image
├── templates/
│   └── config.fish.template # Template for theme-aware Fish config
├── city-night/
├── emerald/                # Currently active theme
├── lighthouse/
├── light-pink/
└── orange/
    └── theme.json          # Color definitions for each theme
```

## Usage

- `Super + t` → Open theme switcher (Wofi dialog)
- `Super + Shift + t` → Create a new theme (prompts for name and background image)
- From terminal: `theme-switch` or `new-theme`

## How It Works

Each theme has a `theme.json` with named color tokens. `theme-switcher.sh` reads the JSON and updates all config files to use those colors, then reloads SwayFX and affected apps.

## Creating a Theme

Run `new_theme.py` — it will:
1. Ask for a theme name
2. Ask for a path to a background image
3. Generate a `theme.json` with extracted colors
4. Create the theme folder in `~/.themes/`

Then switch to it with `theme-switch`.
