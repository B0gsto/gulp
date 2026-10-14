#!/usr/bin/env python3
"""Writes spike/spike.project.json: a complete throwaway place with streaming on and a 150-part
Persistent collision shell (09 section 6.6). Run from anywhere: python3 spike/tools/gen_project.py"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
IDENT = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]


def part(pos, size):
    return {"$className": "Part", "$properties": {
        "Anchored": True, "Size": size, "CFrame": {"CFrame": {"position": pos, "orientation": IDENT}},  # rojo 7.7.1 needs the explicit form
        "Color": [0.16, 0.32, 0.42], "Material": "Slate", "TopSurface": "Smooth", "BottomSurface": "Smooth"}}


shell = {"$className": "Model", "$properties": {"ModelStreamingMode": "Persistent"}}
n = 0
for ix in range(10):          # floor: 10 x 10 tiles of 60 studs, top face at Y = -120
    for iz in range(10):
        n += 1
        shell["Floor_%03d" % n] = part([-270 + 60 * ix, -122, -270 + 60 * iz], [60, 4, 60])
w = 0
for side in range(4):         # walls: 4 x 12 segments of 50 studs, from Y = -120 up to Y = 0
    for i in range(12):
        w += 1
        along = -275 + 50 * i
        if side == 0: pos, size = [along, -60, -302], [50, 120, 4]
        elif side == 1: pos, size = [along, -60, 302], [50, 120, 4]
        elif side == 2: pos, size = [-302, -60, along], [4, 120, 50]
        else: pos, size = [302, -60, along], [4, 120, 50]
        shell["Wall_%03d" % w] = part(pos, size)
shell["Pillar_001"] = part([60, -60, 60], [12, 120, 12])
shell["Pillar_002"] = part([-60, -60, -60], [12, 120, 12])
assert n + w + 2 == 150

project = {
    "name": "GulpSpike",
    "tree": {
        "$className": "DataModel",
        "Workspace": {
            "$className": "Workspace",
            "$properties": {
                "StreamingEnabled": True,
                "StreamingMinRadius": 64,
                "StreamingTargetRadius": 256,
                "StreamingIntegrityMode": "PauseOutsideLoadedArea",
                "ModelStreamingBehavior": "Improved",
                "FallenPartsDestroyHeight": -5000,
            },
            "Collision": shell,
            "Creatures": {"$className": "Folder"},
        },
        "Players": {"$className": "Players", "$properties": {"CharacterAutoLoads": False}},
        "ReplicatedStorage": {"$className": "ReplicatedStorage", "Shared": {"$path": "src/shared"}},
        "ServerScriptService": {"$className": "ServerScriptService", "Server": {"$path": "src/server"}},
        # A Rojo-built place defaults to LegacyChatService; DisplayBubble (S16) needs TextChatService.
        "TextChatService": {"$className": "TextChatService", "$properties": {"ChatVersion": "TextChatService"}},
        "StarterPlayer": {"$className": "StarterPlayer",
                          "StarterPlayerScripts": {"$className": "StarterPlayerScripts", "$path": "src/client"}},
    },
}
with open(os.path.join(HERE, "..", "spike.project.json"), "w") as f:
    json.dump(project, f, indent=1)
    f.write("\n")
print("wrote spike.project.json with", n + w + 2, "shell parts")
