#!/usr/bin/env python3
"""Steam: giochi recenti (SOLO dati locali, no rete) in JSON.

Il menu deve aprirsi istantaneo, quindi non facciamo chiamate di rete qui.
Il nome viene dal manifest locale (appmanifest_<id>.acf); se manca,
ricorriamo a una cache riempita in background da `warm`.

Uso:
    steam_scan.py recent [N]     -> [{"appid":"123","name":"Game"}, ...]
    steam_scan.py warm           -> riempie la cache dei nomi (API store)
"""
import json
import os
import pathlib
import sys

HOME = pathlib.Path.home()
STEAM = HOME / ".local" / "share" / "Steam"
CACHE = HOME / ".config" / "quickshell" / "steam_names.json"


def _recent_game_ids():
    """(appid, mtime) di tutti i giochi mai giocati, dal più recente."""
    user = STEAM / "userdata"
    games = []
    if user.exists():
        for ud in user.iterdir():
            if not (ud.is_dir() and ud.name.isdigit()):
                continue
            for g in ud.iterdir():
                if g.is_dir() and g.name.isdigit():
                    games.append((g.name, g.stat().st_mtime))
    games.sort(key=lambda x: -x[1])
    return games


def _read_cache():
    if CACHE.exists():
        try:
            return json.loads(CACHE.read_text())
        except (OSError, ValueError):
            pass
    return {}


def _game_name(appid):
    manifest = STEAM / "steamapps" / f"appmanifest_{appid}.acf"
    if manifest.exists():
        try:
            for line in manifest.read_text().splitlines():
                if '"name"' in line:
                    return line.split('"name"')[1].strip().strip('"')
        except OSError:
            pass
    return _read_cache().get(appid)


def cmd_recent(argv):
    n = int(argv[0]) if argv else 5
    out = []
    for appid, _t in _recent_game_ids():
        name = _game_name(appid)
        if not name:
            continue
        out.append({"appid": appid, "name": name})
        if len(out) >= n:
            break
    print(json.dumps(out))


def cmd_warm(argv):
    """Riempie in background la cache dei nomi via API store (no key)."""
    import time
    import urllib.request

    cache = _read_cache()
    missing = [a for a, _t in _recent_game_ids() if a not in cache]
    for appid in missing:
        time.sleep(3)  # rate limit dell'API store
        try:
            req = urllib.request.Request(
                f"https://store.steampowered.com/api/appdetails?appids={appid}",
                headers={"Accept-Encoding": "identity"},
            )
            with urllib.request.urlopen(req, timeout=8) as r:
                data = json.loads(r.read()).get(appid, {}).get("data", {})
            name = data.get("name")
            if name:
                cache[appid] = name
                CACHE.parent.mkdir(parents=True, exist_ok=True)
                CACHE.write_text(json.dumps(cache, indent=1))
        except Exception:
            continue
    print("ok")


def main():
    if len(sys.argv) < 2:
        return
    cmd = sys.argv[1]
    if cmd == "recent":
        cmd_recent(sys.argv[2:])
    elif cmd == "warm":
        cmd_warm(sys.argv[2:])


if __name__ == "__main__":
    main()
