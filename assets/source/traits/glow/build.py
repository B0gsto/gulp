"""T_Trait_Glow_Fish_Emi, the Glow trait's overlay on the Fish layout, and its scripted master: task
S6-A1 (docs/13-sprint-plan.md Sprint 6; docs/07-asset-list.md section 3.1 row T_Trait_Glow_Fish_Emi
and section 14.1 row "(tool) Trait overlay bake"; docs/06-art-bible.md sections 5.1, 5.4, 8.1 to 8.4).

    Blender --background --python assets/source/traits/glow/build.py

Glow (06 8.2): Light channel, an emissive overlay plus a light in code; signature colour #FFE98A;
home zone the lateral line, nose to tail; fallback zone the tail tip and fin edges (used when a
second Light trait takes the home zone, 06 8.3 rule 1). 07 3.1: two files, the home zone and the
fallback zone, 256 x 256 glow masks:

    T_Trait_Glow_Fish_Emi            home: one continuous glowing band along the lateral line from
                                     the nose to the tail, a full-strength core inside a wide soft
                                     halo; on the head it runs into the eye at the eye's height
                                     (clear of the mouth below), then sweeps down the flank to the
                                     middle of the tail root and fades out along the tail fin
    T_Trait_Glow_Fish_Fallback_Emi   fallback: the whole free edge of the tail fin, the back fin
                                     and both pectorals and the tail's outer part, lit at the home
                                     band's full strength in the same colour, so the same light
                                     reads on a second Light trait's body; it covers the fin trim
                                     a species paints there, so no dark rim shows outside it

`master()` below is the one scripted master the other families bake from (07 3: the Eel, Turtle
and Squid rows are bakes from it with touch-ups). It is written in body coordinates (t along the
body, h up the side, rim out along a fin; traitbake.py), never in pixels, so the bake tool
(traitbake.bake) can lay it on any family layout. The files are baked on the family base mesh
M_Species_Base_Fish (families/fish, 07's dependency) and checked on the Minnow juvenile
(species/minnow): the same texture must fit every species of the family (06 5.4), which the
build measures (`fits`). Both stay under 06 8.3's 15% cap for emissive overlays.

The contact sheet shows the Minnow juvenile wearing it the way the game will (06 8.4 option B):
an overlay shell 0.5% outside the body, see-through where the mask is 0, glowing #FFE98A where it
is lit. The game's shell and its `SurfaceAppearance` are made by code (task S6-C3); these files
carry the mask in grey and again as alpha so one file serves as that shell's colour map
(tinted with the signature colour) and its emissive mask.
"""
import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(HERE, "..", "..")
sys.path.insert(0, os.path.join(SOURCE, "_shared", "blender"))

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import common  # noqa: E402
import meshgen  # noqa: E402
import rigs  # noqa: E402
import texbake  # noqa: E402
import traitbake  # noqa: E402

NAME = "T_Trait_Glow_Fish_Emi"
FALLBACK = "T_Trait_Glow_Fish_Fallback_Emi"
LAYOUT = "Fish"
GLOW = common.colour("traits.glow.signature")
FIT_MATCH = 0.85            # the family texture against a bake on the species' own mesh, 2-texel tolerance (tune)
MID_LEFT = 0.40             # 06 8.3 rule 7: the species' mid colour still shows over 40% of the body
SEEN = 0.3                  # mask level counted as "glowing" for placement and fit (inside the band's soft halo)


# ---------------------------------------------------------------- the scripted master

BAND = 0.115                # half-width in h (share of the local half-depth) where the band is still 0.5 or more
CORE = 0.055                # half-width of the full-strength core
HALO = 0.13                 # the soft glow outside the band, to 0 (under 0.5, so outside the 15% cap's count)
BODY_LEVEL = 0.80           # the band's level between core and edge; the core is 1
TAIL_FADE = (0.0, 0.75)    # the band fades out along the tail fin
FALL_EDGE = (0.40, 0.56)    # fallback: full light from the outline to this edge distance inside it, soft to the second (tune)
FALL_ROOT = (0.10, 0.28)    # fallback: unlit at a fin's root, full from this rim distance (tune)
FALL_TAIL_TIP = (0.55, 0.72)   # fallback: the tail's outer part, lit across (tune)
FALL_FIN_TIP = (0.80, 0.92)    # fallback: a fin's far tip, lit across (tune)
TRIM_LIT = 0.90             # fallback: share of the Minnow's dark fin and tail trim it must light (mask 0.5 or more)


