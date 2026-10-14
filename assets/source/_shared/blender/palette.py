"""Rewrites assets/source/_shared/palette/gulp_palette.gpl from gulp_palette.json (06 section 15.2).

Run with the system Python:  python3 assets/source/_shared/blender/palette.py
The `palette` build step of 06 section 15.4 (texture sampling) is not in this first version.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402


def write_gpl(path=common.PALETTE_GPL):
    lines = ["GIMP Palette", "Name: GULP", "Columns: 8", "# Generated from gulp_palette.json by assets/source/_shared/blender/palette.py"]
    for name, hexcode in common.flat_palette():
        r, g, b = common.hex_to_rgb255(hexcode)
        lines.append("%3d %3d %3d\t%s" % (r, g, b, name))
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    return len(lines) - 4


if __name__ == "__main__":
    print("wrote %d colours to %s" % (write_gpl(), common.PALETTE_GPL))
