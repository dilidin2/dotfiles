# SwayFX & Friends

Configuration for the window manager and related tools.

## swayfx/

[SwayFX](https://github.com/swaywm/sway) — a fork of Sway with visual effects.

**Features enabled:**
- Blur (glassmorphism) on windows and layers
- Rounded corners (12px)
- Window shadows
- Dim unfocused windows
- Custom inner/outer gaps

**Notes:**
- Uses `Mod4` (Super key) as the modifier
- Dual monitor setup (HDMI-A-1 + DP-3 @ 240Hz) — adjust in `config` if different
- Keyboard layout: US + Italian, toggled with `Super + Space`
- XWayland enabled for Steam, Discord, etc.
- Auto-starts Waybar, SwayNC, and SwayIDLE

## swaync/

[SwayNC](https://github.com/ErikReider/SwayNotificationCenter) — notification daemon with a swipeable panel.

- Click clock in Waybar to toggle
- Styled to match the active theme

## swaylock/

[Swaylock](https://github.com/swaywm/swaylock) — screen locker.

- Triggered automatically by `swayidle` on lock/suspend
- Simple dark lock screen

## wlogout/

[Wlogout](https://github.com/JakeStanger/wlogout) — logout dialog.

- Triggered with `Super + p`
- Shows buttons: Lock, Logout, Suspend, Reboot, Power Off
