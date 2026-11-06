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
| Bar/Shell | [Quickshell](https://quickshell.org/) (QML) — dock, launcher, musica, wifi |
| Audio | PipeWire + WirePlumber (wpctl) |
| Media | playerctl (MPRIS) |
| Screen | wlogout, swaybg (wallpaper) |

## Font

Font che uso, installabili con `zypper`:

| Font | Uso | Package zypper |
|---|---|---|
| Poppins | UI — geometric sans | `google-poppins-fonts` |
| Source Code Pro | codice/terminale — mono | `adobe-sourcecodepro-fonts` |
| Source Sans 3 | UI — humanist sans | `adobe-sourcesans3-fonts` |

```bash
zypper install google-poppins-fonts adobe-sourcecodepro-fonts adobe-sourcesans3-fonts
```

## Palette colori — "aubergine"

Tema custom dello shell (non una palette nominata tipo Catppuccin/Gruvbox).
Definita in `quickshell/Theme.qml` — cambiare un valore lì aggiorna cornice, barra, dock e pannelli.

**Fondi** (colore solido identico tra cornice e pannelli; blur rimosso perché
i semi-trasparenti venivano "out di tono" col wallpaper dietro):

| Nome | Hex | Uso |
|---|---|---|
| `bgFrame` / `bgPanel` / `bgSolid` | `#191521` | fondo cornice + pannelli |
| `bgDeep` | `#1f1926` | menu Steam (un po' più profondo) |

**Interazione** (gradiente verso l'alto):

| Nome | Hex | Uso |
|---|---|---|
| `hover` | `#2a2338` | hover |
| `active` | `#3a3050` | elemento attivo |
| `activeHi` | `#463a5e` | attivo + enfasi |

**Accento e testo:**

| Nome | Hex | Uso |
|---|---|---|
| `accent` | `#b48ede` | lilla — accento principale |
| `accentHi` | `#c79fe6` | lilla chiaro — enfasi |
| `text` | `#d5cbe0` | testo principale |
| `textDim` | `#8d7fa3` | testo secondario |
| `danger` | `#e06c75` | rosso — azioni distruttive |

**Tile statistiche del dock** (una tinta per metrica):

| Nome | Hex | Metrica |
|---|---|---|
| `tileRam` | `#3a2f52` | RAM |
| `tileCpu` | `#2f3a52` | CPU |
| `tileNet` | `#2f5244` | Rete |
| `tileVol` | `#52402f` | Volume |

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

## Pannello musica

Il pannello musica di Quickshell si appoggia a due progetti **a parte**
(non fanno parte delle dotfiles). Hanno pesi molto diversi:

### turntable — il player (necessario)

[turntable](https://github.com/dilidin2/turntable) è il player MPRIS
(Rust, headless) dietro il widget: **senza di lui il pannello non riproduce
niente**. Installalo e avvialo come service user:

```bash
# dipendenza runtime (riproduzione audio)
sudo zypper install portaudio-devel
# build e install del binary
git clone git@github.com:dilidin2/turntable.git ~/turntable
cd ~/turntable && cargo build --release
install -m 755 target/release/turntable ~/.local/bin/turntable
# service systemd user
cp systemd/turntable.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now turntable
```

### vinylrip — scarica brani (opzionale)

Il tasto **"Scarica brano"** (lente d'ingrandimento nella vista *Brani*)
incolla un link YouTube e lo scarica in `~/Music/`. Usa
[vinylrip](https://github.com/dilidin2/vinylrip); **senza, il tasto resta
nella UI ma il download fallisce** (niente di grave: puoi solo non scaricare):

```bash
# dipendenze runtime + toolchain (in openSUSE go è versionato)
sudo zypper install yt-dlp ffmpeg go1.27
# build e install in PATH
git clone git@github.com:dilidin2/vinylrip.git ~/vinylrip
cd ~/vinylrip && go build -o vinylrip .
install -m 755 vinylrip ~/.local/bin/vinylrip
# directory di download (una volta sola)
vinylrip path ~/Music
```

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