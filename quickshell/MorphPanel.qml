import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import "."
import "PanelPath.js" as PanelPath

// ─────────────────────────────────────────────────────────────────────
// Pannello "morph" riutilizzabile.
//
// La finestra ha SEMPRE la dimensione massima: niri non la ridimensiona
// mai. Quello che cambia è la dimensione REALE della forma (cW/cH) con
// una molla: niente transform: scale().
//
//  • growX: "right" | "left" | "none"
//  • growY: "down"  | "up"   | "none"
//  • attach: lato agganciato alla cornice → raccordi CONCAVI
//
// I fillet sono ESTERNI (sporgono dal rettangolo del pannello, come
// smin): la finestra cresce del raggio fillet sui lati dove sporgono.
// Forma, maschera input e contenuto seguono cW/cH.
// ─────────────────────────────────────────────────────────────────────
PanelWindow {
    id: root

    // ── geometria ────────────────────────────────────────────────────
    property int maxW: 240
    property int maxH: 320
    property bool open: false

    property string growX: "none"   // right | left | none
    property string growY: "none"   // down  | up   | none
    property string attach: "left"  // left|right|top|bottom|corner|none
    // true → angolo basso-sx CONVESSO (menu Steam): si aggancia alla barra
    // solo in alto-sx, in basso-sx è un angolo arrotondato normale.
    property bool convexBL: false

    property int filletR: Theme.filletR
    property int outerR: Theme.panelR
    property color bgColor: Theme.bgPanel

    // ── posizione nella layer-shell ──────────────────────────────────
    property bool anchorLeft: true
    property bool anchorRight: false
    property bool anchorTop: true
    property bool anchorBottom: false
    // Margini riferiti al PANNELLO (bordo agganciato). Qui dentro
    // compensiamo il padding dei fillet per ottenere la finestra giusta.
    property int marginLeft: 0
    property int marginRight: 0
    property int marginTop: 0
    property int marginBottom: 0
    property string panelNamespace: "qs_panel"

    // ── focus tastiera (launcher, form) ──────────────────────────────
    property bool wantsKeyboard: false
    property int keyboardFocusWhenOpen: WlrKeyboardFocus.OnDemand

    // ── dimensione animata ───────────────────────────────────────────
    property real panelW: (growX === "none") ? maxW : (open ? maxW : 0)
    property real panelH: (growY === "none") ? maxH : (open ? maxH : 0)

    // Versioni clampate: la molla NON deve mai uscire dai limiti.
    readonly property real cW: Math.max(0, Math.min(maxW, panelW))
    readonly property real cH: Math.max(0, Math.min(maxH, panelH))

    // ── padding della finestra per i fillet (sporgono fuori dal rettangolo) ──
    readonly property int padL: (attach === "trElong" || attach === "bottom") ? filletR : 0
    readonly property int padR: attach === "bottom" ? filletR : 0
    readonly property int padT: attach === "left" ? filletR : 0
    readonly property int padB: (attach === "left" || attach === "trElong") ? filletR : 0

    // raggi scalati: valgono per ogni w/h, anche più piccoli del raggio
    readonly property real fk: Math.min(1, cW / (filletR + outerR), cH / (filletR + outerR))
    readonly property int  fr: Math.round(filletR * fk)
    readonly property int  cr: Math.min(Math.round(outerR * fk), Math.floor(cH / 2))

    Behavior on panelW {
        SpringAnimation {
            spring:  Theme.springStiffness
            damping: root.open ? Theme.springDamping : Theme.springCloseDamping
            epsilon: Theme.springEpsilon
        }
    }
    Behavior on panelH {
        SpringAnimation {
            spring:  Theme.springStiffness
            damping: root.open ? Theme.springDamping : Theme.springCloseDamping
            epsilon: Theme.springEpsilon
        }
    }

    // posizione del pannello in coordinate finestra
    readonly property real panelX: padL + (growX === "left" ? maxW - cW : 0)
    readonly property real panelY: padT + (growY === "up"   ? maxH - cH : 0)

    // ── angoli: concavi / squadrati / convessi ───────────────────────
    function isConcave(c) {
        switch (attach) {
        case "left":   return c === "tl" || c === "bl"
        case "right":  return c === "tr" || c === "br"
        case "top":    return c === "tl" || c === "tr"
        case "bottom": return c === "bl" || c === "br"
        case "topRight":    return c === "tr"
        case "topLeft":     return c === "tl"
        case "bottomRight": return c === "br"
        case "bottomLeft":  return c === "bl"
        case "trElong":     return c === "tl" || c === "br"
        default: return false
        }
    }
    function isSquare(c) {
        if (attach === "squareBottom") return c === "bl" || c === "br"
        if (attach === "squareTop")    return c === "tl" || c === "tr"
        return false
    }
    function radiusFor(c) {
        if (attach === "left")    return (c === "tl" || (c === "bl" && !convexBL)) ? 0 : cr
        if (attach === "trElong") return (c === "bl") ? cr : 0
        return (isConcave(c) || isSquare(c)) ? 0 : cr
    }

    readonly property int rTL: radiusFor("tl")
    readonly property int rTR: radiusFor("tr")
    readonly property int rBL: radiusFor("bl")
    readonly property int rBR: radiusFor("br")

    // ── finestra ─────────────────────────────────────────────────────
    implicitWidth:  maxW + padL + padR
    implicitHeight: maxH + padT + padB
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        left: root.anchorLeft
        right: root.anchorRight
        top: root.anchorTop
        bottom: root.anchorBottom
    }
    margins {
        left:   root.marginLeft   - (root.anchorLeft   ? root.padL : 0)
        right:  root.marginRight  - (root.anchorRight  ? root.padR : 0)
        top:    root.marginTop    - (root.anchorTop    ? root.padT : 0)
        bottom: root.marginBottom - (root.anchorBottom ? root.padB : 0)
    }

    WlrLayershell.namespace: root.panelNamespace
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: (root.open && root.wantsKeyboard)
                                 ? root.keyboardFocusWhenOpen
                                 : WlrKeyboardFocus.None

    // (colore solido, niente blur) — la Region resta come maschera input
    mask: shapeRegion

    // ── regione = forma del pannello (maschera input) ─────────────────
    Region {
        id: shapeRegion
        x: Math.round(root.panelX)
        y: Math.round(root.panelY)
        width: Math.round(root.cW)
        height: Math.round(root.cH)

        topLeftRadius: root.rTL
        topRightRadius: root.rTR
        bottomLeftRadius: root.rBL
        bottomRightRadius: root.rBR

        // alto-sx: dock → sporge in alto (+1,−1); launcher → sporge a sinistra (−1,+1)
        FilletRegion {
            r: (root.attach === "left" || root.attach === "trElong") ? root.fr : 0
            vx: shapeRegion.x; vy: shapeRegion.y
            dx: root.attach === "left" ? 1 : -1
            dy: root.attach === "left" ? -1 : 1
        }
        // basso-sx (solo dock; disattivato se convexBL)
        FilletRegion {
            r: (root.attach === "left" && !root.convexBL) ? root.fr : 0
            vx: shapeRegion.x; vy: shapeRegion.y + shapeRegion.height
            dx: 1; dy: 1
        }
        // basso-dx (solo launcher)
        FilletRegion {
            r: root.attach === "trElong" ? root.fr : 0
            vx: shapeRegion.x + shapeRegion.width; vy: shapeRegion.y + shapeRegion.height
            dx: -1; dy: 1
        }
        // bottom (Wi-Fi): fillet in basso, sporgono a sx/dx
        FilletRegion {
            r: root.attach === "bottom" ? root.fr : 0
            vx: shapeRegion.x + root.padL; vy: shapeRegion.y + root.cH
            dx: -1; dy: -1
        }
        FilletRegion {
            r: root.attach === "bottom" ? root.fr : 0
            vx: shapeRegion.x + root.padL + root.cW; vy: shapeRegion.y + root.cH
            dx: 1; dy: -1
        }
    }

    // ── disegno della forma (Shape copre tutta la finestra) ──────────
    Shape {
        x: root.panelX - root.padL
        y: root.panelY - root.padT
        width:  root.cW + root.padL + root.padR
        height: root.cH + root.padT + root.padB

        ShapePath {
            fillColor: root.bgColor
            strokeWidth: -1
            PathSvg {
                path: root.attach === "left"
                      ? (root.convexBL
                          ? PanelPath.pathLeftConvexBL(root.cW, root.cH, root.fr, root.cr, root.padT)
                          : PanelPath.pathLeft(root.cW, root.cH, root.fr, root.cr, root.padT))
                      : root.attach === "trElong"
                        ? PanelPath.pathTrElong(root.cW, root.cH, root.fr, root.cr, root.padL)
                        : root.attach === "bottom"
                          ? PanelPath.pathBottom(root.padL, 0, root.cW, root.cH, root.fr, root.cr)
                          : PanelPath.path(root.attach, root.cW, root.cH,
                                           root.filletR, root.outerR)
            }
        }
    }

    // ── contenuto: dimensione fissa, ritagliato, sfumato ─────────────
    Item {
        id: clipHost
        x: root.panelX
        y: root.panelY
        width: root.cW
        height: root.cH
        clip: true
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: root.open ? 60 : 0 }
                NumberAnimation {
                    duration: root.open ? Theme.contentFadeMs : 120
                    easing.type: Easing.OutCubic
                }
            }
        }

        Item {
            id: contentRoot
            x: root.growX === "left" ? -(root.maxW - root.cW) : 0
            y: root.growY === "up"   ? -(root.maxH - root.cH) : 0
            width: root.maxW
            height: root.maxH
        }
    }

    default property alias content: contentRoot.data

    // ── API comode ───────────────────────────────────────────────────
    function openPanel() { root.open = true }
    function closePanel() { root.open = false }
    function toggle() { root.open = !root.open }
}
