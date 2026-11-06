import Quickshell
import Quickshell.Io
import QtQuick

// ─────────────────────────────────────────────────────────────────────
// Ponte con niri: stato (workspaces/finestre) + azioni.
//  • stato iniziale via `niri msg -j workspaces|windows`
//  • aggiornamenti via `niri msg -j event-stream`
//  • azioni via `niri msg action …`
// Nessuna dipendenza da plugin: solo Process + JSON.
// ─────────────────────────────────────────────────────────────────────
pragma ComponentBehavior: Bound
QtObject {
    id: root

    property var workspaces: []
    property var windows: []
    property int focusedWindowId: -1

    // ── query ────────────────────────────────────────────────────────
    function workspaceById(id) {
        for (const ws of root.workspaces)
            if (ws.id === id) return ws
        return null
    }

    function activeWorkspace(output) {
        for (const ws of root.workspaces)
            if (ws.output === output && ws.is_active) return ws
        return null
    }

    function workspaceWindows(ws) {
        if (!ws) return []
        return root.windows.filter(w => w.workspace_id === ws.id)
    }

    function windowsFor(output) {
        return root.workspaceWindows(root.activeWorkspace(output))
    }

    function windowById(id) {
        for (const w of root.windows)
            if (w.id === id) return w
        return null
    }

    // Evidenzia la finestra attiva anche quando il focus è su un altro
    // monitor: se la finestra focalizzata è in questo workspace usa
    // quella, altrimenti l'active_window_id del workspace.
    function isActiveWindow(output, win) {
        if (!win) return false
        const ws = activeWorkspace(output)
        if (!ws) return false
        if (root.focusedWindowId >= 0) {
            const fw = windowById(root.focusedWindowId)
            if (fw && fw.workspace_id === ws.id)
                return win.id === fw.id
        }
        return win.id === ws.active_window_id
    }

    // ── azioni ───────────────────────────────────────────────────────
    function focusWindow(id) {
        if (id === undefined || id === null || id < 0) return
        run(["niri", "msg", "action", "focus-window", "--id", String(id)])
    }

    // Porta il monitor in focus e poi cambia workspace: così il click
    // su un workspace della barra funziona anche se il focus è altrove.
    function focusWorkspace(output, idx) {
        runSh("niri msg action focus-monitor " + output +
              " && niri msg action focus-workspace " + idx)
    }

    function focusApp(appid) {
        const needle = String(appid).toLowerCase()
        for (const w of root.windows) {
            if (String(w.app_id || "").toLowerCase().includes(needle)) {
                focusWindow(w.id)
                return true
            }
        }
        return false
    }

    function run(args) {
        cmd.command = args
        cmd.running = true
    }

    function runSh(script) {
        sh.command = ["sh", "-c", script]
        sh.running = true
    }

    // ── event stream ─────────────────────────────────────────────────
    property Process stream: Process {
        id: stream
        command: ["niri", "msg", "-j", "event-stream"]
        running: true

        stdout: SplitParser {
            onRead: (line) => root.handleEvent(line)
        }
        onExited: (code, status) => console.log("niri: event-stream exited code=" + code + " status=" + status)
        stderr: StdioCollector {
            onStreamFinished: console.log("niri: event-stream stderr=" + this.text)
        }

        onRunningChanged: {
            if (!running) restart.start()
        }
    }

    property Timer restart: Timer {
        id: restart
        interval: 1000
        onTriggered: stream.running = true
    }

    function handleEvent(line) {
        let ev
        try {
            ev = JSON.parse(line)
        } catch (e) {
            console.warn("niri: JSON non valido:", line)
            return
        }

        const kind = Object.keys(ev)[0]
        const p = ev[kind]

        if (kind === "WorkspacesChanged") {
            root.workspaces = p.workspaces
        } else if (kind === "WindowsChanged") {
            root.windows = p.windows
        } else if (kind === "WorkspaceActivated") {
            const out = (root.workspaceById(p.id) || {}).output
            root.workspaces = root.workspaces.map(w => {
                if (w.id === p.id)
                    return Object.assign({}, w, { is_active: true, is_focused: p.focused })
                if (out !== undefined && w.output === out)
                    return Object.assign({}, w, { is_active: false, is_focused: false })
                return w
            })
        } else if (kind === "WindowFocusChanged") {
            root.focusedWindowId = p.id === null ? -1 : p.id
        } else if (kind === "WindowOpenedOrChanged") {
            const w = p.window
            const next = root.windows.filter(x => x.id !== w.id)
            next.push(w)
            root.windows = next
        } else if (kind === "WindowClosed") {
            root.windows = root.windows.filter(w => w.id !== p.id)
        } else if (kind === "WindowUrgencyChanged") {
            root.windows = root.windows.map(w =>
                w.id === p.id ? Object.assign({}, w, { is_urgent: p.urgent }) : w)
        } else if (kind === "WorkspaceUrgencyChanged") {
            root.workspaces = root.workspaces.map(w =>
                w.id === p.id ? Object.assign({}, w, { is_urgent: p.urgent }) : w)
        }
    }

    // ── stato iniziale (fallback se l'event-stream tarda) ────────────
    property Process wsQuery: Process {
        id: wsQuery
        command: ["niri", "msg", "-j", "workspaces"]
        onExited: (code, status) => console.log("niri: wsQuery exited code=" + code + " status=" + status)
        stderr: StdioCollector {
            onStreamFinished: console.log("niri: wsQuery stderr=" + this.text)
        }
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("niri: wsQuery bytes=" + this.text.length)
                try {
                    const list = JSON.parse(this.text)
                    console.log("niri: wsQuery parsed=" + (Array.isArray(list) ? list.length : "not-array"))
                    if (Array.isArray(list) && list.length > 0)
                        root.workspaces = list
                } catch (e) {
                    console.log("niri: wsQuery parse error: " + e)
                }
            }
        }
    }

    property Process winQuery: Process {
        id: winQuery
        command: ["niri", "msg", "-j", "windows"]
        onExited: (code, status) => console.log("niri: winQuery exited code=" + code + " status=" + status)
        stderr: StdioCollector {
            onStreamFinished: console.log("niri: winQuery stderr=" + this.text)
        }
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("niri: winQuery bytes=" + this.text.length)
                try {
                    const list = JSON.parse(this.text)
                    console.log("niri: winQuery parsed=" + (Array.isArray(list) ? list.length : "not-array"))
                    if (Array.isArray(list))
                        root.windows = list
                } catch (e) {
                    console.log("niri: winQuery parse error: " + e)
                }
            }
        }
    }

    Component.onCompleted: {
        console.log("niri: init queries")
        wsQuery.running = true
        winQuery.running = true
    }

    // ── processi one-shot ────────────────────────────────────────────
    property Process cmd: Process { id: cmd }
    property Process sh: Process { id: sh }
}
