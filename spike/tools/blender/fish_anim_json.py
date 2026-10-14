"""Spike part D (S0-A2/S8, S0-A2 sockets). Run headless on the built fish file:
  Blender --background assets/source/families/fish/fish.blend --python spike/tools/blender/fish_anim_json.py -- <outdir>
1. Writes <outdir>/A_Fish_Swim.json: per bone its parent, armature-space rest matrix, and per frame the local
   pose (matrix_basis: location + quaternion wxyz, bone-local) and the armature-space head position.
2. Writes <outdir>/M_Fish_SockW.fbx: the body on RIG_Fish with every socket bone made deforming and given a tiny
   skin weight on one nearby vertex (tiers 0.001 / 0.004 / 0.01 / 0.02 / 0.05) to see which survive Roblox import.
Nothing in assets/ is written."""
import json, os, sys
import bpy

out = sys.argv[sys.argv.index("--") + 1]
os.makedirs(out, exist_ok=True)
sys.path.insert(0, os.path.join(os.path.dirname(bpy.data.filepath), "..", "..", "_shared", "blender"))
import export  # noqa: E402

arm = bpy.data.objects["RIG_Fish"]
act = bpy.data.actions["A_Fish_Swim"]
arm.animation_data_create()
arm.animation_data.action = act
sc = bpy.context.scene
f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
mw = arm.matrix_world
bones = {}
for b in arm.data.bones:
    bones[b.name] = {"parent": b.parent.name if b.parent else None, "deform": b.use_deform,
                     "rest": [list(r) for r in b.matrix_local], "frames": []}
for f in range(f0, f1 + 1):
    sc.frame_set(f)
    for pb in arm.pose.bones:
        mb = pb.matrix_basis
        q = mb.to_quaternion()
        head = mw @ pb.head
        bones[pb.name]["frames"].append({"loc": list(mb.to_translation()), "q": [q.w, q.x, q.y, q.z], "head": list(head)})
data = {"clip": act.name, "fps": sc.render.fps, "start": f0, "end": f1, "armatureWorld": [list(r) for r in mw], "bones": bones}
with open(os.path.join(out, "A_Fish_Swim.json"), "w") as fh:
    json.dump(data, fh)
print("JSON bones", len(bones), "frames", f1 - f0 + 1, "fps", sc.render.fps)

# ---- socket weight variant
arm.animation_data.action = None
for pb in arm.pose.bones:
    pb.matrix_basis.identity()
arm.data.pose_position = "REST"
body = bpy.data.objects["M_Species_Base_Fish"]
TIERS = {"Sock_Crest": 0.001, "Sock_Back_01": 0.001, "Sock_Back_02": 0.004, "Sock_Back_03": 0.004,
         "Sock_Flank_L": 0.01, "Sock_Flank_R": 0.01, "Sock_Head": 0.02, "Sock_Tail": 0.02,
         "Sock_FinDorsal": 0.05, "Sock_FinTail": 0.05}
used = set()
inv = body.matrix_world.inverted()
for name, w in TIERS.items():
    bone = arm.data.bones[name]
    bone.use_deform = True
    head = inv @ (mw @ bone.head_local)
    best, bd = None, 1e9
    for v in body.data.vertices:
        if v.index in used or len([g for g in v.groups if g.weight > 0]) >= 4:
            continue
        d = (v.co - head).length
        if d < bd:
            best, bd = v, d
    used.add(best.index)
    vg = body.vertex_groups.get(name) or body.vertex_groups.new(name=name)
    vg.add([best.index], w, "REPLACE")
    print("sock", name, "w", w, "vertex", best.index, "dist %.3f" % bd)
bpy.ops.object.select_all(action="DESELECT")
for o in (body, arm):
    o.select_set(True)
bpy.context.view_layer.objects.active = arm
known = set(bpy.ops.export_scene.fbx.get_rna_type().properties.keys())
st = {k: v for k, v in export.BASE_SETTINGS.items() if k in known}
path = os.path.join(out, "M_Fish_SockW.fbx")
print("export", bpy.ops.export_scene.fbx(filepath=path, **st), os.path.getsize(path))
