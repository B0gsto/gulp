#!/usr/bin/env python3
"""Upload and manifest routine (docs/07-asset-list.md section 14.1: "Upload a file, record its
asset ID and status in manifest.csv, swap out the placeholder"; sections 1.3, 1.5 and 12).

    python3 assets/source/_shared/pipeline/upload.py row <Name> [--dry-run] [--decal]
    python3 assets/source/_shared/pipeline/upload.py batch [--prefix M_] [--limit N] [--live] [--placeholders]
    python3 assets/source/_shared/pipeline/upload.py show <Name>

A batch is a dry run unless --live is given; a row uploads unless --dry-run is given. A live run
also needs assets/upload_target.json ({"creator": {"userId": "..."}} or {"creator": {"groupId": "..."}}):
who owns GULP's assets is the owner's open decision D11 (docs/14), so until that file exists every
live run stops before any request.

What goes up, through Open Cloud Create Asset (POST https://apis.roblox.com/assets/v1/assets,
https://create.roblox.com/docs/cloud/guides/usage-assets):
  M_*.fbx          assetType Model (model/fbx): Roblox imports it as a Model of MeshParts. The API's
                   "Mesh" type takes only mesh data downloaded from Roblox, never an FBX.
  T_*.png          assetType Image (or Decal with --decal)
  SFX_*/MUS_*.ogg  assetType Audio (audio/ogg)
  A_*.rbxm/.rbxmx  assetType Animation. The API takes animations only as .rbxm/.rbxmx saved by
                   Studio, so an A_*.fbx from the clip tools is refused: import it in Studio first.
  FX_, LGT_, SKY_  never uploaded (Data/Manifest: settings read by name, no asset ID)
The file comes from assets/export/ (07 1.3); with --placeholders, a row that has no export uses its
stand-in from assets/placeholder/ and stays marked placeholder.

Each upload polls its operation (GET /assets/v1/operations/{id}) until done, then writes the asset
ID into assets/manifest.csv through `lune run tools/gen/manifest -- set ...` (same parser, same
format; it also regenerates src/shared/Config/AssetManifest.luau). A real export also clears the
placeholder flag and moves the status to `in review` (07 1.5; `done` is left alone). The file's
sha256 and the result are kept in assets/uploads.json: a row whose file hash matches its last
upload is skipped (idempotent). POSTs are spaced by --interval seconds (default 2.0); a 429 waits
for Retry-After. Live runs hold the machine lock `assets.Gulp` (tools/locks.py above the repo).
The API key comes from $ROBLOX_API_KEY, else ~/RobloxProjects/.roblox-api-key; it is never printed.
"""
import argparse
import datetime
import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))
API = "https://apis.roblox.com"
KEY_FILE = os.path.expanduser("~/RobloxProjects/.roblox-api-key")
LOCK_NAME = "assets.Gulp"
MIME = {".fbx": "model/fbx", ".png": "image/png", ".ogg": "audio/ogg", ".rbxm": "model/x-rbxm", ".rbxmx": "model/x-rbxm"}
NO_ID_PREFIXES = ("FX_", "LGT_", "SKY_")


class Refused(Exception):
    pass


def kind(name, decal=False):
    """(export subfolder, [extensions], assetType) for a manifest name."""
    if name.startswith("M_"):
        return "meshes", [".fbx"], "Model"
    if name.startswith("T_"):
        return "textures", [".png"], "Decal" if decal else "Image"
    if name.startswith("SFX_"):
        return os.path.join("audio", "sfx"), [".ogg"], "Audio"
    if name.startswith("MUS_"):
        return os.path.join("audio", "music"), [".ogg"], "Audio"
    if name.startswith("A_"):
        return "animations", [".rbxm", ".rbxmx"], "Animation"
    if name.startswith(NO_ID_PREFIXES):
        raise Refused("%s: settings read by name, never uploaded (no asset ID)" % name)
    raise Refused("%s: not an asset name this routine knows" % name)


