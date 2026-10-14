# Art spike S0-A7: agent art trial (Minnow juvenile)

Measured 2026-10-14 with Blender 5.2.2 LTS, headless. One builder agent (Opus) took
`M_Species_Minnow_Juv` on `RIG_Fish` from black silhouette to a script-painted texture through
`assets/source/species/minnow/build.py`. A separate art-director reviewer judged each contact sheet.
Rebuild with:

    tools/with-heavy.sh --owner gulp-a7 --game Gulp -- /Applications/Blender.app/Contents/MacOS/Blender \
      --background --python assets/source/species/minnow/build.py

Outputs, none committed: the sheet `assets/review/M_Species_Minnow_Juv/<date>_sheet.png`, the versions
sheet, the report JSON, the raw view renders in `renders/`, and the files in `assets/export/meshes/` and
`assets/export/textures/` (`T_Minnow_Juv_Alb`, `T_Shared_Rgh`, `T_Shared_RghWet`, `T_Shared_RghChalk`).

## Result

The trial result is **no pass within the three-loop limit**. The reviewer's third review failed on
the face. Three extra loops, beyond the limit, followed to see whether the agent could reach a pass.
After extra loop 3 the sheet goes to the owner for sign-off with no further agent review.

Final state (commit d8aae06):
- **Validation:** PASS, 179 checks, 0 failed, 3 waived.
- **Triangles:** body 1,476 of 1,500; LOD1 and LOD2 at half and a quarter.
- **Shells:** within budget.
- **Rig:** 18 deform bones and 10 sockets.
- **Texture:** 256 x 256 colour map at 123 px/stud; 8 x 8 shared roughness maps.

## Effort log

Turns are the builder agent's tool calls in each loop. Seconds were measured with `date` from the
loop's first command to the end of its last build. They seem to leave out most of the model's
thinking time between commands, so they understate wall time. Treat the turn counts as the more
reliable effort figure.

| Round | Within the 3-loop trial? | Turns | Seconds | What it did |
|---|---|---|---|---|
| Initial build | yes | about 29 | 753 | Read the bible, wrote build.py: shape, family rig fit, UVs, scripted paint, occlusion bake. Added texture-based value checks and texture export to the shared pipeline. 7 Blender runs. |
| Loop 1 | yes | 7 | 135 | Repainted for "muddy" colour: violet shadows and occlusion, rust only on ridge and fin edges, yellow tail, cream belly, bigger smile, rounder fins. **Dominated by the shared preview-lighting bug**: the texture was already right; the sheet's lighting made it look brown. |
| Loop 2 | yes | 8 | 184 | **Found and fixed the shared preview-lighting bug** in `template.py`. The key light came from straight above and the ambient was blue at 0.35, so a flank showed about 0.2 of its albedo plus blue. Rendered pixels now match the palette hue (flank `#F49748` vs `#FF9A3D`). Also: pectoral fan, smile, lid, head crease. |
| Extra loop 1 | **beyond the limit** | 4 | 77 | Face: smile moved to the side of the head, brow wedge removed, eyes +20%, snout-tip streak removed, larger fins. |
| Extra loop 2 | **beyond the limit** | 4 | 56 | Longer, bolder smile with a lip line; eyes +22% with 16 segments; taller dorsal; pectoral fitted to width and depth. |
| Extra loop 3 | **beyond the limit** | 4 | 17 | Dorsal about 1.5 times taller above the back; smile 25% longer with a cream `#FFE2A8` lip line. |

Total: about 56 turns. Within the trial limit: about 44 turns, 1,072 s. Beyond it: 12 turns, 150 s.

## Findings for the owner

1. **Bible conflicts, logged as waivers in build.py:**
   - The Minnow dark `#C2491D` is L* 47, but 06 4.1 requires a dark block of L* 35 or less.
   - A wholly yellow tail is 8% accent, but 06 4.1 caps accent at 5%. The tail follows 03's yellow-tail ID mark.
2. **Proportions vs size:** 06 3.3 asks for body depth at 55% of body length. That cannot be met within the 3.0 x 1.1 size of 06 6.2 with 03's short round tail. The final body is about 40% deep, because the back was lowered so the dorsal fin clears it within 1.1 studs. The eyes were enlarged well past the 34% row at the reviewer's request.
3. **Review lighting:** the shared preview lighting was wrong for every asset until loop 2. Earlier sheets of other assets (the capsule fish) were lit the same way.
4. **48-pixel mouth check (side view):** the mouth pixel is luma 55, against 192 for the cheek and 206 for the chin.
