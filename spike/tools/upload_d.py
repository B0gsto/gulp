#!/usr/bin/env python3
"""Spike part D uploads through Open Cloud (tools/assets.py), private to the owner; manifest in spike/out/oc.
  upload_d.py model <file> <name>      FBX -> Model (the processed .rbxm is downloaded back to spike/out/oc/assets/models)
  upload_d.py anim <file> <name>       .rbxm/.rbxmx KeyframeSequence -> Animation
  upload_d.py images <file...>         PNG -> Image"""
import os, sys
sys.path.insert(0, "/Users/bogdan/RobloxProjects/tools")
import assets  # noqa: E402

assets.MIME.setdefault(".rbxmx", "model/x-rbxmx")
WT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GAME = os.path.join(WT, "spike", "out", "oc")

if __name__ == "__main__":
    kind, rest = sys.argv[1], sys.argv[2:]
    m = assets.Manifest(GAME)
    quiet = lambda *a: None  # noqa: E731
    if kind == "model":
        e = assets.upload(GAME, rest[0], "Model", name=rest[1], manifest=m, route="delivery", log=quiet)
    elif kind == "anim":
        e = assets.upload(GAME, rest[0], "Animation", name=rest[1], manifest=m, log=quiet)
    else:
        for p in rest:
            e = assets.upload(GAME, p, "Image", manifest=m, log=quiet)
            print(os.path.basename(p), e.get("assetId"), e.get("moderation"))
        sys.exit(0)
    print(rest[1], e.get("assetId"), e.get("moderation"), "rbxm" if e.get("rbxm") else "")
