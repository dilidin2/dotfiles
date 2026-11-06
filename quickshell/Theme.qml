pragma Singleton
import QtQuick

// ─────────────────────────────────────────────────────────────────────
// Tema unico del port Ignis → Quickshell.
// Ogni costante visiva/dimensionale sta QUI: cambiare un valore qui
// aggiorna cornice, barra, dock e (in seguito) tutti i pannelli.
// ─────────────────────────────────────────────────────────────────────
QtObject {
    id: theme

    // ── Palette aubergine ───────────────────────────────────────────
    // BLUR RIMOSSO: senza blur, i fondi SEMI-trasparenti (#a6…/#cc…) +
    // il wallpaper dietro facevano venire OUT di tono barra e pannelli.
    // Ora colore SOLIDO identico per cornice e pannelli.
    readonly property color bgFrame:  "#191521"
    readonly property color bgPanel:  "#191521"
    readonly property color bgSolid:  "#191521"
    readonly property color bgDeep:   "#1f1926"   // menu Steam
    readonly property color hover:    "#2a2338"
    readonly property color active:   "#3a3050"
    readonly property color activeHi: "#463a5e"
    readonly property color accent:   "#b48ede"
    readonly property color accentHi: "#c79fe6"
    readonly property color text:     "#d5cbe0"
    readonly property color textDim:  "#8d7fa3"
    readonly property color danger:   "#e06c75"

    // ── Cornice (NON cambiare: sono le misure di Ignis) ──────────────
    readonly property int leftW:   40
    readonly property int rightW:  10
    readonly property int topH:    10
    readonly property int bottomH: 10
    readonly property int cornerR: 20   // raggio interno della cornice

    // ── Raccordi dei pannelli ────────────────────────────────────────
    // filletR: raccordo concavo con la barra (stesso "respiro" della cornice)
    // panelR : angoli esterni arrotondati
    readonly property int filletR: 20
    readonly property int panelR:  12
    readonly property int btnR:     8
    readonly property int tileR:   10

    // ── Dimensioni pannelli (da config.py / dock.py / wifi.py / …) ───
    readonly property int dockW: 240
    readonly property int dockH: 320

    readonly property int wifiW: 220
    readonly property int wifiH: 170

    readonly property int launcherW: 480
    readonly property int launcherH: 560

    readonly property int musicW: 420
    readonly property int musicH: 250
    readonly property int musicBottom: 970   // bordo inferiore fisso

    readonly property int steamW: 200
    readonly property int steamTop: 430
    readonly property int steamLeft: 48

    // ── Animazioni ───────────────────────────────────────────────────
    // Apertura: molla sul LATO REALE (larghezza/altezza), mai scale().
    // Chiusura: molla con damping alto → ritorno rapido e pulito.
    // Valori stabili per SpringAnimation Qt: spring>~10 diverge
    readonly property real springStiffness: 3.0
    readonly property real springDamping:   0.30
    readonly property real springCloseDamping: 0.7
    readonly property real springEpsilon:   0.25
    readonly property int  contentFadeMs:    180
    readonly property int  staggerMs:         35
    readonly property int  hoverMs:          110

    // ── Tile statistiche del dock ────────────────────────────────────
    readonly property color tileRam: "#3a2f52"
    readonly property color tileCpu: "#2f3a52"
    readonly property color tileNet: "#2f5244"
    readonly property color tileVol: "#52402f"

    // ── Icone locali (copiate da ~/.config/ignis/icons) ──────────────
    readonly property string iconDir: Qt.resolvedUrl("icons/")
    function icon(name) { return theme.iconDir + name }

    // ── Waveform nella barra ─────────────────────────────────────────
    readonly property int waveBars:      22
    readonly property int waveBarH:       3
    readonly property int waveBarGap:     3
    readonly property int waveBottomPad: 40
    readonly property int waveWidth:     40
}
