import Quickshell

// Fillet esterno: quadrato r×r − disco di raggio r. Coordinate assolute finestra.
// (vx, vy) = vertice sul pannello; (dx, dy) = ±1 = quadrante in cui sporge.
Region {
    id: root
    property int r: 0
    property int vx: 0
    property int vy: 0
    property int dx: 1
    property int dy: 1

    x: dx > 0 ? vx : vx - r
    y: dy > 0 ? vy : vy - r
    width: r
    height: r

    Region {
        x: root.vx + (root.dx > 0 ? 0 : -2 * root.r)
        y: root.vy + (root.dy > 0 ? 0 : -2 * root.r)
        width: root.r * 2
        height: root.r * 2
        shape: RegionShape.Ellipse
        intersection: Intersection.Subtract
    }
}
