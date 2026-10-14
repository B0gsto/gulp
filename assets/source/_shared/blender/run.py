"""One-command build of one asset (docs/06-art-bible.md section 15.4).

    Blender --background --python assets/source/_shared/blender/run.py -- --asset <id> --steps build,validate,export,preview
    Blender --background --python assets/source/<path>/<id>/build.py        (same thing, all steps)

Folders follow docs/07-asset-list.md section 1.3; contact sheets and reports go to
assets/review/<asset>/ (06 section 15.2; chapter 07 names no review folder).

Steps: build, lod, shell, validate, export, preview, clips (versions.py makes the distance versions
and outline shells of any body mesh; uvlayout.py checks the family UV layout and texel
density inside validate; clips.py checks every clip inside validate, and the clips step renders
each clip's strip of key poses and 2-second preview; clips-rbxm writes each clip as a binary
Roblox KeyframeSequence, assets/export/animations/<A_name>.rbxm, with no Studio click, and checks
it read back against the rig's bone names: clips.to_rbxm, animrbx.py, luau/xml2rbxm.luau). Steps always run in that order, whatever order they are listed in:
validate runs after lod and shell so it checks what they made. bake runs a build's texture bakes
(spec["bake"]: functions of the spec, such as a Cycles occlusion bake and the paint over it, or the
trait overlay bake of traitbake.py) after lod and shell and before validate; a build with bakes
always runs them, since its texture is part of the asset. palette (palettecheck.py) runs after
validate: block shares and L*, the water contrast rule and the reserved colour bands, for builds
that declare spec["palette"] (task S6-A1).
Nothing in assets/export/ is written when validation fails. Exit status 1 on any failure.
"""
import argparse
import importlib.util
import json
import os
import resource
import sys
import traceback

LIB_DIR = os.path.dirname(os.path.abspath(__file__))
if LIB_DIR not in sys.path:
    sys.path.insert(0, LIB_DIR)

import bpy  # noqa: E402

import clips  # noqa: E402
import common  # noqa: E402
import export  # noqa: E402
import palettecheck  # noqa: E402
import preview  # noqa: E402
import template  # noqa: E402
import validate  # noqa: E402
import versions  # noqa: E402

STEPS = ("build", "validate", "palette", "shell", "lod", "bake", "export", "preview", "clips", "clips-rbxm")
IMPLEMENTED = ("build", "lod", "shell", "bake", "validate", "palette", "export", "preview", "clips", "clips-rbxm")
DEFAULT_STEPS = "build,lod,shell,bake,validate,palette,export,preview,clips,clips-rbxm"


def parse_args(build_file):
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(prog="run.py")
    parser.add_argument("--asset", default=None)
    parser.add_argument("--steps", default=DEFAULT_STEPS)
    args = parser.parse_args(argv)
    steps = [s.strip() for s in args.steps.split(",") if s.strip()]
    unknown = [s for s in steps if s not in STEPS]
    if unknown:
        raise SystemExit("unknown step(s): %s. Steps are %s" % (", ".join(unknown), ", ".join(STEPS)))
    if build_file is None:
        if not args.asset:
            raise SystemExit("--asset <id> is required")
        build_file = os.path.join(common.find_asset_dir(args.asset), "build.py")
    return os.path.abspath(build_file), steps


def load_build(build_file):
    spec = importlib.util.spec_from_file_location("gulp_asset_build", build_file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run(build_file, steps, builder=None):
    """`builder` (a function returning the spec) replaces the build file's build(); the
    placeholder generator uses it. Then no .blend is saved."""
    asset_dir = os.path.dirname(build_file) if build_file else None
    asset_id = os.path.basename(asset_dir) if asset_dir else None
    for step in steps:
        if step not in IMPLEMENTED:
            print("[run] step '%s' is not in this first version of the tool: skipped" % step)

    template.open_template()
    spec = builder() if builder else load_build(build_file).build()
    name = spec["name"]
    spec.setdefault("id", asset_id or name)
    print("[run] built %s (%s)" % (name, spec["id"]))
    if "lod" in steps:
        versions.run_lod(spec)
    if "shell" in steps:
        versions.run_shell(spec)
    bakes = []
    if spec.get("bake"):
        if "bake" not in steps:
            print("[run] %s carries texture bakes: run with the build" % name)
        for fn in spec["bake"]:
            bakes.append(fn(spec) or {})

    report = validate.Report()
    result = {"asset": name, "id": asset_id, "date": common.today(), "commit": common.git_commit(),
              "blender": bpy.app.version_string, "steps": steps, "export_settings": export.recorded_settings()}
    ok = True
    if "validate" in steps:
        report = validate.run(spec)
        ok = report.ok
    if bakes:
        result["bakes"] = bakes
    if "palette" in steps and spec.get("palette"):
        result["palette"] = palettecheck.run(spec, report)
        ok = report.ok
    if "export" in steps:
        if ok:
            result["exports"] = export.run(spec, report)
            for check in spec.get("post_export_checks", []):     # rows on the files as written
                check(spec, report)
            ok = report.ok
            if not ok:
                for row in report.failures():
                    print("[export] FAIL %s %s %s" % (row["subject"], row["check"], row["detail"]))
        else:
            print("[run] validation failed: nothing exported")
    if "preview" in steps:
        result["preview"] = preview.run(spec, report, ok)
        if True:   # every asset: its versions, or the 07 1.2 reason it has none
            result["preview"]["versions_sheet"] = versions.review_sheet(spec, report, ok)
        if spec.get("weight_check"):   # RIG_Fish weights at the squash, stretch and bite poses
            import weightcheck
            result["preview"]["weights_sheet"] = weightcheck.sheet(spec, report, ok)
    if "clips" in steps and spec.get("actions"):
        result["clips"] = clips.preview(spec, report, ok)
    if "clips-rbxm" in steps and spec.get("actions"):
        result["clips_rbxm"] = clips.to_rbxm(spec, report, ok)
        ok = report.ok
    if "build" in steps and asset_dir:
        blend = os.path.join(asset_dir, asset_id + ".blend")
        bpy.ops.wm.save_as_mainfile(filepath=blend, check_existing=False, copy=True)
        result["blend"] = os.path.relpath(blend, common.REPO_DIR)

    result["ok"] = ok
    result["checks"] = report.rows
    result["meshes"] = [{"name": e["object"].name, "role": e["role"], "triangles": e.get("tris"),
                         "budget": e.get("tri_budget"), "lod": e.get("lod"), "thickness": e.get("thickness"),
                         "self_intersections": e.get("self_intersections"), "texel_density": e.get("texel_density"), "width": e.get("width")}
                        for e in spec["meshes"]]
    result["bones"] = spec.get("bone_counts")
    peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    result["peak_rss_mb"] = round(peak / (1024.0 * 1024.0) if sys.platform == "darwin" else peak / 1024.0, 1)
    out = os.path.join(common.review_dir(name), "%s_report.json" % common.today())
    with open(out, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=1, default=str)
    print("[run] report %s" % out)
    print("[run] peak memory %.0f MB" % result["peak_rss_mb"])
    print("[run] %s %s" % (name, "OK" if ok else "FAILED"))
    return ok


def main(build_file=None):
    try:
        build_file, steps = parse_args(build_file)
        ok = run(build_file, steps)
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        print("[run] FAILED with an error")
        sys.exit(1)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
