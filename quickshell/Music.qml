import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// ─────────────────────────────────────────────────────────────────────
// Pannello musica 420×250: esce dalla barra verso DESTRA (come il dock).
// Client MPRIS verso "turntable". 5 viste: home / now / songs /
// playlists / detail. Dati (brani + playlist) da ~/Music via music_scan.py.
// ─────────────────────────────────────────────────────────────────────
MorphPanel {
    id: root

    maxW: Theme.musicW
    maxH: Theme.musicH
    growX: "right"
    growY: "none"
    attach: "left"
    filletR: Theme.filletR
    outerR: Theme.panelR
    bgColor: Theme.bgPanel

    panelNamespace: "music_panel"
    anchorLeft: true
    anchorTop: true
    marginLeft: Theme.leftW
    marginTop: 720

    wantsKeyboard: true
    keyboardFocusWhenOpen: WlrKeyboardFocus.OnDemand

    // ── stato ────────────────────────────────────────────────────────
    property string view: "songs"
    property var songs: []
    // ── ricerca ────────────────────────────────────────────────────
    property string searchText: ""
    readonly property var filteredSongs: {
        if (!root.searchText) return root.songs
        const q = root.searchText.toLowerCase()
        return root.songs.filter(s =>
            (s.title && s.title.toLowerCase().includes(q)) ||
            (s.artist && s.artist.toLowerCase().includes(q)))
    }
    readonly property string songsCountText: root.searchText
        ? (root.filteredSongs.length + " di " + root.songs.length + " canzoni")
        : (root.songs.length + " canzoni")
    property var playlists: []
    property string currentPl: ""
    property var plSongs: []
    property var plCovers: []
    property string plMood: ""
    property real plHours: 0
    property var currentSong: null
    property var queue: null      // lista di brani per next/prev
    property int queueIndex: -1   // posizione corrente nel queue
    property var menuSong: null   // path della riga con menu inline aperto
    // ── stato riproduzione in QML: QS non aggiorna i PropertiesChanged MPRIS ──
    property bool isPlaying: false
    property real livePos: 0    // posizione corrente (secondi)
    property real liveLen: 0    // durata brano (secondi, da currentSong.duration)
    property real liveVol: 1.0  // volume corrente
    // ── shuffle / repeat (stato QML: turntable non li gestisce) ──
    property bool shuffleOn: false
    property string repMode: "none"   // "none" | "playlist" | "track"
    property var shuffleBag: []       // indici da riprodurre (shuffle senza ripetuti)
    property var history: []          // stack indici già suonati (per "indietro")
    property int _lastPosMs: 0
    property int _stall: 0
    property string lastStatus: ""   // ultimo PlaybackStatus letto (Playing/Paused/Stopped)
    property int _lastAdvanceMs: 0   // anti-doppio evento di fine traccia

    // ── player MPRIS (turntable) ─────────────────────────────────────
    readonly property string targetBus: "org.mpris.MediaPlayer2.turntable"
    // ATTENZIONE: ObjectModel.values è REATTIVO; .at(i)/.count NO.
    // Usare .values + .find() altrimenti `player` resta null.
    readonly property var _plist: Mpris.players.values
    readonly property var player: _plist.find(p => p.dbusName === root.targetBus)
    // turntable NON espone i metadati MPRIS → mi affido alla canzone cliccata
    readonly property bool hasTrack:
        currentSong !== null || root.isPlaying
    readonly property string dispTitle:
        (currentSong && currentSong.title) ? currentSong.title
        : (player ? player.trackTitle : "")
    readonly property string dispArtist:
        (currentSong && currentSong.artist) ? currentSong.artist
        : (player ? player.trackArtist : "")
    readonly property string dispCover:
        (currentSong && currentSong.cover) ? currentSong.cover
        : (player ? player.trackArtUrl : "")

    // posizione aggiornata 1×/s via gdbus (QS non aggiorna position MPRIS)
    // FIX: il timer deve girare ANCHE a pannello chiuso: prima, se chiudevi il
    // pannello in riproduzione, onTrackEnded() non scattava mai e il brano
    // successivo non partiva (bisognava riaprire il pannello).
    Timer {
        id: posTimer
        interval: 1000
        repeat: true
        running: root.isPlaying
        onTriggered: { root.readPos(); root.readStatus() }
    }
    Process {
        id: posProc
        stdout: StdioCollector {
            onStreamFinished: {
                // output gdbus: "(<int64 3013333>,)" → ultimo numero = µs
                var nums = String(posProc.stdout.data).match(/-?\d+/g)
                if (nums) {
                    root.livePos = parseInt(nums[nums.length - 1], 10) / 1000000
                    root.checkEnded()
                }
            }
        }
    }
    // PlaybackStatus 1×/s: "Stopped" è il segnale affidabile di fine traccia
    // (se Position torna a 0 lo stall-check non la rileverebbe mai).
    Process {
        id: stProc
        stdout: StdioCollector {
            onStreamFinished: {
                var m = String(stProc.stdout.data).match(/"(Playing|Paused|Stopped)"/)
                if (m) root.checkStopped(m[1])
            }
        }
    }
    // controllo play/pause via gdbus (i metodi MPRIS QS falliscono per playbackState stale)
    Process {
        id: ctlProc
        stdout: StdioCollector { onStreamFinished: {} }
    }
    function ctlCall(method) {
        ctlProc.exec(["gdbus", "call", "--session",
                      "--dest", root.targetBus,
                      "--object-path", "/org/mpris/MediaPlayer2",
                      "--method", "org.mpris.MediaPlayer2.Player." + method])
    }
    function readPos() {
        posProc.exec(["gdbus", "call", "--session",
                      "--dest", root.targetBus,
                      "--object-path", "/org/mpris/MediaPlayer2",
                      "--method", "org.freedesktop.DBus.Properties.Get",
                      "org.mpris.MediaPlayer2.Player", "Position"])
    }
    // output gdbus: "(<'Paused'>,)" → parola tra virgolette
    function readStatus() {
        stProc.exec(["gdbus", "call", "--session",
                     "--dest", root.targetBus,
                     "--object-path", "/org/mpris/MediaPlayer2",
                     "--method", "org.freedesktop.DBus.Properties.Get",
                     "org.mpris.MediaPlayer2.Player", "PlaybackStatus"])
    }
    // turntable ha smesso = fine traccia: fa partire il brano successivo
    // anche a pannello chiuso (e anche se Position è tornato a 0)
    function checkStopped(status) {
        root.lastStatus = status
        if (status === "Stopped" && root.isPlaying) {
            root._stall = 0
            root._lastPosMs = 0
            root.onTrackEnded()
        }
    }

    // ── dati da ~/Music ──────────────────────────────────────────────
    function loadData(text) {
        let d
        try { d = JSON.parse(text) } catch (e) { return }
        root.songs = d.songs || []
        // per ogni playlist: 4 copertine casuali + ore totali
        d.playlists = (d.playlists || []).map(pl => {
            const songs = pl.songs || []
            const covers = songs.map(s => s.cover).filter(c => c && c.length > 0)
            const picks = []
            for (let i = 0; i < 4; i++)
                picks.push(covers.length > 0
                           ? covers[Math.floor(Math.random() * covers.length)]
                           : "")
            pl.covers = picks
            pl.hours = songs.reduce((a, s) => a + (s.duration || 0), 0)
            return pl
        })
        root.playlists = d.playlists
    }
    function fmtHours(sec) {
        const h = Math.floor(sec / 3600)
        const m = Math.floor((sec % 3600) / 60)
        if (h > 0) return h + "h " + m + "m"
        if (m > 0) return m + "m"
        return "< 1m"
    }
    property Process proc: Process {
        id: proc
        command: ["/usr/bin/python3", Quickshell.shellPath("scripts/music_scan.py"), "all"]
        stdout: StdioCollector {
            onStreamFinished: root.loadData(this.text)
        }
    }
    // delete playlist
    property Process delProc: Process {
        stdout: StdioCollector {
            onStreamFinished: root.rescan()
        }
    }
    function deletePlaylist(name) {
        delProc.exec(["/usr/bin/python3", Quickshell.shellPath("scripts/music_scan.py"), "rm", name])
    }
    onOpenChanged: if (root.open) proc.running = true

    // ── navigazione ──────────────────────────────────────────────────
    function setView(v) {
        root.view = v
        if (v === "detail" && root.currentPl) loadDetail(root.currentPl)
    }
    function openDetail(name) {
        root.currentPl = name
        root.plSongs = []
        root.setView("detail")
        loadDetail(name)
    }
    // i brani della playlist sono già nella scansione (field "songs")
    function loadDetail(name) {
        for (var i = 0; i < root.playlists.length; i++) {
            if (root.playlists[i].name === name) {
                root.plSongs = root.playlists[i].songs || []
                root.plCovers = root.playlists[i].covers || []
                root.plMood = root.playlists[i].mood || ""
                root.plHours = root.playlists[i].hours || 0
                return
            }
        }
    }
    function playFile(path, queue) {
        root.view = "now"
        if (!queue) queue = root.songs
        root.queue = queue
        root.queueIndex = -1
        root.shuffleBag = []
        root.history = []
        for (var i = 0; i < queue.length; i++) {
            if (queue[i].path === path) { root.currentSong = queue[i]; root.queueIndex = i; break }
        }
        if (root.shuffleOn) root.initShuffleBag()
        doPlay(path)
    }

    function doPlay(path) {
        if (!root.player) return
        root.player.openUri("file://" + path)
        root.isPlaying = true
        root.livePos = 0
        root.liveLen = (root.currentSong && root.currentSong.duration)
                       ? root.currentSong.duration : 0
        root.liveVol = 1.0
        root._stall = 0
        root._lastPosMs = 0
    }
    // play/pause: lo stato lo tengo io, il comando va via gdbus (affidabile)
    function togglePlay() {
        if (!root.currentSong) {
            if (root.songs.length > 0) root.playFile(root.songs[0].path)
            return
        }
        if (root.isPlaying) { ctlCall("Pause"); root.isPlaying = false }
        else { ctlCall("Play"); root.isPlaying = true }
    }

    // ── fine traccia + shuffle/repeat ────────────────────────────
    // fine: posizione ferma da 2 tick (turntable smesso) o quasi a fine brano
    function checkEnded() {
        if (!root.isPlaying || root.liveLen <= 0) {
            root._stall = 0
            root._lastPosMs = Math.round(root.livePos * 1000)
            return
        }
        // pausa (anche esterna): posizione ferma ≠ fine traccia
        if (root.lastStatus === "Paused") {
            root._stall = 0
            return
        }
        var ms = Math.round(root.livePos * 1000)
        // conta il "stall" solo nella seconda metà (evita falsi trigger post-doPlay)
        if (ms <= root._lastPosMs) {
            if (root.livePos >= root.liveLen * 0.5) root._stall++
            else root._stall = 0
        } else {
            root._stall = 0
            root._lastPosMs = ms
        }
        var ended = root._stall >= 2
        if (root.livePos >= root.liveLen - 0.4) ended = true
        if (ended) { root._stall = 0; root._lastPosMs = 0; root.onTrackEnded() }
    }
    function onTrackEnded() {
        // anti-doppio: Position fermo a fine + PlaybackStatus "Stopped" possono
        // segnalare LA STESSA fine traccia nello stesso secondo → ignora il 2°
        var now = Date.now()
        if (now - root._lastAdvanceMs < 1000) return
        root._lastAdvanceMs = now
        if (!root.currentSong) { root.isPlaying = false; return }
        if (root.repMode === "track") { doPlay(root.currentSong.path); return }
        var i = pickNextIndex()
        if (i >= 0) root.forwardPlay(i)
        else { root.isPlaying = false; root.livePos = 0 }
    }
    // riempi la sacca shuffle: tutti gli indici tranne il corrente, mescolati
    function initShuffleBag() {
        var q = root.queue
        root.shuffleBag = []
        if (!q) return
        for (var k = 0; k < q.length; k++)
            if (k !== root.queueIndex) root.shuffleBag.push(k)
        // Fisher-Yates
        for (var j = root.shuffleBag.length - 1; j > 0; j--) {
            var r = Math.floor(Math.random() * (j + 1))
            var tmp = root.shuffleBag[j]
            root.shuffleBag[j] = root.shuffleBag[r]
            root.shuffleBag[r] = tmp
        }
    }
    // shuffle → sacca (no ripetuti, stop a fine se no repeat); sequenziale → +1
    function pickNextIndex() {
        var q = root.queue
        if (!q || q.length === 0) return -1
        if (root.shuffleOn) {
            if (q.length === 1) return (root.repMode === "playlist") ? 0 : -1
            // sacca vuota = ciclo completato: ripeti solo con "repeat playlist"
            if (!root.shuffleBag || root.shuffleBag.length === 0) {
                if (root.repMode !== "playlist") return -1
                root.initShuffleBag()
            }
            return root.shuffleBag.shift()
        }
        var i = root.queueIndex + 1
        if (i >= q.length) return (root.repMode === "playlist") ? 0 : -1
        return i
    }

    // avanti (next/auto-advance): spinge l'indice corrente nello storico
    function forwardPlay(i) {
        if (root.queueIndex >= 0 && root.queueIndex !== i)
            root.history.push(root.queueIndex)
        root.queueIndex = i
        root.currentSong = root.queue[i]
        root.view = "now"
        doPlay(root.queue[i].path)
    }

    function nextTrack() {
        var i = pickNextIndex()
        if (i >= 0) root.forwardPlay(i)
    }

    function prevTrack() {
        if (root.history.length === 0) return
        var i = root.history.pop()
        root.queueIndex = i
        root.currentSong = root.queue[i]
        root.view = "now"
        doPlay(root.queue[i].path)
    }
    function addSongToPlaylist(path, playlist) {
        Quickshell.execDetached(["/usr/bin/python3",
            Quickshell.shellPath("scripts/music_scan.py"), "add", playlist, path])
        rescanTimer.start()
    }
    function removeFromPlaylist(playlist, path) {
        Quickshell.execDetached(["/usr/bin/python3",
            Quickshell.shellPath("scripts/music_scan.py"), "remove", playlist, path])
        rescanTimer.start()
    }
    function deleteSong(path) {
        Quickshell.execDetached(["/usr/bin/python3",
            Quickshell.shellPath("scripts/music_scan.py"), "delete", path])
        rescanTimer.start()
    }
    function rescan() { proc.running = true }
    signal openNewPlaylist(string song)
    signal openRipFlyout()

    function openNewPl(songPath) {
        root.openNewPlaylist(songPath)
    }
    Timer {
        id: rescanTimer
        interval: 700
        repeat: false
        onTriggered: proc.running = true
    }

    function fmtTime(sec) {
        if (!isFinite(sec) || sec < 0) sec = 0
        const m = Math.floor(sec / 60)
        const s = Math.floor(sec % 60)
        return m + ":" + String(s).padStart(2, "0")
    }

    // Esc: se non in home → home, altrimenti chiudi
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (root.view !== "home") root.setView("home")
            else root.closePanel()
        }
    }

    // ── riga canzone riusabile ───────────────────────────────────────
    component SongRow: Rectangle {
        id: srow
        property var data: null
        width: parent ? parent.width : 0
        height: 34
        radius: Theme.btnR
        color: srowMa.containsMouse ? Theme.hover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.hoverMs } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: srow.data ? srow.data.title : ""
                color: Theme.text
                font.pixelSize: 13
                elide: Text.ElideRight
            }
            Text {
                text: srow.data ? srow.data.artist : ""
                color: Theme.textDim
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.maximumWidth: 120
            }
        }
        MouseArea {
            id: srowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.playFile(srow.data.path)
        }
    }

    // ── contenuto (420×250 fisso, ritagliato dalla forma) ───────────
    Item {
        width: root.maxW
        height: root.maxH

        // ═══════════════════════════ HOME ═══════════════════════════
        Item {
            id: homeView
            anchors.fill: parent
            visible: root.view === "home"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // card brano corrente (nascosta se non suona)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    radius: Theme.tileR
                    color: Theme.hover
                    visible: root.hasTrack

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setView("now")
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle {
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                radius: 6
                                color: Theme.active
                                clip: true
                                Image {
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    source: root.dispCover
                                    asynchronous: true
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    text: root.dispTitle
                                    color: Theme.text
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.dispArtist || "—"
                                    color: Theme.textDim
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        // seek
                        Item {
                            id: homeSeek
                            Layout.fillWidth: true
                            Layout.preferredHeight: 5
                            readonly property real pos: root.liveLen > 0
                                   ? Math.min(1, root.livePos / root.liveLen) : 0
                            Rectangle {
                                anchors.fill: parent
                                radius: 3
                                color: Theme.bgPanel
                            }
                            Rectangle {
                                width: Math.max(5, homeSeek.pos * parent.width)
                                height: parent.height
                                radius: 3
                                color: Theme.accent
                            }
                        }

                        // controlli
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.rightMargin: 0
                            spacing: 6
                            IconImage {
                                implicitSize: 16
                                source: Theme.icon("prev.svg")
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.player) root.player.previous()
                                }
                            }
                            IconImage {
                                implicitSize: 18
                                source: root.isPlaying ? Theme.icon("pause.svg")
                                       : Theme.icon("play.svg")
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.togglePlay()
                                }
                            }
                            IconImage {
                                implicitSize: 16
                                source: Theme.icon("next.svg")
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.player) root.player.next()
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }

                // nav: [Playlist] [Brani]
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.tileR
                        color: navPlMa.containsMouse ? Theme.hover : Theme.bgDeep
                        Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            IconImage { implicitSize: 18; source: Theme.icon("list.svg") }
                            Text { text: "Playlist"; color: Theme.text; font.pixelSize: 13 }
                        }
                        MouseArea {
                            id: navPlMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setView("playlists")
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.tileR
                        color: navSnMa.containsMouse ? Theme.hover : Theme.bgDeep
                        Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            IconImage { implicitSize: 18; source: Theme.icon("folder.svg") }
                            Text { text: "Brani"; color: Theme.text; font.pixelSize: 13 }
                        }
                        MouseArea {
                            id: navSnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setView("songs")
                        }
                    }
                }
            }
        }

        // ═══════════════════════════ NOW ════════════════════════════
        Item {
            id: nowView
            anchors.fill: parent
            visible: root.view === "now"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // header: ← titolo [🔊 slider]
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 6
                        color: backMa.containsMouse ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                        Text {
                            anchors.centerIn: parent
                            text: "←"
                            color: Theme.textDim
                            font.pixelSize: 15
                        }
                        MouseArea {
                            id: backMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setView("home")
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.dispTitle
                        color: Theme.text
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    IconImage {
                        Layout.preferredWidth: 15
                        Layout.preferredHeight: 15
                        source: Theme.icon("volume.svg")
                    }

                    Item {
                        id: volSlider
                        Layout.preferredWidth: 70
                        Layout.preferredHeight: 6
                        property real pos: root.liveVol
                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            color: Theme.hover
                        }
                        Rectangle {
                            width: Math.max(6, volSlider.pos * parent.width)
                            height: parent.height
                            radius: 3
                            color: Theme.accent
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.topMargin: -6
                            anchors.bottomMargin: -6
                            cursorShape: Qt.PointingHandCursor
                            function setVol(mouse) {
                                const v = Math.max(0, Math.min(1, mouse.x / width))
                                volSlider.pos = v
                                root.liveVol = v
                                if (root.player) root.player.volume = v
                            }
                            onPressed: (mouse) => setVol(mouse)
                            onReleased: (mouse) => setVol(mouse)
                        }
                    }
                }

                // copertina + info
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 64
                        radius: 8
                        clip: true
                        color: Theme.hover
                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: root.dispCover
                            asynchronous: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 4
                        Text {
                            Layout.fillWidth: true
                            text: root.dispArtist
                            color: Theme.text
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.player ? (root.player.trackAlbum || "") : ""
                            color: Theme.textDim
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }
                }

                // seek
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 16
                    spacing: 8

                    Text {
                        text: root.fmtTime(root.livePos)
                        color: Theme.textDim
                        font.pixelSize: 11
                    }

                    Item {
                        id: seekBar
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        property bool dragging: false
                        property real dragPos: 0
                        readonly property real pos: dragging
                                ? dragPos
                                : (root.liveLen > 0
                                   ? Math.min(1, root.livePos / root.liveLen)
                                   : 0)
                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            color: Theme.hover
                        }
                        Rectangle {
                            width: Math.max(6, seekBar.pos * parent.width)
                            height: parent.height
                            radius: 3
                            color: Theme.accent
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.topMargin: -6
                            anchors.bottomMargin: -6
                            cursorShape: Qt.PointingHandCursor
                            function setDrag(mouse) {
                                seekBar.dragging = true
                                seekBar.dragPos = Math.max(0, Math.min(1, mouse.x / width))
                            }
                            onPressed: (mouse) => setDrag(mouse)
                            onPositionChanged: (mouse) => setDrag(mouse)
                            onReleased: (mouse) => {
                                setDrag(mouse)
                                seekBar.dragging = false
                                if (root.player) {
                                    root.player.position = seekBar.dragPos * root.liveLen
                                    root.livePos = seekBar.dragPos * root.liveLen
                                }
                            }
                        }
                    }

                    Text {
                        text: root.fmtTime(root.liveLen)
                        color: Theme.textDim
                        font.pixelSize: 11
                    }
                }

                // controlli
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 8
                        color: prevMa.containsMouse ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 18
                            source: Theme.icon("prev.svg")
                        }
                        MouseArea {
                            id: prevMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.prevTrack()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 20
                        color: ppMa.containsMouse ? Theme.activeHi : Theme.active
                        Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 20
                            source: root.isPlaying ? Theme.icon("pause.svg")
                                   : Theme.icon("play.svg")
                        }
                        MouseArea {
                            id: ppMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.togglePlay()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 8
                        color: nextMa.containsMouse ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 18
                            source: Theme.icon("next.svg")
                        }
                        MouseArea {
                            id: nextMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.nextTrack()
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // shuffle
                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: 8
                        color: shufMa.containsMouse ? Theme.hover
                               : (root.shuffleOn ? Theme.active : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 16
                            source: Theme.icon("shuffle.svg")
                            opacity: root.shuffleOn ? 1 : 0.6
                        }
                        MouseArea {
                            id: shufMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.shuffleOn = !root.shuffleOn
                                if (root.shuffleOn) root.initShuffleBag()
                                else root.shuffleBag = []
                            }
                        }
                    }

                    // repeat: None → Playlist → Track → None
                    Rectangle {
                        id: repBtn
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: 8
                        property bool repOn: root.repMode !== "none"
                        color: repMa.containsMouse ? Theme.hover
                               : (repOn ? Theme.active : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 16
                            source: Theme.icon("repeat.svg")
                            opacity: repBtn.repOn ? 1 : 0.6
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 1
                            text: root.repMode === "track" ? "1" : ""
                            color: Theme.accent
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }
                        MouseArea {
                            id: repMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.repMode =
                                root.repMode === "none"     ? "playlist"
                              : root.repMode === "playlist" ? "track"
                                                            : "none"
                        }
                    }
                }
            }
        }

        // ═══════════════════════════ SONGS ══════════════════════════
        Item {
            id: songsView
            anchors.fill: parent
            visible: root.view === "songs"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    spacing: 8
                    Rectangle {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 6
                        color: sBackMa.containsMouse ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                        Text {
                            anchors.centerIn: parent
                            text: "←"
                            color: Theme.textDim
                            font.pixelSize: 15
                        }
                        MouseArea {
                            id: sBackMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setView("home")
                        }
                    }
                    Text {
                        text: "Brani"
                        color: Theme.text
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }
                    Text {
                        text: root.songsCountText
                        color: Theme.textDim
                        font.pixelSize: 11
                    }
                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: 22
                        placeholderText: "Cerca…"
                        color: Theme.text
                        font.pixelSize: 12
                        background: Rectangle {
                            color: searchField.activeFocus ? "#2a2338" : "transparent"
                            radius: Theme.btnR
                            Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                        }
                        onTextChanged: root.searchText = text.trim()
                    }
                    Rectangle {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 6
                        color: ripMa.containsMouse ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 15
                            source: Theme.icon("search.svg")
                        }
                        MouseArea {
                            id: ripMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openRipFlyout()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"
                    ListView {
                        id: songsList
                        anchors.fill: parent
                        anchors.topMargin: -6
                        model: root.filteredSongs
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Rectangle {
                            id: srow
                            width: songsList.width
                            property string songPath: modelData.path
                            readonly property bool expanded: modelData.path === root.menuSong
                            height: expanded ? (64 + sMenu.implicitHeight) : 64
                            clip: true
                            radius: Theme.btnR
                            color: srowMa.containsMouse ? Theme.hover : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                            Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.InOutCubic } }
                            // play area (solo riga base, 64px)
                            MouseArea {
                                id: srowMa
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                height: 64
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.playFile(modelData.path)
                            }
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 0
                                // riga base
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 64
                                    Layout.leftMargin: 8
                                    Layout.rightMargin: 8
                                    spacing: 10
                                    Rectangle {
                                        Layout.preferredWidth: 48
                                        Layout.preferredHeight: 48
                                        radius: 6
                                        clip: true
                                        color: Theme.hover
                                        Image {
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectCrop
                                            source: modelData.cover
                                            asynchronous: true
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.title
                                            color: Theme.text
                                            font.pixelSize: 13
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.artist
                                            color: Theme.textDim
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }
                                    Rectangle {
                                        Layout.preferredWidth: 84
                                        Layout.fillHeight: true
                                        radius: Theme.btnR
                                        color: sDotsMa.containsMouse ? Theme.hover : "transparent"
                                        Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "⋮"
                                            color: Theme.textDim
                                            font.pixelSize: 18
                                        }
                                        MouseArea {
                                            id: sDotsMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.menuSong = (root.menuSong === modelData.path) ? null : modelData.path
                                        }
                                    }
                                }
                                // menu inline: box playlist + crea + elimina
                                ColumnLayout {
                                    id: sMenu
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 12
                                    Layout.rightMargin: 12
                                    Layout.bottomMargin: 8
                                    spacing: 6
                                    opacity: srow.expanded ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.InOutQuad } }
                                    // ══ BOX PLAYLIST ══
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: plBoxCol.implicitHeight + 8
                                        radius: 8
                                        color: "#1e1826"
                                        border.width: 1
                                        border.color: "#2b2536"
                                        Column {
                                            id: plBoxCol
                                            width: parent.width - 8
                                            x: 4
                                            y: 4
                                            spacing: 2
                                            Repeater {
                                                model: root.playlists
                                                delegate: Rectangle {
                                                    width: plBoxCol.width
                                                    height: 30
                                                    radius: 6
                                                    color: plMa.containsMouse ? Theme.hover : "transparent"
                                                    Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                                                    Text {
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: 10
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: parent.width - 20
                                                        text: modelData.name + "  (" + modelData.count + ")"
                                                        color: Theme.text
                                                        font.pixelSize: 12
                                                        elide: Text.ElideRight
                                                    }
                                                    MouseArea {
                                                        id: plMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            root.addSongToPlaylist(srow.songPath, modelData.name)
                                                            root.menuSong = null
                                                        }
                                                    }
                                                }
                                            }
                                            // crea playlist (bordo tratteggiato +)
                                            Rectangle {
                                                width: plBoxCol.width
                                                height: 34
                                                radius: 8
                                                color: plCreateMa.containsMouse ? Theme.hover : "transparent"
                                                Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                                                Canvas {
                                                    anchors.fill: parent
                                                    anchors.margins: 1
                                                    onPaint: {
                                                        var ctx = getContext("2d")
                                                        ctx.clearRect(0, 0, width, height)
                                                        ctx.strokeStyle = "#4a4258"
                                                        ctx.lineWidth = 1
                                                        ctx.setLineDash([5, 4])
                                                        ctx.strokeRect(0.5, 0.5, width - 1, height - 1)
                                                    }
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "+  Nuova playlist"
                                                    color: Theme.textDim
                                                    font.pixelSize: 12
                                                }
                                                MouseArea {
                                                    id: plCreateMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.openNewPl(srow.songPath)
                                                }
                                            }
                                        }
                                    }
                                    // ══ ELIMINA ══ (rosso, cestino su hover)
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 34
                                        radius: 6
                                        color: sDelMa.containsMouse ? "#3a1f2a" : "transparent"
                                        Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Elimina"
                                            color: "#e05a6a"
                                            font.pixelSize: 13
                                        }
                                        IconImage {
                                            anchors.right: parent.right
                                            anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            implicitSize: 14
                                            source: Theme.icon("trash.svg")
                                            opacity: sDelMa.containsMouse ? 1 : 0
                                            Behavior on opacity { NumberAnimation { duration: Theme.hoverMs } }
                                        }
                                        MouseArea {
                                            id: sDelMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.deleteSong(srow.songPath)
                                                root.menuSong = null
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═════════════════════════ PLAYLISTS ═════════════════════════
        Item {
            id: plView
            anchors.fill: parent
            visible: root.view === "playlists"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    spacing: 8
                    Rectangle {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 6
                        color: plBackMa.containsMouse ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                        Text {
                            anchors.centerIn: parent
                            text: "←"
                            color: Theme.textDim
                            font.pixelSize: 15
                        }
                        MouseArea {
                            id: plBackMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setView("home")
                        }
                    }
                    Text {
                        text: "Playlist"
                        color: Theme.text
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.playlists.length + ""
                        color: Theme.textDim
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"

                    // vuoto
                    Text {
                        anchors.centerIn: parent
                        visible: root.playlists.length === 0
                        text: "Nessuna playlist\n(Crea un file .m3u in ~/Music)"
                        color: Theme.textDim
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                    }

                    ListView {
                        anchors.fill: parent
                        anchors.topMargin: -6
                        model: root.playlists
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Rectangle {
                            id: plRow
                            property var pl: modelData
                            width: plView.width - 28
                            height: 64
                            radius: Theme.btnR
                            color: plRowMa.containsMouse ? Theme.hover : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.hoverMs } }

                            // click riga = apri dettaglio (dietro il layout, così il cestino resta in cima)
                            MouseArea {
                                id: plRowMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openDetail(plRow.pl.name)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 10

                                // 2×2 copertine casuali della playlist
                                Grid {
                                    Layout.alignment: Qt.AlignVCenter
                                    columns: 2
                                    columnSpacing: 3
                                    rowSpacing: 3
                                    Repeater {
                                        model: plRow.pl.covers || []
                                        delegate: Rectangle {
                                            width: 24
                                            height: 24
                                            radius: 4
                                            color: Theme.bgSolid
                                            clip: true
                                            visible: modelData.length > 0
                                            Image {
                                                anchors.fill: parent
                                                fillMode: Image.PreserveAspectCrop
                                                source: modelData
                                                asynchronous: true
                                            }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        text: plRow.pl.name
                                        color: Theme.text
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: plRow.pl.count + " brani   ·   " + root.fmtHours(plRow.pl.hours)
                                             + (plRow.pl.mood ? "   ·   " + plRow.pl.mood : "")
                                        color: Theme.textDim
                                        font.pixelSize: 11
                                    }
                                }

                                // cestino (hover → elimina playlist)
                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30
                                    radius: 8
                                    color: plDelMa.containsMouse ? Theme.hover : "transparent"
                                    Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                                    IconImage {
                                        anchors.centerIn: parent
                                        implicitSize: 18
                                        source: Theme.icon("trash.svg")
                                    }
                                    MouseArea {
                                        id: plDelMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.deletePlaylist(plRow.pl.name)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═════════════════════════ DETAIL ════════════════════════════
        Item {
            id: detailView
            anchors.fill: parent
            visible: root.view === "detail"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    spacing: 10
                    Rectangle {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 6
                        color: dBackMa.containsMouse ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                        Text {
                            anchors.centerIn: parent
                            text: "←"
                            color: Theme.textDim
                            font.pixelSize: 15
                        }
                        MouseArea {
                            id: dBackMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setView("playlists")
                        }
                    }
                    Grid {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        columns: 2
                        columnSpacing: 4
                        rowSpacing: 4
                        Repeater {
                            model: root.plCovers
                            delegate: Rectangle {
                                width: 18
                                height: 18
                                radius: 3
                                color: Theme.bgSolid
                                clip: true
                                visible: modelData.length > 0
                                Image {
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    source: modelData
                                    asynchronous: true
                                }
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: root.currentPl
                            color: Theme.text
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.plSongs.length + " brani   ·   " + root.fmtHours(root.plHours)
                                 + (root.plMood ? "   ·   " + root.plMood : "")
                            color: Theme.textDim
                            font.pixelSize: 11
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"
                    ListView {
                        id: detList
                        anchors.fill: parent
                        anchors.topMargin: -6
                        model: root.plSongs
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Rectangle {
                            id: drow
                            width: detList.width
                            property string songPath: modelData.path
                            height: 64
                            radius: Theme.btnR
                            color: drowMa.containsMouse ? Theme.hover : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                            // play area (tutta la riga tranne il cestino)
                            MouseArea {
                                id: drowMa
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: parent.width - 48
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.playFile(modelData.path, root.plSongs)
                            }
                            RowLayout {
                                anchors.fill: parent
                                Layout.leftMargin: 8
                                Layout.rightMargin: 8
                                spacing: 10
                                Rectangle {
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    radius: 6
                                    clip: true
                                    color: Theme.hover
                                    Image {
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        source: modelData.cover
                                        asynchronous: true
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title
                                        color: Theme.text
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.artist
                                        color: Theme.textDim
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }
                                // cestino: visibile solo su hover, rimuove SOLO dalla playlist
                                Rectangle {
                                    Layout.preferredWidth: 40
                                    Layout.fillHeight: true
                                    radius: Theme.btnR
                                    color: dTrashMa.containsMouse ? "#3a1f2a" : "transparent"
                                    opacity: (drowMa.containsMouse || dTrashMa.containsMouse) ? 1 : 0
                                    Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                                    Behavior on opacity { NumberAnimation { duration: Theme.hoverMs } }
                                    IconImage {
                                        anchors.centerIn: parent
                                        implicitSize: 16
                                        source: Theme.icon("trash.svg")
                                    }
                                    MouseArea {
                                        id: dTrashMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.removeFromPlaylist(root.currentPl, drow.songPath)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
