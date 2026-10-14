# Sprint 0 technical spike, part B: results (Mac, Studio play tests)

Measured on 14 October 2026 on the 16 GB Mac (tasks S0-C4, S0-C6, S0-C9, S0-C11). Roblox Studio was driven through
the Studio MCP by `spike/tools/drive_b.py`, which reuses part A's `drive.py`. Every hold took the machine `studio`
lock, one `heavy` slot and the worktree's `.locks/studio` (`spike/tools/held.sh`).

- **Code:**
  - `spike/src/server/SpikeB.server.luau`: the S6 prey stand-in, S7 sender, S4-under-latency and S12 server side.
  - `spike/src/client/SpikeBClient.client.luau`: the S7 checker, the S6 decoder and 80-part pool, the S3 driver and
    observer, S4 stamps and the S12 owner side.
  - `spike/src/shared/Logic/Formation.luau`: the shared member-offset hash.
  - These scripts do nothing until the driver sends a command. `drive_b.py sync` pushes them into the open place.
- **Runs:**
  - `drive_b.py play`: one single-process play test.
  - `drive_b.py mp`: two-client tests through `ExecuteMultiplayerTestAsync(2, {})`, run twice (run 1: lag 0, 0.1
    and 0.2 s; run 2: lag 0, 0.1, 0.2 and 0 again).
  - `drive_b.py s12`: on `spike/build/s12.rbxl`, built from `spike/s12.project.json` with `AuthorityMode = Server`
    and opened as a separate tab.
- **Raw numbers:** `spike/results/raw/b-*.json`.
- **Phones:** nothing here was run on a phone.
- **Latency:** Studio's network simulation was settable from script: `settings().Network.IncomingReplicationLag`,
  written through `execute_luau` in each test process, and read back. "100 ms" below means 0.1 s of *incoming* lag
  on the server and on both clients. Measured RTT: 0.033 s at 0, **0.233 s at 0.1** and **0.433 s at 0.2**. A
  movement from Player1 therefore reaches Player2 about 2 × lag late, which is harsher than a 100 ms ping.
- **Loopback:** Studio traffic is local, not Wi-Fi. No loss or jitter was simulated beyond the fixed lag.

