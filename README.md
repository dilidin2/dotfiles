# Dotfiles

Configurazione personale di Matteo — **niri** su **openSUSE Tumbleweed**.

Desktop (Ryzen 7 7800X3D, RX 7900 XT).
Due monitor: DP-3 (1920x1080@144) al centro, HDMI-A-1 (1920x1080@60) a sinistra.

## Stack

| Ruolo | Strumento |
|---|---|
| WM | [niri](https://niri.wiki/) — tiling compositor (colonne, workspaces dinamici) |
| Shell | [Fish](https://fishshell.com/) con prompt git custom |
| Terminal | [Ghostty](https://ghostty.org/) — no titlebar, no sessione |
| Bar/Shell | [Quickshell](https://quickshell.org/) + Ignis (QML) — dock, launcher, musica, wifi |
| Audio | PipeWire + WirePlumber (wpctl) |
| Media | playerctl (MPRIS) |
| Screen | wlogout, swaybg (wallpaper) |

## Struttura

```
dotfiles/
├── niri/            # config.kdl + basicsettings.kdl + keybinds.kdl
├── quickshell/      # shell QML (dock, launcher, pannelli, musica, wifi)
├── ghostty/         # config terminale
├── fish/            # config.fish (prompt), conf.d, variabili
├── systemd/user/    # service user (turntable, bot audio sinks)
├── bashrc           # ~/.bashrc
├── zshrc            # ~/.zshrc
├── profile          # ~/.profile
├── gitconfig        # ~/.gitconfig (solo nome, niente email personale)
├── inputrc          # ~/.inputrc (readline)
├── env / env.fish   # helper PATH per ~/.local/bin
└── install.sh       # crea tutti i symlink
```

## Install

```bash
git clone git@github.com:dilidin2/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

`install.sh` crea symlink: ogni modifica in `~/dotfiles/` è immediatamente
visibile nel sistema (e viceversa).

## Note

- **niri**: le animazioni/blur sono gestite da niri stesso (no swayfx).
  `basicsettings.kdl` e `keybinds.kdl` sono generati da **niri-settings**:
  modificarli a mano viene sovrascritto.
- **quickshell**: lo shell QML parte con `spawn-at-startup "qs"` in niri.
  I pannelli usano layer-shell con namespace `dock_panel`, `wifi_panel`, ecc.
- **fish**: il prompt mostra percorso completo + stato git
  (staged/modificato/nuovi) + stato ultimo comando.
- **git**: il `gitconfig` contiene solo il nome (niente email personale,
  repo pubblico). Per committare usa `dilidin2@users.noreply.github.com`
  come email locale.