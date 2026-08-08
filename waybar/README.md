# Waybar

Custom status bar for Wayland.

## Modules

- **Left**: Workspaces (1–9), mode indicator, scratchpad
- **Center**: Active window title
- **Right**: Screen lock toggle, volume, network, CPU, memory, clock, system tray, power button

## Interactions

- Click network icon → opens `networkmanager_dmenu` for Wi-Fi selection
- Click volume icon → opens `pavucontrol`
- Click clock → toggles notification center + calendar
- Click power icon → opens `wlogout` (right-click exits Sway immediately)
- Scroll on workspaces → cycle between workspaces

## Setup

Ensure `networkmanager_dmenu` is installed for Wi-Fi management:

```bash
sudo apt install networkmanager-dmenu
```