| ID | Result | Measured | How |
|---|---|---|---|
| S6 server half | **mixed.** The simulation fits 2.0 ms (p50 0.33 ms, p99 0.41 ms). **Simulation plus interest for 24 recipients does not** (crowded p50 3.35 ms, p99 4.98 ms; spread p50 1.60 ms, p99 2.95 ms). **Bytes pass**: at most 3.36 kB/s per player against 6 kB/s. The 2.0 ms budget in 8.4 reads as the simulation only; if it is meant to include interest, this is a fail. | **Load:** 254 groups and 1,348 members (8.1 table, seeded), struct-of-arrays `buffer`s, a 64-stud grid and `--!native`. **Steps:** the threat pass over 3 × 3 cells per player, steer, integrate, leash, scatter, an 8-sample history ring, and the 700-stud active test. **Interest:** per 8.5 and 8.7, with Near, Mid and Far bands and dead reckoning, full records for new groups (sent twice), 2 s keyframes, deltas over threshold, priority order and a 900-byte cap. It is spread over 6 frames (4 players per frame). **Two 20 s scenarios:** *crowded* (24 recipients and every home volume inside 700 × 700 studs, 12 Near groups per player at p50 and 26 at most) and *spread* (the whole 2,048 map, 1 Near group at p50). **Bytes per player per second, mean / max:** crowded 3,267 / 3,359; spread 838 / 1,019. That is 9.9 and 8.2 packets per second, at about 330 bytes per packet in the crowded case. Keyframes dominate: 2,953 full against 887 delta records per second. The worst single server frame was 1.37 ms. | **Recipients:** 23 *simulated* bots (they wander at 30 studs/s, encode the real packet and count bytes, but nothing is sent) plus **1 real client**, Player 1. The real client's root sets slot 1's position, and it receives that slot's actual `PreyState` packets. **The real client's stream:** 199 packets in the crowded scenario (the client counted 215 over its slightly longer window), 0 sequence gaps, 0 unknown deltas. Its bytes per second agree with the server's count (3,355 sent, 3,536 counted on the client). **Timing:** `os.clock` on the server Heartbeat. The server shares one Studio process with the client. |
| S6 Mac client half | **pass (Mac)**; phone: not run | **Frame time with 80 pooled parts moved by one `BulkMoveTo` (FireCFrameChanged) per frame:** mean 16.66 ms, p99 17.73 ms, max 20.8 ms (60 fps, vsync-capped). **Draw step** (decode bookkeeping, sorting groups by distance, Formation offsets, building 80 CFrames, `BulkMoveTo`): p50 0.69 ms, p99 1.13 ms when crowded; p50 0.47 ms when spread. In the crowded scenario, all 80 parts were members of real groups decoded from the packets (p50 80). | Studio was brought to the front first (part A surprise 6). The parts are anchored, with CanCollide, CanTouch, CanQuery and CastShadow off. The drawn position eases toward the dead-reckoned target with τ = 0.1 s (8.8). |
| S7 | **pass** in Studio: intact, 0% loss. Loss on Wi-Fi: **not run** | **900-byte `buffer`s** through `UnreliableRemoteEvent`: **400/400 at 20 Hz and 300/300 at 60 Hz arrived intact.** Every byte was checked against a regenerated pseudo-random payload: 0 corrupt, 0 duplicates, 0 reordered. A size sweep under 0.2 s lag (two-client test) delivered 10/10 at 950, 970, 980, 985, 990 and 995 bytes. **A payload of 999 bytes or more is dropped every time (0/10 at 999, 0/50 at 1,000, 0/50 at 1,200, 0/20 at 8,000), with no error or warning on either side.** **Bytes on the wire:** server `Stats.DataSendKbps` plateau 19.15 at 20 × 900 B/s and 55.9 at 60 × 900 B/s, about 930–980 bytes per 900-byte payload (overhead 30–80 B, depending on whether a "k" is 1,000 or 1,024). The client's `Stats.DataReceiveKbps` reads 0 throughout in Studio, so it is useless here. | `drive_b.py play` (phases 1–5) and `drive_b.py mp` (sweep). The payload is a seq/phase/size header followed by LCG bytes, verified on the client. |
| S3 (Mac, two Studio clients) | **pass by the pop metric** at 0, 100 and 200 ms, with **one finding** (the rig trails the root). The first 0 ms segment of each run was invalid; it was repeated. | **Largest rig "pop":** cruise 0.023–0.056 studs (limit 2), dash 0.10–0.20 studs (limit 4). A pop here is the largest per-frame deviation of the rig's step from its own previous-frame velocity. **Without the spring, the raw replicated root pops** up to 0.84 studs in cruise and **7.3–10.4 studs per frame during dashes**, at every lag *including 0*. Its apparent speed reaches 590–850 studs/s at dash onset: the engine overshoots, then corrects. **Finding:** a critically damped spring toward a moving target trails it by 2τv. That is **6.1–6.4 studs behind the replicated root at 38 studs/s and 12.5–13 studs during a dash** (τ = 0.08). The spring removes pops by converting them into lag. Feed-forward (spring toward root + velocity × 2τ) or springing the *offset* to zero would remove the trail; this needs a design decision in 6.7. | **Player1:** circles R = 60 at 38 studs/s, then dashes 2.2× for 0.35 s every 2.5 s, set by `LinearVelocity` at RenderStep Input+2. **Player2:** on `PreRender`, `springStep` per 6.7 (ω = 1/τ, exact critically damped), 1,199 frames per 20 s segment at 60 fps. The first 0 ms segment in both runs saw Player1 almost static (22 and 7 moving frames out of 1,199; cause not found, it was the first segment after the clients joined). The final 0 ms segment of run 2 is the valid one. **Player1's window was throttled to 15 fps** (211 RenderSteps in 14 s), so the driver set its velocity at 15 Hz. Physics ran normally. |
| S4 under latency | **pass** at 0, 100 and 200 ms (Mac Studio) | **Arrival** of the server's `root.CFrame` write on the owner (Player1 swimming the circle at 38 studs/s), 6 writes per lag per run, 42 in total over both runs. 0 ms: **0.028–0.063 s**. 100 ms: **0.108–0.173 s**. 200 ms: **0.212–0.272 s** (limit 0.3 s). In 12 of the 42 writes (both runs) no exact time was taken. In run 2, which logged the closest approach, the first rendered frame after the snap in those cases was already 2.5–2.7 studs past the target (4 frames of travel at 38 studs/s). All 24 run-2 writes reached the target within 2.7 studs, in step with the server's reliable message (0.11–0.14 s at 100 ms, 0.21–0.25 s at 200 ms). Run 1 did not log the closest approach, so its 4 untimed writes are unconfirmed. **Freeze:** `SetNetworkOwner(nil)` plus `Anchored` gave 0.000 studs of server drift over 2 s at every lag, while the client kept pushing. | `SpikeB` `s4lag`; the client keeps a 400-frame ring of (GetServerTimeNow, position) and finds the first sample within 2.5 studs of each target. At 200 ms the margin to 0.3 s is only about 30 ms. |
| S12 | **fail as run; not conclusive.** Time-box used (about 8 turns). | **Setting it:** `Workspace.AuthorityMode` cannot be read by plugin *or game* scripts ("lacking capability RobloxScript"). Rojo 7.7.1 accepts `"AuthorityMode": "Server"` in the project file. The only evidence that it took effect is indirect: see surprise 3, and the resimulation count below. **Binding:** `RunService:BindToSimulation(fn)` binds without error on server and client. **Owner prediction** (own root driven in BindToSimulation at 38 studs/s, dashing): the owner's rendered root showed **corrections up to 66 studs per frame at 0 ms and 68 at 100 ms**, p99 3.8 and 8.4 studs. The simulation callback ran 527 times in 12 s at 0 ms but **2,232 times at 100 ms**, which reads as rollback and resimulation. **Caveat:** the input came from `os.clock()`, not from the simulated tick, so replayed ticks saw different input. The visible rollbacks may be self-inflicted. A fair retry needs tick-indexed input. **Server with 24 server-owned bot roots** driven in BindToSimulation: callback 0.13 ms p50 (0.45 ms p99); `Stats.PhysicsStepTimeMs` p50 0.9–1.0 ms, max 1.25 ms; HeartbeatTimeMs 0.05 ms. That is under 4 ms, but the bots are one-process Studio parts, not players. | `spike/s12.project.json` and `drive_b.py s12` (single play test, lag 0 then 0.1). The design does not depend on S12 (canon 14). R2's fallback stays **closed** until a fair retry is run. |
| S0-C11 memory | **measured** | **Spike Studio idle**, Edit mode with the place open: RSS 1.1–1.4 GB, physical footprint (vmmap) 3.1 GB. **During a play test:** RSS 2.17 GB, footprint 3.6 GB; the peak footprint was 3.9 GB over the session. **During the two-client test:** the editor process stays at 3.1 GB, plus the server process at 2.0–2.1 GB and two client processes at 2.0–2.1 GB each, so about **9.3 GB footprint for the editor and test**. RSS was only 2.5 GB, because macOS compressed memory under pressure: another agent's Studio (4.2 GB footprint) was also open. The test took 14.5 s to start, and `EndTest("…")` on the server ended all three processes. **Blender peak** (art spike, `spike/results/art-blender.md` on main): 385–390 MB. | `ps -o rss` and `vmmap --summary` (Physical footprint) on every `RobloxStudio` pid, in `drive_b.studio_mem()`. **Implication for the 16 GB Mac:** two-client tests cost about 6 GB of footprint on top of an open Studio, so they must not overlap another two-client test or a second agent's Studio. |

