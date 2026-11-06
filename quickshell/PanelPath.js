.pragma library

// ─────────────────────────────────────────────────────────────────────
// Genera il path SVG del pannello.
// Tutti gli archi sono da 90° in senso orario (sweep=1): il path gira
// in senso orario partendo dal bordo alto.
//
// attach:
//   left/right/top/bottom  → due raccordi CONCAVI sul lato agganciato
//   topRight/topLeft/...   → un solo raccordo concavo sull'angolo
//   none                   → tutti gli angoli convessi
//   squareBottom/squareTop → lati squadrati (pannello appoggiato a un altro)
// ─────────────────────────────────────────────────────────────────────

function kind(attach, corner) {
    const tl = corner === "tl", tr = corner === "tr"
    const bl = corner === "bl", br = corner === "br"

    switch (attach) {
    case "left":  return (tl || bl) ? "concave" : "convex"
    case "right": return (tr || br) ? "concave" : "convex"
    case "top":   return (tl || tr) ? "concave" : "convex"
    case "bottom":return (bl || br) ? "concave" : "convex"
    case "topRight":    return tr ? "concave" : "convex"
    case "topLeft":     return tl ? "concave" : "convex"
    case "bottomRight": return br ? "concave" : "convex"
    case "bottomLeft":  return bl ? "concave" : "convex"
    case "squareBottom":return (bl || br) ? "square" : "convex"
    case "squareTop":   return (tl || tr) ? "square" : "convex"
    default: return "convex"
    }
}

// ─────────────────────────────────────────────────────────────────────
// Versione per attach "left" con fillet ESTERNI (stile caelestia).
// f = raggio fillet, c = raggio angoli convessi, p = padding verticale:
// il pannello occupa [0,w] × [p, p+h] (i fillet sporgono di f sopra/sotto).
//
// Arco fillet: dal bordo della barra (0, p∓f) al bordo del pannello
// (f, p∓f→p), sweep=0 (CCW) → l'arco si gonfia verso l'angolo, cioè
// riempie il quadrato meno il disco di centro (f, p∓f).
// ─────────────────────────────────────────────────────────────────────
function pathLeft(w, h, f, c, p) {
    if (w < 1 || h <= 0) return ""
    let d = "M 0 " + (p - f)
    d += " A " + f + " " + f + " 0 0 0 " + f + " " + p              // fillet alto (CCW)
    d += " L " + (w - c) + " " + p
    d += " A " + c + " " + c + " 0 0 1 " + w + " " + (p + c)        // TR convesso
    d += " L " + w + " " + (p + h - c)
    d += " A " + c + " " + c + " 0 0 1 " + (w - c) + " " + (p + h)   // BR convesso
    d += " L " + f + " " + (p + h)
    d += " A " + f + " " + f + " 0 0 0 0 " + (p + h + f)            // fillet basso (CCW)
    return d + " Z"                                                 // chiude lungo x=0 (sotto la barra)
}

// ─────────────────────────────────────────────────────────────────────
// Stesso pathLeft ma con l'angolo BASSO-SINISTRO CONVESSO (raggio c)
// invece del fillet concavo. Usato dal menu Steam: si aggancia alla
// barra solo in alto-sx, in basso-sx è un angolo arrotondato normale.
// ─────────────────────────────────────────────────────────────────────
function pathLeftConvexBL(w, h, f, c, p) {
    if (w < 1 || h <= 0) return ""
    let d = "M 0 " + (p - f)
    d += " A " + f + " " + f + " 0 0 0 " + f + " " + p              // fillet alto-sx (CCW)
    d += " L " + (w - c) + " " + p
    d += " A " + c + " " + c + " 0 0 1 " + w + " " + (p + c)        // TR convesso
    d += " L " + w + " " + (p + h - c)
    d += " A " + c + " " + c + " 0 0 1 " + (w - c) + " " + (p + h)   // BR convesso
    d += " L " + c + " " + (p + h)
    d += " A " + c + " " + c + " 0 0 1 0 " + (p + h - c)            // BL convesso
    d += " L 0 " + (p - f)                                          // bordo sx fino al fillet alto
    return d + " Z"
}

// ─────────────────────────────────────────────────────────────────────
// Versione per attach "bottom" con fillet ESTERNI (stile caelestia).
// Il pannello occupa [px,px+w] × [py,py+h] (coordinate finestra).
// Angoli ALTI convessi (raggio c), angoli BASSI fillet concavi (raggio f)
// che sporgono DI f sotto il bordo inferiore (contatto con il dock).
// Tutti gli archi sweep=1 (orario).
// ─────────────────────────────────────────────────────────────────────
function pathBottom(px, py, w, h, f, c) {
    if (w < 1 || h <= 0) return ""
    const x1 = px, x2 = px + w
    const y1 = py, y2 = py + h
    const r = Math.max(0, Math.min(c, w / 2, h / 2))
    // Angoli ALTI convessi (raggio r). Bordo BASSO agganciato: ESTESO di f
    // ai due capi; bordi laterali ACCORCIATI di f. I fillet (smin) stanno
    // DENTRO l'altezza del pannello, in [y2-f, y2], e sporgono di f a
    // sx/dx. Arco fillet sweep=0 (CCW) → si gonfia verso l'angolo.
    let d = "M " + x1 + " " + (y1 + r)
    d += " A " + r + " " + r + " 0 0 1 " + (x1 + r) + " " + y1   // TL convesso
    d += " L " + (x2 - r) + " " + y1                            // bordo alto
    d += " A " + r + " " + r + " 0 0 1 " + x2 + " " + (y1 + r)   // TR convesso
    d += " L " + x2 + " " + (y2 - f)                            // bordo destro (accorciato)
    d += " A " + f + " " + f + " 0 0 0 " + (x2 + f) + " " + y2   // fillet BR (CCW)
    d += " L " + (x1 - f) + " " + y2                            // bordo basso (esteso)
    d += " A " + f + " " + f + " 0 0 0 " + x1 + " " + (y2 - f)   // fillet BL (CCW)
    d += " L " + x1 + " " + (y1 + r)                            // bordo sinistro (accorciato)
    return d + " Z"
}

