#!/usr/bin/env python3
"""Generate the terminal emulator theme files in theme/emulator from the Nord palette.

Run it after changing the palette below. The output files are committed, so
this script is only needed when the colors change.
"""

import plistlib
from pathlib import Path

OUT = Path(__file__).resolve().parent / "emulator"

# Nord, mapped onto the 16 ANSI slots the way the official Nord terminal themes do
ANSI = [
    "#3B4252", "#BF616A", "#A3BE8C", "#EBCB8B",
    "#81A1C1", "#B48EAD", "#88C0D0", "#E5E9F0",
    "#4C566A", "#BF616A", "#A3BE8C", "#EBCB8B",
    "#81A1C1", "#B48EAD", "#8FBCBB", "#ECEFF4",
]
BACKGROUND = "#2E3440"
FOREGROUND = "#D8DEE9"
CURSOR = "#D8DEE9"
CURSOR_TEXT = "#2E3440"
SELECTION_BG = "#434C5E"
SELECTION_FG = "#D8DEE9"

NAMES = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]


def rgb(hex_color):
    value = hex_color.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def itermcolors():
    def entry(hex_color):
        r, g, b = rgb(hex_color)
        return {
            "Alpha Component": 1.0,
            "Blue Component": b / 255,
            "Color Space": "sRGB",
            "Green Component": g / 255,
            "Red Component": r / 255,
        }

    data = {f"Ansi {i} Color": entry(color) for i, color in enumerate(ANSI)}
    data["Background Color"] = entry(BACKGROUND)
    data["Foreground Color"] = entry(FOREGROUND)
    data["Bold Color"] = entry(FOREGROUND)
    data["Cursor Color"] = entry(CURSOR)
    data["Cursor Text Color"] = entry(CURSOR_TEXT)
    data["Selection Color"] = entry(SELECTION_BG)
    data["Selected Text Color"] = entry(SELECTION_FG)
    with open(OUT / "nord.itermcolors", "wb") as handle:
        plistlib.dump(data, handle, sort_keys=True)


def alacritty():
    lines = [
        "# Nord for Alacritty. Import it from alacritty.toml:",
        '#   general.import = ["~/.config/oh-my-term/theme/emulator/nord.alacritty.toml"]',
        "",
        "[colors.primary]",
        f'background = "{BACKGROUND}"',
        f'foreground = "{FOREGROUND}"',
        "",
        "[colors.cursor]",
        f'text = "{CURSOR_TEXT}"',
        f'cursor = "{CURSOR}"',
        "",
        "[colors.selection]",
        f'text = "{SELECTION_FG}"',
        f'background = "{SELECTION_BG}"',
        "",
        "[colors.normal]",
    ]
    lines += [f'{name} = "{ANSI[i]}"' for i, name in enumerate(NAMES)]
    lines += ["", "[colors.bright]"]
    lines += [f'{name} = "{ANSI[i + 8]}"' for i, name in enumerate(NAMES)]
    (OUT / "nord.alacritty.toml").write_text("\n".join(lines) + "\n")


def kitty():
    lines = [
        "# Nord for kitty. Add to kitty.conf:",
        "#   include ~/.config/oh-my-term/theme/emulator/nord.kitty.conf",
        "",
        f"background {BACKGROUND}",
        f"foreground {FOREGROUND}",
        f"cursor {CURSOR}",
        f"cursor_text_color {CURSOR_TEXT}",
        f"selection_background {SELECTION_BG}",
        f"selection_foreground {SELECTION_FG}",
    ]
    lines += [f"color{i} {color}" for i, color in enumerate(ANSI)]
    (OUT / "nord.kitty.conf").write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    itermcolors()
    alacritty()
    kitty()
    print(f"wrote theme files to {OUT}")