def read_key():
    key = os.environ.get("ROBLOX_API_KEY", "").strip()
    if not key and os.path.isfile(KEY_FILE):
        with open(KEY_FILE) as f:
            key = f.read().strip()
    if not key:
        raise Refused("no API key: set ROBLOX_API_KEY or create ~/RobloxProjects/.roblox-api-key")
    return key


def urllib_http(method, url, body=None, headers=None, timeout=300):
    req = urllib.request.Request(url, data=body, method=method, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read(), dict(r.headers)
    except urllib.error.HTTPError as e:
        return e.code, e.read(), dict(e.headers or {})


def multipart(fields, files):
    b = uuid.uuid4().hex
    out = bytearray()
    for n, v in fields.items():
        out += ('--%s\r\nContent-Disposition: form-data; name="%s"\r\n\r\n%s\r\n' % (b, n, v)).encode()
    for n, (fn, ct, blob) in files.items():
        out += ('--%s\r\nContent-Disposition: form-data; name="%s"; filename="%s"\r\nContent-Type: %s\r\n\r\n'
                % (b, n, fn, ct)).encode() + blob + b"\r\n"
    out += ("--%s--\r\n" % b).encode()
    return bytes(out), "multipart/form-data; boundary=" + b


def lune_set(repo, name, fields):
    """The existing manifest tooling writes the row and regenerates the runtime module."""
    env = dict(os.environ, PATH=os.path.expanduser("~/.rokit/bin") + os.pathsep + os.environ.get("PATH", ""))
    args = ["lune", "run", "tools/gen/manifest", "--", "set", name] + ["%s=%s" % kv for kv in sorted(fields.items())]
    done = subprocess.run(args, cwd=repo, capture_output=True, text=True, env=env)
    if done.returncode != 0:
        raise RuntimeError("manifest set %s failed: %s" % (name, (done.stdout + done.stderr)[-400:]))


def machine_lock(repo):
    d = os.path.dirname(repo)
    while d != os.path.dirname(d):
        if os.path.isfile(os.path.join(d, "tools", "locks.py")):
            sys.path.insert(0, os.path.join(d, "tools"))
            import locks
            return locks.Lock(LOCK_NAME, owner="gulp upload", game="Gulp")
        d = os.path.dirname(d)
    raise Refused("tools/locks.py not found above the repo: no lock, no live upload")


class Uploader:
    def __init__(self, repo=REPO, http=urllib_http, sleep=time.sleep, clock=time.monotonic, set_manifest=lune_set,
                 lock=machine_lock, key=read_key, interval=2.0, log=print, poll_limit=120):
        self.repo, self.http, self.sleep, self.clock = repo, http, sleep, clock
        self.set_manifest, self.lock, self.key, self.interval, self.log = set_manifest, lock, key, interval, log
        self.poll_limit = poll_limit
        self.state_path = os.path.join(repo, "assets", "uploads.json")
        self.last_post = None

    # -------------------------------------------------------------- state and inputs
    def state(self):
        if not os.path.isfile(self.state_path):
            return {}
        with open(self.state_path, encoding="utf-8") as f:
            return json.load(f)

    def save_state(self, state):
        tmp = self.state_path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(state, f, indent=1, sort_keys=True)
            f.write("\n")
        os.replace(tmp, self.state_path)

    def manifest(self):
        import csv
        with open(os.path.join(self.repo, "assets", "manifest.csv"), newline="", encoding="utf-8") as f:
            return {r["name"]: r for r in csv.DictReader(f)}

    def creator(self):
        path = os.path.join(self.repo, "assets", "upload_target.json")
        if not os.path.isfile(path):
            raise Refused("no assets/upload_target.json: who owns GULP's assets is open (owner decision D11, "
                          "docs/14), so nothing is uploaded; dry runs still work")
        with open(path) as f:
            c = json.load(f).get("creator", {})
        for k in ("userId", "groupId"):
            if str(c.get(k, "")).isdigit():
                return {k: str(c[k])}
        raise Refused("assets/upload_target.json: creator must hold a numeric userId or groupId")

    def locate(self, name, decal=False, placeholders=False):
        folder, exts, asset_type = kind(name, decal)
        for root, is_ph in (("export", False), ("placeholder", True)):
            if is_ph and not placeholders:
                break
            for ext in exts:
                path = os.path.join(self.repo, "assets", root, folder, name + ext)
                if os.path.isfile(path):
                    return path, asset_type, is_ph
        if asset_type == "Animation" and os.path.isfile(os.path.join(self.repo, "assets", "export", folder, name + ".fbx")):
            raise Refused("%s: Open Cloud takes animations only as .rbxm/.rbxmx saved by Studio; import "
                          "animations/%s.fbx in Studio and save it as %s.rbxm" % (name, name, name))
        raise Refused("%s: no file in assets/export/%s/%s" % (name, folder, "" if not placeholders else " or assets/placeholder/"))

    # -------------------------------------------------------------- one row
    def plan(self, name, decal=False, placeholders=False):
        rows = self.manifest()
        if name not in rows:
            raise Refused("%s is not a row of assets/manifest.csv" % name)
        path, asset_type, is_ph = self.locate(name, decal, placeholders)
        with open(path, "rb") as f:
            blob = f.read()
        if len(blob) > 20 * 1024 * 1024:
            raise Refused("%s: %d bytes, over the API's 20 MB per file" % (name, len(blob)))
        sha = hashlib.sha256(blob).hexdigest()
        last = self.state().get(name, {})
        same = last.get("sha256") == sha and last.get("asset_type") == asset_type and last.get("asset_id")
        return {"name": name, "path": path, "blob": blob, "sha256": sha, "asset_type": asset_type, "placeholder": is_ph,
                "row": rows[name], "skip": bool(same), "last": last}

    def manifest_fields(self, p, asset_id):
        fields = {"asset_id": str(asset_id)}
        if not p["placeholder"]:
            fields["placeholder"] = "no"
            if p["row"]["status"] != "done":
                fields["status"] = "in review"
        return fields

    def upload_one(self, p, creator, key):
        name, ext = p["name"], os.path.splitext(p["path"])[1].lower()
        if p["skip"]:
            if p["row"].get("asset_id") != str(p["last"]["asset_id"]):
                self.set_manifest(self.repo, name, self.manifest_fields(p, p["last"]["asset_id"]))
            self.log("[upload] skip %s: same file as asset %s" % (name, p["last"]["asset_id"]))
            return p["last"]["asset_id"]
        request = {"assetType": p["asset_type"], "displayName": name[:50], "description": "GULP %s" % name,
                   "creationContext": {"creator": creator}}
        body, ctype = multipart({"request": json.dumps(request)},
                                {"fileContent": (os.path.basename(p["path"]), MIME[ext], p["blob"])})
        if self.last_post is not None:                       # rate limit: space the POSTs
            wait = self.interval - (self.clock() - self.last_post)
            if wait > 0:
                self.sleep(wait)
        for attempt in range(6):
            self.last_post = self.clock()
            status, raw, headers = self.http("POST", API + "/assets/v1/assets", body, {"x-api-key": key, "Content-Type": ctype})
            if status != 429:
                break
            self.sleep(float(headers.get("Retry-After") or 5 * (attempt + 1)))
        if status != 200:
            raise RuntimeError("upload %s: HTTP %d %s" % (name, status, raw[:300].decode(errors="replace").replace(key, "<key>")))
        op = json.loads(raw)["path"]
        result = {}
        for i in range(self.poll_limit):
            self.sleep(1.5 if i < 10 else 4.0)
            status, raw, headers = self.http("GET", API + "/assets/v1/" + op, None, {"x-api-key": key})
            if status == 200:
                result = json.loads(raw)
                if result.get("done"):
                    break
            elif status == 429:
                self.sleep(float(headers.get("Retry-After") or 5))
        if not result.get("done"):
            raise RuntimeError("upload %s: operation %s not done after %d polls" % (name, op, self.poll_limit))
        if "error" in result:
            raise RuntimeError("upload %s: %s" % (name, json.dumps(result["error"])[:300]))
        asset_id = int(result["response"]["assetId"])
        state = self.state()
        state[name] = {"sha256": p["sha256"], "asset_id": asset_id, "asset_type": p["asset_type"],
                       "file": os.path.relpath(p["path"], self.repo), "placeholder": p["placeholder"], "operation": op,
                       "moderation": (result["response"].get("moderationResult") or {}).get("moderationState"),
                       "uploaded": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}
        self.save_state(state)                               # the ID is on disk before the manifest write can fail
        self.set_manifest(self.repo, name, self.manifest_fields(p, asset_id))
        self.log("[upload] %s %s -> %d" % (p["asset_type"], name, asset_id))
        return asset_id

    # -------------------------------------------------------------- modes
    def run(self, names, dry_run, decal=False, placeholders=False):
        plans, refused = [], []
        for name in names:
            try:
                plans.append(self.plan(name, decal, placeholders))
            except Refused as e:
                refused.append((name, str(e)))
        for p in plans:
            self.log("[upload] %s %-36s %-9s %s sha %s%s" % ("skip" if p["skip"] else "plan", p["name"], p["asset_type"],
                                                           os.path.relpath(p["path"], self.repo), p["sha256"][:12],
                                                           " (placeholder)" if p["placeholder"] else ""))
        for name, why in refused:
            self.log("[upload] refused %s" % why)
        if dry_run:
            todo = sum(1 for p in plans if not p["skip"])
            self.log("[upload] dry run: %d to upload, %d unchanged, %d refused; nothing sent" % (todo, len(plans) - todo, len(refused)))
            return {"planned": plans, "refused": refused, "uploaded": {}}
        creator = self.creator()
        key = self.key()
        uploaded = {}
        with self.lock(self.repo):
            for p in plans:
                uploaded[p["name"]] = self.upload_one(p, creator, key)
        return {"planned": plans, "refused": refused, "uploaded": uploaded}

    def batch_names(self, prefix="", limit=None, placeholders=False):
        names = []
        for name in self.manifest():
            if not name.startswith(prefix) or name.startswith(NO_ID_PREFIXES):
                continue
            try:
                self.locate(name, placeholders=placeholders)
            except Refused as e:
                if "Studio" not in str(e):
                    continue
            names.append(name)
        return names[:limit] if limit else names


def main(argv):
    p = argparse.ArgumentParser(prog="upload.py")
    sub = p.add_subparsers(dest="mode", required=True)
    r = sub.add_parser("row")
    r.add_argument("name")
    r.add_argument("--dry-run", action="store_true")
    b = sub.add_parser("batch")
    b.add_argument("--prefix", default="")
    b.add_argument("--limit", type=int)
    b.add_argument("--live", action="store_true", help="really upload (a batch is a dry run without it)")
    s = sub.add_parser("show")
    s.add_argument("name")
    for q in (r, b):
        q.add_argument("--decal", action="store_true", help="textures as Decal instead of Image")
        q.add_argument("--placeholders", action="store_true", help="use assets/placeholder/ for rows with no export")
        q.add_argument("--interval", type=float, default=2.0, help="seconds between uploads")
    a = p.parse_args(argv)
    try:
        if a.mode == "show":
            print(json.dumps(Uploader().state().get(a.name, {}), indent=1))
            return 0
        up = Uploader(interval=a.interval)
        if a.mode == "row":
            out = up.run([a.name], a.dry_run, a.decal, a.placeholders)
        else:
            out = up.run(up.batch_names(a.prefix, a.limit, a.placeholders), not a.live, a.decal, a.placeholders)
        return 1 if out["refused"] else 0
    except Refused as e:
        print("[upload] stopped: %s" % e)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
