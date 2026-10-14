#!/usr/bin/env python3
"""Unit tests of upload.py against a mocked Open Cloud: no request leaves the machine.

    python3 assets/source/_shared/pipeline/test_upload.py
"""
import contextlib
import json
import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import upload  # noqa: E402

KEY = "test-key-SECRET-123"
ROWS = ["M_Prop_EyeX,MVP,not started,,yes,", "T_Shared_Rgh,MVP,in progress,,yes,", "SFX_Gulp,MVP,not started,,yes,",
        "A_Fish_Swim,MVP,not started,,yes,", "A_Fish_Bite,MVP,not started,,yes,", "FX_BiteChomp,MVP,not started,,yes,",
        "MUS_Reef,MVP,done,,no,"]


class FakeCloud:
    def __init__(self, fail_first_with_429=False):
        self.calls, self.next_id, self.ops = [], 1000, {}
        self.throttle = fail_first_with_429

    def __call__(self, method, url, body=None, headers=None, timeout=300):
        self.calls.append((method, url, body, dict(headers or {})))
        assert headers.get("x-api-key") == KEY
        if method == "POST":
            if self.throttle:
                self.throttle = False
                return 429, b"slow down", {"Retry-After": "3"}
            self.next_id += 1
            op = "operations/op%d" % self.next_id
            self.ops[op] = {"polls": 0, "id": self.next_id}
            return 200, json.dumps({"path": op, "done": False}).encode(), {}
        op = url.split("/assets/v1/")[1]
        self.ops[op]["polls"] += 1
        if self.ops[op]["polls"] < 2:
            return 200, json.dumps({"path": op, "done": False}).encode(), {}
        return 200, json.dumps({"path": op, "done": True, "response": {
            "assetId": str(self.ops[op]["id"]), "moderationResult": {"moderationState": "Approved"}}}).encode(), {}


