"""Self-test of the clip checks (clips.py): each check must catch the fault it is for.

    Blender --background --python assets/source/_shared/blender/clips_selftest.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import clips  # noqa: E402
import rigs  # noqa: E402
import run  # noqa: E402
import template  # noqa: E402
import validate  # noqa: E402

FISH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "families", "fish", "build.py")


def main():
    template.open_template()
    spec = run.load_build(FISH).build()
    arm = spec["armature"]
    good = {c["name"]: c for c in spec["actions"]}
    cases = []

    def expect(label, clip, check, ok):
        report = validate.Report()
        clips.check(spec, clip, report)
        row = next(r for r in report.rows if r["check"] == check)
        cases.append((label, row["ok"] == ok, row["detail"]))

    expect("good swim loop passes the seam check", good["A_Fish_Swim"], "loop seam", True)
    kinked = rigs.bake_clip(arm, "A_Fish_Swim", 16, lambda p: rigs.fish_swim_pose(p ** 1.3))
    expect("kinked loop fails the seam check", kinked, "loop seam", False)
    short = rigs.bake_clip(arm, "A_Fish_SwimFast", 12, rigs.fish_swimfast_pose)
    expect("12-frame SwimFast fails the length check (07: loop 8)", short, "length", False)
    drift = rigs.bake_clip(arm, "A_Fish_Idle", 60, lambda p: dict(rigs.fish_idle_pose(p), Root={"loc": (0.0, 0.0, 0.1 * math.sin(6.283 * p))}))
    expect("Root bob fails the root-motion check", drift, "no root motion", False)
    scaled = clips.bake(arm, "A_Fish_Dash", rigs.fish_dash_pose)
    arm.animation_data.action = scaled["action"]
    arm.pose.bones["Jaw"].keyframe_insert("scale", frame=0)
    expect("a scale key fails the bone-name check", scaled, "bone names", False)
    stripped = clips.strip(clips.bake(arm, "A_Fish_Bite", rigs.fish_bite_pose), ["Spine1", "Spine3", "Spine4", "TailFin", "Dorsal"])
    report = validate.Report()
    validate.check_action(spec, stripped, report)
    row = next(r for r in report.rows if r["check"] == "all bones keyed")
    cases.append(("sway-stripped Bite still passes 'all bones keyed'", row["ok"], row["detail"]))

    for label, ok, detail in cases:
        print("[clips-selftest] %s  %s  (%s)" % ("PASS" if ok else "FAIL", label, detail))
    bad = [c for c in cases if not c[1]]
    print("[clips-selftest] %d of %d passed" % (len(cases) - len(bad), len(cases)))
    sys.exit(1 if bad else 0)


main()