def centre_line(t, frame):
    """h of the lateral line at t: from the snout into the eye at the eye's own height (the eye
    covers it there), out behind the eye and down the flank to the middle of the tail root, where
    it runs onto the tail fin. It stays above the middle of the head, clear of the mouth and smile
    below (06 3.4); passing under the eye put the band's edge along the smile, which then read
    as a dark whisker inside the light."""
    eyes = frame.eyes or [{"t": 0.2, "h": 0.3, "r_h": 0.3, "r_t": 0.05, "area": 1.0}]
    eye = max(eyes, key=lambda e: e["area"])
    eh = min(eye["h"], 0.35)        # at or under the eye's middle: on the Minnow the band runs into its eye
    ts = [0.0, eye["t"] - 1.4 * eye["r_t"], eye["t"], eye["t"] + 1.8 * eye["r_t"], 0.55, 0.80, 1.0]
    hs = [0.30, 0.85 * eh + 0.05, eh, 0.85 * eh, 0.22, 0.10, 0.0]
    return np.interp(t, ts, hs)


def band_width(t):
    """Narrower on the snout, full along the flank; the local depth narrows it toward the tail by itself."""
    return 0.55 + 0.45 * texbake.smoothstep(0.0, 0.16, t)


def master(zone, S, frame):
    role, t, h, rim = S["role"], S["t"], S["h"], S["rim"]
    m = np.zeros(len(t))
    if zone == "home":
        b = role == "body"
        tb, hb = t[b], h[b]
        d = np.abs(hb - centre_line(tb, frame))
        w = band_width(tb)
        # One continuous lit band, no beads: a full core, the band at BODY_LEVEL out to its edge
        # (still 0.5 there), then a soft halo to nothing.
        core = traitbake.smooth_band(d, CORE * w, 0.6 * CORE * w)
        band = 1.0 - texbake.smoothstep(0.55 * BAND * w, (BAND + HALO) * w, d)
        m[b] = np.maximum(core, BODY_LEVEL * band ** 0.8) * texbake.smoothstep(0.0, 0.035, tb)
        tl = role == "tail"
        fade = 1.0 - texbake.smoothstep(TAIL_FADE[0], TAIL_FADE[1], t[tl])
        m[tl] = 0.85 * traitbake.smooth_band(h[tl], 0.07, 0.10) * fade      # carries on from the body's band, then fades
    else:
        # Fallback: the same light as the home band, at full strength, along the whole free edge
        # of the tail fin and of every fin (the outline seen flat, where a species paints its fin
        # trim, so no dark trim shows outside the light), and across the tail's outer part (its
        # tip). The root, where a fin meets the body, stays unlit.
        edge = S["edge"]
        for r, tip in (("tail", FALL_TAIL_TIP), ("fin", FALL_FIN_TIP)):
            sel = role == r
            lit = 1.0 - texbake.smoothstep(FALL_EDGE[0], FALL_EDGE[1], edge[sel])
            lit = np.maximum(lit, texbake.smoothstep(tip[0], tip[1], rim[sel]))
            m[sel] = lit * texbake.smoothstep(FALL_ROOT[0], FALL_ROOT[1], rim[sel])
    return m


# ---------------------------------------------------------------- the family base and the Minnow

