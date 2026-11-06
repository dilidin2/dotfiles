#!/usr/bin/env python3
"""Elenco le app installate (.desktop) per il launcher.

Uso:
    launcher_apps.py            → stampa la lista JSON (ordinata per uso, poi nome)
    launcher_apps.py bump ID    → incrementa il conteggio d'uso di ID

Il conteggio d'uso sta in ~/.config/quickshell/app_usage.json
(anche qui l'id .desktop è la chiave, come in Ignis).
"""
import os
import sys
import json
import glob

DIRS = [
    os.path.expanduser("~/.local/share/applications"),
    "/usr/local/share/applications",
    "/usr/share/applications",
]
USAGE = os.path.expanduser(
    "~/.config/quickshell/app_usage.json"
)


def _parse_desktop(path):
    d = {}
    in_entry = False
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith("["):
                    in_entry = (line == "[Desktop Entry]")
                    continue
                if not in_entry or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                d[k.strip()] = v.strip()
    except Exception:
        return None
    return d


def _load_usage():
    try:
        with open(USAGE, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def _save_usage(u):
    try:
        os.makedirs(os.path.dirname(USAGE), exist_ok=True)
        with open(USAGE, "w", encoding="utf-8") as f:
            json.dump(u, f, indent=2, sort_keys=True)
    except Exception:
        pass


def _scan():
    apps = {}
    for dirp in DIRS:
        for path in sorted(glob.glob(os.path.join(dirp, "*.desktop"))):
            base = os.path.basename(path)
            d = _parse_desktop(path)
            if d is None:
                continue
            if d.get("NoDisplay", "").lower() in ("true", "1"):
                continue
            if d.get("Hidden", "").lower() in ("true", "1"):
                continue
            name = d.get("Name", "")
            if not name:
                continue
            # preferisce la versione localizzata (it), poi en
            name = d.get("Name[it]", d.get("Name[en]", name))
            comment = d.get("Comment", d.get("Comment[it]", ""))
            icon = d.get("Icon", "")
            keywords = [k.strip() for k in d.get("Keywords", "").split(";") if k.strip()]
            # il dir locale (primo in DIRS) ha priorità
            if base not in apps:
                apps[base] = {
                    "id": base,
                    "name": name,
                    "icon": icon,
                    "comment": comment,
                    "keywords": keywords,
                }
    return list(apps.values())


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "bump":
        u = _load_usage()
        u[sys.argv[2]] = u.get(sys.argv[2], 0) + 1
        _save_usage(u)
        return
    usage = _load_usage()
    apps = _scan()
    apps.sort(key=lambda a: (-usage.get(a["id"], 0), a["name"].lower()))
    print(json.dumps(apps, ensure_ascii=False))


if __name__ == "__main__":
    main()