// ─────────────────────────────────────────────────────────────────────
// Versione per attach "topRight" con fillet ESTERNO (stile caelestia).
// Il pannello occupa [0,w] × [p, p+h] (p = padTop). Angolo ALTO-DESTRO
// fillet CONCAVO (raggio f, sporge di f a destra e sopra); gli altri tre
// angoli convessi (raggio c).
// ─────────────────────────────────────────────────────────────────────
function pathTopRight(w, h, f, c, p) {
    if (w < 1 || h <= 0) return ""
    const r = Math.max(0, Math.min(c, w / 2, h / 2))
    let d = "M 0 " + (p + r)
    d += " A " + r + " " + r + " 0 0 1 " + r + " " + p             // TL convesso
    d += " L " + (w - f) + " " + p
    d += " A " + f + " " + f + " 0 0 1 " + w + " " + (p + f)       // fillet TR (concavo)
    d += " L " + w + " " + (p + h - r)
    d += " A " + r + " " + r + " 0 0 1 " + (w - r) + " " + (p + h) // BR convesso
    d += " L " + r + " " + (p + h)
    d += " A " + r + " " + r + " 0 0 1 " + 0 + " " + (p + h - r)   // BL convesso
    return d + " Z"
}

// ─────────────────────────────────────────────────────────────────────
// Launcher (trElong). Il pannello occupa [ox, ox+w] × [0, h] nella Shape;
// ox = padding sinistro (= f). Il fillet basso-dx sporge sotto di f.
// ─────────────────────────────────────────────────────────────────────
function pathTrElong(w, h, f, c, ox) {
    if (w < 1 || h < 1) return ""
    const x1 = ox + w
    let d = "M " + (ox - f) + " 0"
    d += " L " + x1 + " 0"                                    // bordo alto → angolo TR quadrato
    d += " L " + x1 + " " + (h + f)                           // bordo destro, oltre il pannello
    d += " A " + f + " " + f + " 0 0 0 " + (x1 - f) + " " + h // fillet basso-dx (CCW)
    d += " L " + (ox + c) + " " + h
    d += " A " + c + " " + c + " 0 0 1 " + ox + " " + (h - c) // angolo BL convesso
    d += " L " + ox + " " + f
    d += " A " + f + " " + f + " 0 0 0 " + (ox - f) + " 0"    // fillet alto-sx (CCW)
    return d + " Z"
}

function path(attach, w, h, r, r2) {
    if (w <= 0 || h <= 0)
        return ""

    const R  = Math.max(0, Math.min(r,  w / 2, h / 2))
    const R2 = Math.max(0, Math.min(r2, w / 2, h / 2))

    const kTL = kind(attach, "tl")
    const kTR = kind(attach, "tr")
    const kBR = kind(attach, "br")
    const kBL = kind(attach, "bl")

    const rad = k => k === "convex" ? R2 : (k === "concave" ? R : 0)

    // Punto di partenza: bordo alto, subito dopo l'angolo in alto a sinistra.
    let x0 = kTL === "convex" ? R2 : (kTL === "concave" ? R : 0)
    let d = "M " + x0 + " 0"

    // ── alto → angolo alto-destro ──
    const trStart = kTR === "convex" ? w - R2 : (kTR === "concave" ? w - R : w)
    d += " L " + trStart + " 0"
    if (kTR === "convex")
        d += " A " + R2 + " " + R2 + " 0 0 1 " + w + " " + R2
    else if (kTR === "concave")
        d += " A " + R  + " " + R  + " 0 0 1 " + w + " " + R

    // ── destro → angolo basso-destro ──
    const brStart = kBR === "convex" ? h - R2 : (kBR === "concave" ? h - R : h)
    d += " L " + w + " " + brStart
    if (kBR === "convex")
        d += " A " + R2 + " " + R2 + " 0 0 1 " + (w - R2) + " " + h
    else if (kBR === "concave")
        d += " A " + R  + " " + R  + " 0 0 1 " + (w - R)  + " " + h

    // ── basso → angolo basso-sinistro ──
    const blStart = kBL === "convex" ? R2 : (kBL === "concave" ? R : 0)
    d += " L " + blStart + " " + h
    if (kBL === "convex")
        d += " A " + R2 + " " + R2 + " 0 0 1 0 " + (h - R2)
    else if (kBL === "concave")
        d += " A " + R  + " " + R  + " 0 0 1 0 " + (h - R)

    // ── sinistro → angolo alto-sinistro ──
    const tlStart = kTL === "convex" ? R2 : (kTL === "concave" ? R : 0)
    d += " L 0 " + tlStart
    if (kTL === "convex")
        d += " A " + R2 + " " + R2 + " 0 0 1 " + R2 + " 0"
    else if (kTL === "concave")
        d += " A " + R  + " " + R  + " 0 0 1 " + R  + " 0"

    return d + " Z"
}