def _load(rel, name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(SOURCE, rel, "build.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def base_fish():
    """M_Species_Base_Fish as families/fish/build.py makes it, on its own skeleton."""
    fb = _load("families/fish", "gulp_fish_base_build")
    fit = rigs.FishFit(fb.BODY, fb.EYE, fb.PEC, (0.0, 0.18, fb.Z_HI))
    arm = meshgen.build_armature("RIG_Fish_Base", fit.bones())
    body = meshgen.skin(fb.fish_meshdata(fb.RES, fit).to_object(fb.NAME, "LOD"), arm)
    return body


def minnow():
    """M_Species_Minnow_Juv as species/minnow/build.py makes it; painted in the bake step."""
    mb = _load("species/minnow", "gulp_minnow_build")
    fit = rigs.FishFit(mb.BODY, mb.EYE, mb.PEC, (0.0, 0.18, mb.Z_HI))
    arm = meshgen.build_armature("RIG_Fish", fit.bones())
    md, part_of = mb.minnow_meshdata(mb.RES, fit)
    body = meshgen.skin(md.to_object(mb.NAME, "GEO"), arm)
    return mb, fit, arm, body, part_of


def copy_of(obj, name):
    o = obj.copy()
    o.data = obj.data.copy()
    o.name = o.data.name = name
    bpy.data.collections["PREVIEW"].objects.link(o)
    return o


# ---------------------------------------------------------------- the asset

def build():
    mb, fit, arm, body, part_of = minnow()
    base = base_fish()
    review = common.review_dir(NAME)
    picture = os.path.join(review, "masks_on_layout.png")
    state = {}
    plain = copy_of(body, "PV_Minnow_Plain")
    alt = copy_of(body, "PV_Minnow_Fallback")

    def bake(spec):
        # The Minnow's own colour map, exactly as its build paints it (06 5.2, occlusion baked).
        albedo, block_map, baked = mb.paint_texture(body, part_of)
        work = os.path.join(review, "%s_work.png" % mb.ALBEDO)
        mb.save_png(work, albedo, mb.TEX)
        mat = mb.textured_material("MAT_PV_Minnow", bpy.data.images.load(work))
        for o in (body, plain, alt):
            o.data.materials[0] = mat
        # The bake (traitbake.py): home and fallback on the family base, then the fit on the Minnow.
        home, frame = traitbake.bake(base, LAYOUT, master, "home")
        fall, _ = traitbake.bake(base, LAYOUT, master, "fallback", frame=frame)
        state.update(home=home, fall=fall, frame=frame, block=block_map, albedo=albedo)
        mframe = traitbake.Frame(body, LAYOUT)
        state["mframe"] = mframe
        for zone, mask in (("home", home), ("fallback", fall)):
            state["fit_" + zone] = traitbake.fits(mask, body, LAYOUT, master, zone, level=SEEN)
            state["cov_base_" + zone] = traitbake.coverage(base, mask, frame)
            state["cov_minnow_" + zone] = traitbake.coverage(body, mask, mframe)
            state["outside_" + zone] = traitbake.outside_layout(mask, LAYOUT)
        state["mid_left"] = mid_left(body, block_map, home, mframe)
        state["trim_lit"] = trim_lit(body, block_map, fall, mframe, mb.BLOCKS.index("dark"))
        state["shell_home"] = traitbake.overlay_shell(body, "PV_Minnow_GlowHome", home, GLOW)
        state["shell_fall"] = traitbake.overlay_shell(alt, "PV_Minnow_GlowFallback", fall, GLOW)
        texbake.save_png(picture, traitbake.layout_picture([home, fall], LAYOUT, colour_hex=GLOW))
        spec["preview"]["main"].append(state["shell_home"])
        spec["preview"]["lineup"][1]["objects"].append(state["shell_home"])
        spec["preview"]["lineup"][2]["objects"].append(state["shell_fall"])
        spec["preview"]["extras"][0]["objects"].append(state["shell_home"])
        spec["preview"]["extras"][1]["objects"].append(state["shell_fall"])
        spec["texture_sampler"] = sampler
        lit = np.concatenate([np.outer(home[home > 0.05], texbake.hex_rgb(GLOW)), np.outer(fall[fall > 0.05], texbake.hex_rgb(GLOW))])
        spec["palette"]["texels"] = lit
        spec["palette"]["emissive"] = [{"name": "%s on the Minnow" % n, "lit_share": state["cov_minnow_" + z]["lit_share"]}
                                       for n, z in ((NAME, "home"), (FALLBACK, "fallback"))]
        out = {"frame": frame.summary(), "occlusion": "baked" if baked else "NOT baked"}
        for z in ("home", "fallback"):
            out[z] = {"base": {k: v for k, v in state["cov_base_" + z].items()},
                      "minnow": {k: v for k, v in state["cov_minnow_" + z].items()},
                      "fit_match": round(state["fit_" + z]["match"], 3), "fit_match_by_role": state["fit_" + z]["match_by_role"],
                      "fit_iou": round(state["fit_" + z]["iou"], 3),
                      "fit_mean_abs": round(state["fit_" + z]["mean_abs"], 4)}
        out["mid_left"] = state["mid_left"]
        out["fallback_trim_lit"] = state["trim_lit"]
        print("[glow] home: base %.1f%%, Minnow %.1f%% lit; fit %.3f. fallback: base %.1f%%, Minnow %.1f%%; fit %.3f"
              % (100 * state["cov_base_home"]["lit_share"], 100 * state["cov_minnow_home"]["lit_share"], state["fit_home"]["match"],
                 100 * state["cov_base_fallback"]["lit_share"], 100 * state["cov_minnow_fallback"]["lit_share"], state["fit_fallback"]["match"]))
        return out

    def sampler(u, v):
        big = mb.PAINT
        r = min(big - 1, max(0, int(v * big)))
        c = min(big - 1, max(0, int(u * big)))
        k = state["block"][r, c]
        rr, cc = min(mb.TEX - 1, r // 2), min(mb.TEX - 1, c // 2)
        return (mb.BLOCKS[k] if k >= 0 else None), tuple(float(x) for x in state["albedo"][rr, cc])

    def checks(spec, report):
        for zone, file in (("home", NAME), (FALLBACK and "fallback", FALLBACK)):
            cb, cm = state["cov_base_" + zone], state["cov_minnow_" + zone]
            report.add(file, "emissive cover", max(cb["lit_share"], cm["lit_share"]) <= traitbake.EMISSIVE_CAP,
                       "lights %.1f%% of M_Species_Base_Fish and %.1f%% of the Minnow juvenile (mask 0.5 or more), cap 15%% (06 8.3 rule 3)"
                       % (100 * cb["lit_share"], 100 * cm["lit_share"]))
            report.add(file, "inside the Fish layout", state["outside_" + zone] == 0,
                       "%d lit texels outside the regions of 06 5.4" % state["outside_" + zone])
            f = state["fit_" + zone]
            report.add(file, "fits the Minnow", f["match"] >= FIT_MATCH and min(f["match_by_role"].values()) >= 0.7,
                       "lit texels matched within %d texels by a bake on the Minnow juvenile's own mesh: %.3f (at least %.2f; "
                       "by part %s); strict IoU %.3f, mean difference %.3f"
                       % (traitbake.FIT_TOLERANCE, f["match"], FIT_MATCH, f["match_by_role"], f["iou"], f["mean_abs"]))
            roles = cb["lit_area_by_role"]
            if zone == "home":
                ok = roles.get("body", 0) > 0 and roles.get("fin", 0) == 0 and roles.get("eye", 0) == 0
                detail = "lit on the body %.1f%%, tail fin %.1f%%, fins %.1f%%, eyes %.1f%% of the surface (06 8.2: lateral line, nose to tail)"
            else:
                ok = roles.get("body", 0) == 0 and roles.get("fin", 0) > 0 and roles.get("tail", 0) > 0 and roles.get("eye", 0) == 0
                detail = "lit on the body %.1f%%, tail fin %.1f%%, fins %.1f%%, eyes %.1f%% of the surface (06 8.2: tail tip and fin edges)"
            report.add(file, "zone", ok, detail % tuple(100 * roles.get(r, 0) for r in ("body", "tail", "fin", "eye")))
        report.add(FALLBACK, "covers the fin trim", state["trim_lit"] >= TRIM_LIT,
                   "lights %.0f%% of the Minnow juvenile's dark fin and tail trim (at least %.0f%%), so the fallback reads as a lit "
                   "tail tip and fin edge, not as dark trim beside the light (06 8.2, 8.3)" % (100 * state["trim_lit"], 100 * TRIM_LIT))
        span = state["home_span"] = home_span()
        report.add(NAME, "nose to tail", span[0] <= 0.05 and span[1] >= 0.95 and state["cov_base_home"]["lit_area_by_role"].get("tail", 0) > 0,
                   "the band (mask %.1f or more) runs from t %.2f to %.2f of the body (0 nose, 1 tail root) and onto the tail fin" % ((SEEN,) + span))
        report.add(NAME, "mid colour left (06 8.3 rule 7)", state["mid_left"] >= MID_LEFT,
                   "the Minnow's mid block still shows on %.0f%% of its surface under the home zone (at least 40%%)" % (100 * state["mid_left"]))

    def home_span():
        frame = state["frame"]
        big = traitbake.SIZE
        r = texbake.rasterise(base, big)
        sel = r["filled"] & (state["home"] >= SEEN)
        P, part = r["P"][sel], r["part"][sel]
        rows, cols = np.nonzero(sel)
        body_pts = frame.texel_roles(part, (cols + 0.5) / big, (rows + 0.5) / big) == "body"
        t, _ = frame.body_coords(P[body_pts])
        return float(t.min()), float(t.max())

    def write(mask_key):
        return lambda path: traitbake.save(path, state[mask_key])

    def check_files(spec, report):
        for name in (NAME, FALLBACK):
            path = os.path.join(common.EXPORT_DIR, "textures", name + ".png")
            info = texbake.png_info(path) if os.path.exists(path) else None
            report.add(name + ".png", "texture mode", bool(info) and info[0] == "LA" and info[1] == info[2] == traitbake.SIZE,
                       "%s, want LA %d x %d (06 5.1 8-bit greyscale mask, the same mask as alpha for the overlay shell)"
                       % (info, traitbake.SIZE, traitbake.SIZE))

    return {
        "name": NAME,
        "category": "Trait",
        "id": "glow",
        "budget": "species_juv",
        "rig": "Fish",
        "uv": {"layout": LAYOUT, "texture": "trait_overlay"},
        "armature": arm,
        "origin": "creature",
        "size": (mb.WIDTH, mb.LENGTH, mb.HEIGHT),
        "size_tol": 0.02,
        "facing": {"kind": "bones", "front": "Jaw", "back": "TailFin"},
        "rig_k": fit.k,
        "id_mark": {"block": "accent", "what": "the yellow tail, 03 Minnow"},
        "meshes": [{"object": body, "role": "body", "primary": True}],
        "versions": {"lods": [], "shells": []},
        "bake": [bake],
        "texture_name": "%s, the Minnow juvenile's colour map under the overlay" % mb.ALBEDO,
        "palette": {"zones": []},
        "extra_checks": [checks],
        "post_export_checks": [check_files],
        "exports": [],
        "textures": [
            {"file": "textures/%s.png" % NAME, "write": write("home"), "max": traitbake.SIZE},
            {"file": "textures/%s.png" % FALLBACK, "write": write("fall"), "max": traitbake.SIZE},
        ],
        "preview": {
            "main": [body],
            "blocks": {"mid": mb.MID, "light": mb.LIGHT, "dark": mb.DARK, "accent": mb.ACCENT},
            "lineup": [
                {"label": "Minnow juvenile, no trait", "objects": [plain]},
                {"label": "Glow, home zone (T_Trait_Glow_Fish_Emi)", "objects": [body]},
                {"label": "Glow, fallback zone (_Fallback_Emi)", "objects": [alt]},
            ],
            "lineup_caption": ["06 8.4 option B: overlay shell 0.5% outside the body, #FFE98A where lit",
                               "baked on M_Species_Base_Fish, worn by the Minnow juvenile"],
            "view_captions": {v: ["Glow home zone on the Minnow juvenile (overlay shell)"] for v in ("Side", "ThreeQuarter", "Game", "Top")},
            "extras": [
                {"title": "Glow home, game camera, deep Drop-off", "view": "Game", "objects": [body], "backdrop": "dropoff_deep",
                 "light_scale": 0.25,
                 "caption": ["preview lights at 25%; no bloom (06 rule 5); the code's PointLight is not drawn",
                             "combinations: Glow is the first trait made; no other overlay exists yet"]},
                {"title": "Glow fallback: tail tip and fin edges", "view": "ThreeQuarter", "objects": [alt],
                 "caption": ["used when a second Light trait (Moonlit, Spark, Ember) takes the home zone (06 8.3)"]},
                {"title": "The two masks on the Fish layout", "picture": picture,
                 "caption": ["%s (home) and %s, 256 x 256; outlines are the 06 5.4 regions" % (NAME, FALLBACK)]},
            ],
            "texture": "%s and %s 256 x 256, 8-bit greyscale with the mask as alpha; baked by traitbake.py on M_Species_Base_Fish"
                       % (NAME, FALLBACK),
        },
    }


def trim_lit(body, block_map, mask, frame, dark):
    """Share of the dark block on the Minnow's tail fin and fins (its painted fin trim) that the
    mask lights (0.5 or more), by surface area."""
    mesh = body.data
    mesh.calc_loop_triangles()
    uvl = mesh.uv_layers[common.UV_NAME].data
    big = block_map.shape[0]
    total = lit = 0.0
    for tri in mesh.loop_triangles:
        uv = np.array([uvl[li].uv[:] for li in tri.loops])
        cu, cv = uv.mean(0)
        if frame.texel_roles([frame.comp[tri.vertices[0]]], np.array([cu]), np.array([cv]))[0] not in ("tail", "fin"):
            continue
        pts = np.array(traitbake._SAMPLES) @ uv
        rows = np.clip((pts[:, 1] * big).astype(int), 0, big - 1)
        cols = np.clip((pts[:, 0] * big).astype(int), 0, big - 1)
        trim = block_map[rows, cols] == dark
        if not trim.any():
            continue
        on = traitbake.sample_mask(mask, pts[:, 0], pts[:, 1]) >= 0.5
        total += tri.area * float(trim.mean())
        lit += tri.area * float((trim & on).mean())
    return round(lit / max(total, 1e-9), 4)


def mid_left(body, block_map, mask, frame):
    """Share of the Minnow's visible surface that is its mid block and not lit by the overlay."""
    mesh = body.data
    mesh.calc_loop_triangles()
    uvl = mesh.uv_layers[common.UV_NAME].data
    big = block_map.shape[0]
    total = left = 0.0
    for tri in mesh.loop_triangles:
        uv = np.array([uvl[li].uv[:] for li in tri.loops])
        cu, cv = uv.mean(0)
        if frame.texel_roles([frame.comp[tri.vertices[0]]], np.array([cu]), np.array([cv]))[0] in traitbake.HIDDEN_ROLES:
            continue
        pts = np.array(traitbake._SAMPLES) @ uv
        rows = np.clip((pts[:, 1] * big).astype(int), 0, big - 1)
        cols = np.clip((pts[:, 0] * big).astype(int), 0, big - 1)
        blk = block_map[rows, cols]
        seen = blk >= 0                 # as validate counts the blocks: texels with no block (fin roots) are left out
        if not seen.any():
            continue
        lit = traitbake.sample_mask(mask, pts[:, 0], pts[:, 1]) >= 0.5
        total += tri.area * float(seen.mean())
        left += tri.area * float(((blk == 0) & ~lit & seen).mean())
    return round(left / max(total, 1e-9), 4)


if __name__ == "__main__":
    import run
    run.main(__file__)
