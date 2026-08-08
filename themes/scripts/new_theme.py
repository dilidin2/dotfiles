#!/usr/bin/env python3
"""
new_theme.py - Create a new theme from a background image using pywal.

Usage:
    new_theme.py <theme-name> [image-path]

If image-path is not provided, you'll be prompted to select one with wofi.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

THEMES_DIR = Path.home() / ".themes"
VENV_PYTHON = THEMES_DIR / ".venv" / "bin" / "python"
WAL_CACHE = Path.home() / ".cache" / "wal"


def select_image_with_wofi() -> str:
    """Let user pick an image using wofi."""
    images = []
    picture_dirs = [
        Path.home() / "Pictures",
        Path.home() / "Downloads",
    ]

    for d in picture_dirs:
        if d.exists():
            for ext in ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]:
                images.extend(str(p) for p in d.rglob(ext) if p.is_file())

    if not images:
        print("No images found. Please specify an image path.")
        sys.exit(1)

    result = subprocess.run(
        ["wofi", "--show", "dmenu", "--prompt", "Select background image: "],
        input="\n".join(images),
        capture_output=True,
        text=True,
    )

    selected = result.stdout.strip()
    if not selected:
        print("No image selected.")
        sys.exit(1)

    return selected


def run_pywal(image_path: str) -> dict:
    """Run pywal on the image and return the colors."""
    # Run pywal using the venv python to ensure pywal is available
    env = os.environ.copy()
    env["PYTHONPATH"] = ""

    # Create temp dir for pywal output
    with tempfile.TemporaryDirectory() as tmpdir:
        cache_dir = Path(tmpdir)

        result = subprocess.run(
            [
                str(VENV_PYTHON), "-m", "pywal",
                "-i", image_path,
                "--out-dir", str(cache_dir),
            ],
            capture_output=True,
            text=True,
            env=env,
        )

        if result.returncode != 0:
            print(f"pywal failed: {result.stderr}")
            sys.exit(1)

        # Read colors from pywal output
        colors_file = cache_dir / "colors.json"
        if not colors_file.exists():
            print("pywal did not generate colors.json")
            sys.exit(1)

        with open(colors_file) as f:
            wal_colors = json.load(f)

    return wal_colors


def build_theme_colors(wal_colors: dict) -> dict:
    """Convert pywal colors to our theme format."""
    special = wal_colors["special"]
    colors = wal_colors["colors"]

    # Map pywal colors to our theme structure
    return {
        "bg": special["background"],
        "bg-secondary": colors["color0"],
        "bg-hover": colors["color8"],
        "primary": colors["color1"],
        "primary-light": colors["color9"],
        "primary-dark": colors["color10"],
        "accent": colors["color2"],
        "accent-urgent": colors["color3"],
        "lavender": colors["color4"],
        "lavender-dark": colors["color5"],
        "text": special["foreground"],
        "text-primary": colors["color7"],
        "text-secondary": colors["color15"],
        "text-muted": colors["color11"],
        "terminal-green": colors["color2"],
        "terminal-yellow": colors["color3"],
        "terminal-blue": colors["color4"],
        "terminal-cyan": colors["color6"],
    }


def create_theme(theme_name: str, image_path: str) -> None:
    """Create a new theme directory with extracted colors."""
    theme_dir = THEMES_DIR / theme_name
    bg_dir = THEMES_DIR / "backgrounds" / theme_name

    if theme_dir.exists():
        print(f"Theme '{theme_name}' already exists. Use a different name.")
        sys.exit(1)

    print(f"Creating theme: {theme_name}")
    print(f"Background: {image_path}")
    print("Extracting colors with pywal...")

    # Run pywal
    wal_colors = run_pywal(image_path)

    # Build theme colors
    theme_colors = build_theme_colors(wal_colors)

    # Create directories
    theme_dir.mkdir(parents=True, exist_ok=True)
    bg_dir.mkdir(parents=True, exist_ok=True)

    # Copy background image
    shutil.copy2(image_path, bg_dir / "background.png")

    # Save theme.json
    theme_data = {
        "name": theme_name,
        "colors": theme_colors,
    }

    with open(theme_dir / "theme.json", "w") as f:
        json.dump(theme_data, f, indent=2)
        f.write("\n")

    print(f"\nTheme '{theme_name}' created successfully!")
    print(f"  Theme dir: {theme_dir}")
    print(f"  Background: {bg_dir / 'background.png'}")
    print(f"\nColors extracted:")
    for key, value in theme_colors.items():
        print(f"  {key}: {value}")


def main():
    if len(sys.argv) < 2:
        print("Usage: new_theme.py <theme-name> [image-path]")
        sys.exit(1)

    theme_name = sys.argv[1]

    # Validate theme name (alphanumeric, hyphens, underscores only)
    if not all(c.isalnum() or c in "-_" for c in theme_name):
        print("Theme name can only contain letters, numbers, hyphens, and underscores.")
        sys.exit(1)

    # Get image path
    if len(sys.argv) >= 3:
        image_path = sys.argv[2]
    else:
        image_path = select_image_with_wofi()

    if not Path(image_path).exists():
        print(f"Image not found: {image_path}")
        sys.exit(1)

    create_theme(theme_name, image_path)


if __name__ == "__main__":
    main()
