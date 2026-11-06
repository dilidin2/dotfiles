//@ pragma IconTheme Adwaita
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "."

// ─────────────────────────────────────────────────────────────────────
// Root del port Ignis → Quickshell.
//
//  • cornice su OGNI monitor (DP-3 con barra, HDMI-A-1 solo cornice)
//  • strut invisibili per riservare i 4 bordi su entrambi
//  • dock solo su DP-3
//  • IPC shell: qs ipc call shell <comando>
// ─────────────────────────────────────────────────────────────────────
ShellRoot {
    id: shellRoot

    Niri { id: niriState }

    function screenByName(name) {
        for (let i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === name)
                return Quickshell.screens[i]
        return null
    }

    readonly property var dp3: shellRoot.screenByName("DP-3")

    // ── chiusura sfasata: flyout → wifi → dock ──────────────────────
    property int staggerStep: 0
    Timer {
        id: staggerTimer
        interval: 200
        repeat: false
        onTriggered: {
            shellRoot.staggerStep++
            if (shellRoot.staggerStep === 1) {
                wifiPanel.open = false
                staggerTimer.start()
            } else if (shellRoot.staggerStep === 2) {
                dockPanel.open = false
                shellRoot.staggerStep = 0
            }
        }
    }

    // ── stagger musica: flyout → pannello ─────────────────────────
    Timer {
        id: musicStaggerTimer
        interval: 200
        repeat: false
        onTriggered: musicPanel.closePanel()
    }

    // ── Cornice su tutti i monitor ───────────────────────────────────
    Variants {
        model: Quickshell.screens
        delegate: Frame {
            niri: niriState
            dock: dockPanel
        }
    }

    // ── Riserve di spazio (4 bordi) su tutti i monitor ───────────────
    Variants {
        model: Quickshell.screens
        delegate: ScreenStruts {}
    }

    // ── Dock + pannello Wi-Fi (solo DP-3) ─────────────────────────────
    Dock {
        id: dockPanel
        screen: shellRoot.dp3
        niri: niriState
        // stagger se è aperto un sub-panel (Wi-Fi O menu Steam)
        subsOpen: wifiPanel.open || steamMenu.open

        // chiusura sfasata: flyout → wifi → dock
        onStaggerClose: {
            wifiPanel.flyoutOpen = false   // step 0: flyout Wi-Fi
            steamMenu.open = false         // step 0: menu Steam
            shellRoot.staggerStep = 0
            staggerTimer.start()          // step 1: wifi, step 2: dock
        }

        onWifiRequested: wifiPanel.toggle()
        onMusicRequested: {
            if (musicPanel.open) {
                newPl.closePanel()      // 1°: chiudi il flyout "nuova playlist"
                musicStaggerTimer.start() // 2°: poi il pannello (200ms)
            } else {
                musicPanel.openPanel()
            }
        }
        onSteamMenuRequested: steamMenu.toggle()

        // rete di sicurezza: chiudendo il dock chiude anche Wi-Fi e Steam
        onOpenChanged: {
            if (!dockPanel.open) {
                if (wifiPanel.open)  wifiPanel.closePanel()
                if (steamMenu.open)  steamMenu.closePanel()
            }
        }
    }

    Wifi {
        id: wifiPanel
        screen: shellRoot.dp3
    }

    // Pannello musica (client MPRIS verso turntable)
    Music {
        id: musicPanel
        screen: shellRoot.dp3
        onOpenNewPlaylist: (song) => { newPl.openPl(song) }
    }

    // Flyout "Nuova playlist" (a destra del pannello musica)
    NewPlaylist {
        id: newPl
        screen: shellRoot.dp3
        onCreated: (name) => { musicPanel.rescan(); newPl.open = false }
        onCancelRequested: newPl.open = false
    }

    // Flyout a destra del Wi-Fi: stessa animazione, mostra password /
    // Connetti / Annulla / Disconnetti.
    WifiFlyout {
        id: wifiFlyout
        screen: shellRoot.dp3
        open:  wifiPanel.flyoutOpen && wifiPanel.open
        ssid:  wifiPanel.flyoutSsid
        mode:  wifiPanel.flyoutMode

        onConnectRequested: {
            wifiPanel.connectNet(ssid, password)
            wifiPanel.flyoutOpen = false
        }
        onDisconnectRequested: {
            wifiPanel.disconnectNet()
            wifiPanel.flyoutOpen = false
        }
        onCancelRequested: wifiPanel.flyoutOpen = false
    }

    // Menu Steam: flyout a destra del dock (giocati recenti + URL)
    SteamMenu {
        id: steamMenu
        screen: shellRoot.dp3
    }

    // ── Launcher (solo DP-3) ──────────────────────────────────────────
    Launcher {
        id: launcherPanel
        screen: shellRoot.dp3
    }

    // ── IPC: comandi dello shell (target "shell") ───────────────────────────
    // Uso: qs ipc call shell toggle_dock
    IpcHandler {
        target: "shell"

        function toggle_dock(): void { dockPanel.toggle() }
        function open_dock(): void { dockPanel.openPanel() }
        function close_dock(): void { dockPanel.closeStaggered() }

        // debug temporaneo
        function debug_state(): string {
            return JSON.stringify({
                dock: dockPanel !== null,
                ws: niriState.workspaces.length,
                win: niriState.windows.length,
                dp3: shellRoot.dp3 ? shellRoot.dp3.name : null
            })
        }

        // ── Wi-Fi ─────────────────────────────────────────────────
        function toggle_wifi(): void { wifiPanel.toggle() }
        function close_wifi(): void { wifiPanel.closePanel() }
        // debug: apre dock + flyout connect
        function debug_flyout(): void {
            wifiPanel.openPanel()
            wifiPanel.openFlyoutConnect("TIM-28737892")
        }
        // debug: apre dock + flyout disconnect
        function debug_flyout_disc(): void {
            wifiPanel.openPanel()
            wifiPanel.openFlyoutDisconnect()
        }

        // Stub espliciti: le funzioni arriveranno negli step successivi.
        function toggle_launcher(): void { launcherPanel.toggle() }
        function open_launcher(): void { launcherPanel.openPanel() }
        function close_launcher(): void { launcherPanel.closePanel() }

        // DEBUG: elenco app da DesktopEntries.applications
        function debug_apps(): string {
            var vals = DesktopEntries.applications.values
            var out = []
            for (var i = 0; i < vals.length && i < 5; i++)
                out.push(vals[i].id + " | " + vals[i].name)
            return "count=" + vals.length + " :: " + out.join(" ; ")
        }
        // DEBUG: lancia per id
        function debug_launch(id: string): string {
            var vals = DesktopEntries.applications.values
            for (var i = 0; i < vals.length; i++) {
                if (vals[i].id === id) { vals[i].execute(); return "executed " + id; }
            }
            return "non trovato: " + id
        }
        function toggle_music(): void { musicPanel.toggle() }
        function open_music(): void { musicPanel.openPanel() }
        function close_music(): void { musicPanel.closePanel() }
        function open_new_pl(song: string): void { newPl.openPl(song) }
        function close_new_pl(): void { newPl.open = false }
        function toggle_steam_menu(): void { steamMenu.toggle() }
        function hide_steam_menu(): void { steamMenu.closePanel() }
    }
}