class UploadTest(unittest.TestCase):
    def setUp(self):
        self.repo = tempfile.mkdtemp(prefix="gulp_upload_test_")
        a = os.path.join(self.repo, "assets")
        for d in ("export/meshes", "export/textures", "export/audio/sfx", "export/audio/music", "export/animations", "placeholder/audio/sfx"):
            os.makedirs(os.path.join(a, d))
        with open(os.path.join(a, "manifest.csv"), "w") as f:
            f.write("name,tag,status,asset_id,placeholder,note\n" + "\n".join(ROWS) + "\n")
        self.write("export/meshes/M_Prop_EyeX.fbx", b"FBX-mesh")
        self.write("export/textures/T_Shared_Rgh.png", b"PNG")
        self.write("export/audio/music/MUS_Reef.ogg", b"OggS-music")
        self.write("placeholder/audio/sfx/SFX_Gulp.ogg", b"OggS-ph")
        self.write("export/animations/A_Fish_Swim.fbx", b"FBX-anim")
        self.write("export/animations/A_Fish_Bite.rbxm", b"<roblox!anim")
        with open(os.path.join(a, "upload_target.json"), "w") as f:
            json.dump({"creator": {"userId": "42"}}, f)
        self.cloud, self.sets, self.slept, self.logs, self.locks = FakeCloud(), [], [], [], []
        self.now = [0.0]

    def tearDown(self):
        shutil.rmtree(self.repo)

    def write(self, rel, data):
        with open(os.path.join(self.repo, "assets", rel), "wb") as f:
            f.write(data)

    @contextlib.contextmanager
    def fake_lock(self, repo):
        self.locks.append("held")
        yield

    def uploader(self, **kw):
        def sleep(s):
            self.slept.append(s)
            self.now[0] += s
        return upload.Uploader(repo=self.repo, http=self.cloud, sleep=sleep, clock=lambda: self.now[0],
                               set_manifest=lambda repo, name, fields: self.sets.append((name, fields)),
                               lock=self.fake_lock, key=lambda: KEY, log=self.logs.append, **kw)

    def test_dry_run_sends_nothing(self):
        up = self.uploader()
        out = up.run(up.batch_names(placeholders=True), dry_run=True, placeholders=True)
        self.assertEqual(self.cloud.calls, [])
        self.assertEqual(self.sets, [])
        self.assertEqual(self.locks, [])
        self.assertEqual(sorted(p["name"] for p in out["planned"]), sorted(["A_Fish_Bite", "M_Prop_EyeX", "MUS_Reef", "SFX_Gulp", "T_Shared_Rgh"]))
        self.assertTrue(any("A_Fish_Swim" in why and ".rbxm" in why for _, why in out["refused"]))
        self.assertFalse(os.path.exists(os.path.join(self.repo, "assets", "uploads.json")))

    def test_types_and_request_shape(self):
        up = self.uploader()
        up.run(["M_Prop_EyeX", "T_Shared_Rgh", "A_Fish_Bite", "MUS_Reef"], dry_run=False)
        posts = [c for c in self.cloud.calls if c[0] == "POST"]
        self.assertEqual(len(posts), 4)
        for (_, url, body, headers), (atype, mime) in zip(posts, [("Model", b"model/fbx"), ("Image", b"image/png"),
                                                                 ("Animation", b"model/x-rbxm"), ("Audio", b"audio/ogg")]):
            self.assertEqual(url, "https://apis.roblox.com/assets/v1/assets")
            self.assertIn(b'"assetType": "%s"' % atype.encode(), body)
            self.assertIn(b'"creator": {"userId": "42"}', body)
            self.assertIn(b"Content-Type: " + mime, body)
            self.assertTrue(headers["Content-Type"].startswith("multipart/form-data; boundary="))
        self.assertEqual(self.locks, ["held"])

    def test_manifest_and_state_written(self):
        up = self.uploader()
        up.run(["M_Prop_EyeX", "MUS_Reef"], dry_run=False)
        self.assertEqual(self.sets[0], ("M_Prop_EyeX", {"asset_id": "1001", "placeholder": "no", "status": "in review"}))
        self.assertEqual(self.sets[1], ("MUS_Reef", {"asset_id": "1002", "placeholder": "no"}))   # done stays done
        state = up.state()
        self.assertEqual(state["M_Prop_EyeX"]["asset_id"], 1001)
        self.assertEqual(state["M_Prop_EyeX"]["moderation"], "Approved")
        self.assertEqual(len(state["M_Prop_EyeX"]["sha256"]), 64)

    def test_placeholder_keeps_flag(self):
        up = self.uploader()
        up.run(["SFX_Gulp"], dry_run=False, placeholders=True)
        self.assertEqual(self.sets, [("SFX_Gulp", {"asset_id": "1001"})])
        self.assertTrue(up.state()["SFX_Gulp"]["placeholder"])

    def test_idempotent_and_changed_file(self):
        up = self.uploader()
        up.run(["M_Prop_EyeX"], dry_run=False)
        posts = lambda: len([c for c in self.cloud.calls if c[0] == "POST"])  # noqa: E731
        self.assertEqual(posts(), 1)
        up.run(["M_Prop_EyeX"], dry_run=False)               # same bytes: no request
        self.assertEqual(posts(), 1)
        self.write("export/meshes/M_Prop_EyeX.fbx", b"FBX-mesh-v2")
        up.run(["M_Prop_EyeX"], dry_run=False)
        self.assertEqual(posts(), 2)
        self.assertEqual(up.state()["M_Prop_EyeX"]["asset_id"], 1002)

    def test_rate_limit_and_429(self):
        self.cloud.throttle = True
        up = self.uploader(interval=5.0)
        up.run(["M_Prop_EyeX", "T_Shared_Rgh"], dry_run=False)
        self.assertIn(3.0, self.slept)                       # Retry-After honoured
        posts = [i for i, c in enumerate(self.cloud.calls) if c[0] == "POST"]
        self.assertEqual(len(posts), 3)
        self.assertTrue(self.now[0] >= 5.0)

    def test_no_owner_decision_no_upload(self):
        os.remove(os.path.join(self.repo, "assets", "upload_target.json"))
        up = self.uploader()
        with self.assertRaises(upload.Refused) as ctx:
            up.run(["M_Prop_EyeX"], dry_run=False)
        self.assertIn("D11", str(ctx.exception))
        self.assertEqual(self.cloud.calls, [])

    def test_key_never_logged(self):
        def failing(method, url, body=None, headers=None, timeout=300):
            return 401, ("bad key " + KEY).encode(), {}
        up = self.uploader()
        up.http = failing
        with self.assertRaises(RuntimeError) as ctx:
            up.run(["M_Prop_EyeX"], dry_run=False)
        self.assertNotIn(KEY, str(ctx.exception))
        self.assertFalse(any(KEY in line for line in self.logs))

    def test_settings_rows_refused(self):
        with self.assertRaises(upload.Refused):
            upload.kind("FX_BiteChomp")


if __name__ == "__main__":
    unittest.main(verbosity=1)