## Surprises (behaviour that differs from what chapter 09 assumes or leaves open)

1. **The `UnreliableRemoteEvent` cap is below 1,000 bytes, and the drop is silent.** Payloads of 995 bytes arrived;
   999, 1,000, 1,200 and 8,000 were dropped 100% of the time with no error on either side. The 900-byte
   `PreyState` cap (8.6) is safe, but any packet that grows past about 996 bytes vanishes rather than "risks being
   dropped". The codec should assert `size ≤ 900`.
2. **`IncomingReplicationLag` is settable from script** (`settings().Network.IncomingReplicationLag`) in each
   test process through `execute_luau`, and it shows in RTT. S3 and S4 under latency need no human. It applies per
   process, so set the server and every client, and state the resulting RTT.
3. **A place built with `AuthorityMode = Server` caps string attributes at 50 characters at run time.** Part A's
   `SetAttribute(key, json)` reporting failed with "Attribute string value exceeds 50 character limit" and killed
   the server script. The same 60-character write works in Edit in both places and at run time in the normal place.
   The spike scripts now fall back to `StringValue` children. If Server Authority is ever adopted, every
   long-string attribute in the design (for example JSON in attributes) must be reviewed.
4. **`AuthorityMode` is unreadable from game scripts**, as well as from plugins, so code cannot assert which mode
   it runs in.
