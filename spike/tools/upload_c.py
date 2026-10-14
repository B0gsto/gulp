#!/usr/bin/env python3
"""Spike part C: upload the S0-A1/S0-A2 FBX files as private Model assets through Open Cloud (tools/assets.py).

  upload_c.py [name ...]     upload (default: all), print one line per file, ids into spike/out/oc/manifest.json
The manifest lives in the git-ignored spike/out/oc (a scratch GameDir), so nothing under assets/ changes.
The .rbxm download-back uses only the delivery route; when it fails the asset id is still recorded.
"""
import os, sys
sys.path.insert(0, "/Users/bogdan/RobloxProjects/tools")
import assets  # noqa: E402

WT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GAME = os.path.join(WT, "spike", "out", "oc")
FILES = {
    "M_Prop_ScaleCube": "assets/export/meshes/M_Prop_ScaleCube.fbx",
    "M_Species_Base_Fish_RigTest": "assets/export/meshes/M_Species_Base_Fish_RigTest.fbx",
    "M_Species_Base_Fish": "assets/export/meshes/M_Species_Base_Fish.fbx",
    "A_Fish_Swim": "assets/export/animations/A_Fish_Swim.fbx",
}

def images():
    """The S0-A3/S0-A4 test textures (generated, flat): white colour map, flat roughness, emissive stripes, overlay bands."""
    m = assets.Manifest(GAME)
    tex = os.path.join(WT, "spike", "out", "tex")
    for fn in sorted(os.listdir(tex)):
        if fn.endswith(".png"):
            e = assets.upload(GAME, os.path.join(tex, fn), "Image", manifest=m, log=lambda *a: None)
            print(fn, "->", e.get("assetId"), e.get("moderation"))


if __name__ == "__main__":
    if sys.argv[1:] == ["images"]:
        images()
        sys.exit(0)
    want = sys.argv[1:] or list(FILES)
    m = assets.Manifest(GAME)
    for name in want:
        path = os.path.join(WT, FILES[name])
        try:
            e = assets.upload(GAME, path, "Model", name=name, manifest=m, route="delivery", log=lambda *a: None)
            print(name, "->", e.get("assetId"), e.get("moderation"), "rbxm" if e.get("rbxm") else "")
        except Exception as ex:  # noqa: BLE001
            print(name, "FAILED", str(ex)[:300])
            m.reload()
            for k, v in m.data.items():
                if v.get("name") == name:
                    print("  recorded id", v.get("assetId"))
