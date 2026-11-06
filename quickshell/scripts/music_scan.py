#!/usr/bin/env python3
"""Dati musica per il pannello Quickshell.

Comandi:
  songs       -> [{"path","name","artist","title","cover"}]
  playlists   -> [{"name","path","count","songs":[...]}]
  all         -> {"songs":[...], "playlists":[...]}
  add PL SONG -> aggiunge SONG alla playlist PL (crea il .m3u se serve)
  delete SONG -> sposta SONG nel cestino (o lo rimuove) e lo toglie dalle playlist
"""
import sys
import json
import pathlib
import hashlib
import subprocess

MUSIC = pathlib.Path.home() / "Music"
EXTS = {".mp3", ".flac", ".ogg", ".opus", ".wav", ".m4a"}
CACHE = pathlib.Path.home() / ".cache" / "quickshell" / "covers"
CACHE.mkdir(parents=True, exist_ok=True)


def parse_name(fn: str):
    """'Artist - Title.mp3' -> (artist, title)."""
    stem = pathlib.Path(fn).stem
    if " - " in stem:
        artist, title = stem.split(" - ", 1)
        return artist.strip(), title.strip()
    return "", stem


def extract_cover(path: pathlib.Path) -> str:
    """Estrae l'art embedded (mjpeg) con ffmpeg, lo cache. Ritorna il path o ''."""
    h = hashlib.sha1(str(path).encode()).hexdigest()[:16]
    out = CACHE / (h + ".png")
    if out.exists() and out.stat().st_size > 0:
        return str(out)
    try:
        r = subprocess.run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error",
             "-i", str(path), "-map", "0:v", "-frames:v", "1",
             "-vf", "scale=256:-1", "-y", str(out)],
            capture_output=True, timeout=20)
        if r.returncode == 0 and out.exists() and out.stat().st_size > 0:
            return str(out)
    except Exception:
        pass
    return ""


def _duration(path: pathlib.Path) -> float:
    """Durata in secondi via ffprobe (0 se fallisce)."""
    try:
        r = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=noprint_wrappers=1:nokey=1", str(path)],
            capture_output=True, timeout=15, text=True)
        if r.returncode == 0:
            return float(r.stdout.strip() or 0)
    except Exception:
        pass
    return 0.0


def _entry(p: pathlib.Path):
    artist, title = parse_name(p.name)
    return {"path": str(p), "name": p.name,
            "artist": artist, "title": title,
            "cover": extract_cover(p),
            "duration": _duration(p)}


def songs():
    out = []
    for f in sorted(MUSIC.rglob("*")):
        if f.is_file() and f.suffix.lower() in EXTS:
            out.append(_entry(f))
    return out


def parse_m3u(path: pathlib.Path):
    base = path.parent
    out = []
    try:
        for line in path.read_text(errors="ignore").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            p = pathlib.Path(line)
            if not p.is_absolute():
                p = base / p
            if p.is_file():
                out.append(str(p))
    except Exception:
        pass
    return out


def _mood(f: pathlib.Path) -> str:
    try:
        for line in f.read_text(errors="ignore").splitlines():
            line = line.strip()
            if line.startswith("#MOOD:"):
                return line[len("#MOOD:"):].strip()
    except OSError:
        pass
    return ""


def playlists():
    out = []
    for f in sorted(MUSIC.rglob("*.m3u*")):
        if f.is_file():
            raw = parse_m3u(f)
            out.append({"name": f.stem, "mood": _mood(f), "path": str(f),
                        "count": len(raw),
                        "songs": [_entry(pathlib.Path(p)) for p in raw]})
    return out


def add_to_playlist(name: str, song: str):
    f = MUSIC / (name + ".m3u")
    lines = []
    if f.exists():
        lines = [l for l in f.read_text(errors="ignore").splitlines()
                 if l.strip() and not l.startswith("#")]
    if song not in lines:
        lines.append(song)
    f.write_text("\n".join(lines) + ("\n" if lines else ""))
    return True


def create_playlist(name: str, mood: str = "",
                    first_song: str | None = None) -> str:
    name = name.strip()
    if not name:
        return ""
    f = MUSIC / (name + ".m3u")
    lines = [f"#PLAYLIST:{name}", f"#MOOD:{mood}"]
    if first_song:
        lines.append(first_song)
    f.write_text("\n".join(lines) + "\n")
    return name


def delete_playlist(name: str) -> bool:
    f = MUSIC / (name + ".m3u")
    if not f.exists():
        return False
    try:
        subprocess.run(["gio", "trash", str(f)], capture_output=True, timeout=10)
    except Exception:
        try:
            f.unlink()
        except Exception:
            pass
    return True


def delete_song(path: str):
    p = pathlib.Path(path)
    if not p.exists():
        return False
    try:
        subprocess.run(["gio", "trash", str(p)], capture_output=True, timeout=10)
    except Exception:
        try:
            p.unlink()
        except Exception:
            pass
    # toglilo dalle playlist
    for f in MUSIC.rglob("*.m3u*"):
        lines = [l for l in f.read_text(errors="ignore").splitlines()
                 if l.strip() and l.strip() != str(p) and not l.startswith("#")]
        f.write_text("\n".join(lines) + ("\n" if lines else ""))
    return True


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "all"
    if cmd == "songs":
        print(json.dumps(songs()))
    elif cmd == "playlists":
        print(json.dumps(playlists()))
    elif cmd == "all":
        print(json.dumps({"songs": songs(), "playlists": playlists()}))
    elif cmd == "add" and len(sys.argv) > 3:
        add_to_playlist(sys.argv[2], sys.argv[3])
        print("ok")
    elif cmd == "create" and len(sys.argv) > 2:
        name = create_playlist(
            sys.argv[2],
            sys.argv[3] if len(sys.argv) > 3 else "",
            sys.argv[4] if len(sys.argv) > 4 else None)
        print(name)
    elif cmd == "delete" and len(sys.argv) > 2:
        delete_song(sys.argv[2])
        print("ok")
    elif cmd == "rm" and len(sys.argv) > 2:
        delete_playlist(sys.argv[2])
        print("ok")
    else:
        print("{}")


if __name__ == "__main__":
    main()