5. **The engine's replicated position of a client-owned root pops 7–10 studs per frame at a dash onset, even at
   0 ms lag**, with an apparent speed of 590–850 studs/s. The 6.7 spring hides it, but anything that reads
   `root.Position` raw (bite reach on clients, outlines, UI anchors) will see these jumps.
6. **The 6.7 spring trails by 2τv:** 6 studs at 38 studs/s and 13 during a dash. That is a visible offset between
   the drawn rig and the collision ball or bite position of other players. Use feed-forward or spring the offset.
7. **`ExecuteMultiplayerTestAsync`'s `EndTest` needs an argument.** `EndTest()` raises "Argument 1 missing or nil".
   `EndTest("done")` on the server instance ends all three processes, and SIGTERM does not. In run 1 the three
   processes outlived SIGTERM until a follow-up `EndTest("…")`.
8. **Background Studio test clients run at 15 fps** (the Player1 window). Frame-time numbers from two-client tests
   are only valid for the window in front.
9. **The interest pass, not the simulation, is the S6 cost.** Interest across 24 recipients (about 0.13 ms per
   recipient when crowded, because keyframes every 2 s for about 250 known groups dominate) is 90% of the tick.
   Options: let the 2.0 ms budget cover the simulation only and give interest its own budget (about 0.6 ms per
   frame); stagger keyframes; or shrink the keyframe set to Near and Mid. Full records (mostly keyframes) are also 77% of records
   and about 85% of record bytes when crowded.
10. **`Stats.DataReceiveKbps` reads 0 on a Studio client.** Server `DataSendKbps` works. On-wire bytes for U2 can
    only be estimated from the server side in Studio.

## Not run, or left for others

- **Phone:** S6's 80-prey draw at 30 fps on a low-end phone, and all phone fps.
- **Wi-Fi loss for S7:** loopback only.
- **S12 retry** with tick-indexed input, and confirmation that the mode really is Server.
- **Real bots for S6:** 23 of the 24 recipients were simulated.
- **Engine replication bytes of other creatures (U2):** not measured.

## Housekeeping

The spike place is open in Studio (`TestBench-gulp-spike.rbxl`) and idle in Edit mode. Its Edit data model now
also holds the part B scripts (synced, never saved). The S12 tab (`TestBench-gulp-spike-s12`) was opened and then
closed again, and no two-client test processes are left. `IncomingReplicationLag` was reset to 0 in every test
process; Edit read 0 before and after. All locks are released.
