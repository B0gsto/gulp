"""Shared paths, palette access and colour maths for the GULP Blender pipeline.

Rules come from docs/06-art-bible.md (section 15 for the pipeline). Pure Python:
safe to import both inside Blender and from the system python3 (sheet.py).
"""
import datetime
import json
import os
import subprocess

# Folder layout: docs/07-asset-list.md section 1.3 (it owns the layout over 06 section 15.2).
LIB_DIR = os.path.dirname(os.path.abspath(__file__))          # assets/source/_shared/blender
SHARED_DIR = os.path.dirname(LIB_DIR)
SOURCE_DIR = os.path.dirname(SHARED_DIR)
ASSETS_DIR = os.path.dirname(SOURCE_DIR)
REPO_DIR = os.path.dirname(ASSETS_DIR)
EXPORT_DIR = os.path.join(ASSETS_DIR, "export")
REVIEW_DIR = os.path.join(ASSETS_DIR, "review")
PALETTE_JSON = os.path.join(SHARED_DIR, "palette", "gulp_palette.json")
PALETTE_GPL = os.path.join(SHARED_DIR, "palette", "gulp_palette.gpl")
TEMPLATE_BLEND = os.path.join(LIB_DIR, "gulp_template.blend")

# 06 section 6.6 / canon section 16.
CATEGORIES = ("Species", "Prey", "Pred", "Hazard", "Env", "Cove", "Prop", "Trait")

FPS = 30                 # 06 section 15.3
COLOR_ATTR = "Col"       # the one vertex-colour layer of a mesh
UV_NAME = "UVMap"        # the one UV set of a mesh (06 section 6.5)
TAG_ATTR = "gulp_tag"    # build-time vertex tags, never exported
TAG_FRONT = 1            # vertices of a prop's front marker

_palette = None


def palette():
    global _palette
    if _palette is None:
        with open(PALETTE_JSON, "r", encoding="utf-8") as f:
            _palette = json.load(f)
    return _palette


def colour(path):
    """colour('creatures.minnow.mid') -> '#FF9A3D'."""
    node = palette()
    for key in path.split("."):
        node = node[key]
    if not isinstance(node, str):
        raise KeyError("palette entry %s is not a colour" % path)
    return node


def flat_palette():
    """Every colour as ('group.name.part', '#RRGGBB'), in file order."""
    out = []

    def walk(prefix, node):
        if isinstance(node, dict):
            for key, value in node.items():
                walk(prefix + [key], value)
        elif isinstance(node, str) and node.startswith("#"):
            out.append((".".join(prefix), node))

    for group, node in palette().items():
        if isinstance(node, dict):
            walk([group], node)
    return out


def hex_to_rgb255(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hex_to_srgb(h):
    return tuple(c / 255.0 for c in hex_to_rgb255(h))


def srgb_to_linear_channel(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_to_linear(h):
    """Scene-linear RGB for Blender node, light and world colours."""
    return tuple(srgb_to_linear_channel(c) for c in hex_to_srgb(h))


def lstar_from_srgb(rgb):
    """CIE L* (0 to 100) of an sRGB colour given as floats 0 to 1."""
    r, g, b = (srgb_to_linear_channel(c) for c in rgb[:3])
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    return 116.0 * y ** (1.0 / 3.0) - 16.0 if y > 0.008856 else 903.3 * y


def lstar(h):
    return lstar_from_srgb(hex_to_srgb(h))


def today():
    return datetime.date.today().isoformat()


def git_commit():
    try:
        out = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=REPO_DIR,
                             capture_output=True, text=True, timeout=10)
        dirty = subprocess.run(["git", "status", "--porcelain", "--", "assets"], cwd=REPO_DIR,
                               capture_output=True, text=True, timeout=10)
        commit = out.stdout.strip() or "unknown"
        return commit + ("+dirty" if dirty.stdout.strip() else "")
    except Exception:
        return "unknown"


def find_asset_dir(asset_id):
    """The folder under assets/source/ named <asset_id> that holds a build.py."""
    hits = [root for root, dirs, files in os.walk(SOURCE_DIR)
            if os.path.basename(root) == asset_id and "build.py" in files]
    if len(hits) != 1:
        raise SystemExit("asset '%s': expected one build.py, found %d %s" % (asset_id, len(hits), hits))
    return hits[0]


def review_dir(asset_name):
    path = os.path.join(REVIEW_DIR, asset_name)
    os.makedirs(path, exist_ok=True)
    return path
