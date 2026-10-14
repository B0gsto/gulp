#!/usr/bin/env python3
"""Audio batch (docs/07-asset-list.md section 14.1: "Trim, level, export to OGG, check loops";
rules in section 12, upload rules 5 to 7, and section 11: every sound effect is a mono OGG).

    python3 assets/source/_shared/pipeline/audio_batch.py                 every row of the sources table
    python3 assets/source/_shared/pipeline/audio_batch.py SFX_Gulp ...    the named rows
    python3 assets/source/_shared/pipeline/audio_batch.py --selftest      two generated test tones (and two
                                                                          faults it must catch), in a temp folder

The sources table, assets/source/audio/sources.csv, has one row per sound:
    name      SFX_* or MUS_* (07 section 1.2)
    file      the source clip, relative to assets/source/audio/ (wav, flac, aiff, ogg, mp3 ...)
    loop      yes or no
    licence   `original` for our own work, else the licence text file in assets/licences/ (07 12, rule 5)
    source    where it came from: the author, library and clip ID, or the project file
A row without a licence and a source fails; so does a licence file that does not exist.

Per row: trim the silence at both ends (one-shots only: a loop runs from its first sample to
its last, 07 section 12), level it (effects: peak at -3 dBFS; music: -16 LUFS integrated with
the peak kept under -1 dBFS; 07 12 rule 7, both tune), mix effects to mono, encode OGG Vorbis at
44.1 kHz (see encoder()) into assets/export/audio/sfx|music/<name>.ogg, then decode the result and check:
level reached, channels, nothing clipped, and for loops: no gap of silence at either end and
no click where the end joins the start. Report: assets/review/_audio/<date>_audio_report.json.
Encodes with oggenc (vorbis-tools, the reference libvorbis encoder: mono effects as 07 section 11
asks); ffmpeg does the trimming, mixing, levelling, decoding and analysis. Nothing is installed by
this tool: without oggenc it falls back to ffmpeg's libvorbis, else to ffmpeg's native `vorbis`
encoder, which is stereo only, so effects are then written as two identical channels and the format
check says so (a deviation from 07 section 11). Exit status 1 when any row fails.
"""
import argparse
import array
import csv
import datetime
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))
SOURCE_DIR = os.path.join(REPO, "assets", "source", "audio")
SOURCES = os.path.join(SOURCE_DIR, "sources.csv")
EXPORT_DIR = os.path.join(REPO, "assets", "export", "audio")
LICENCES = os.path.join(REPO, "assets", "licences")
REVIEW = os.path.join(REPO, "assets", "review", "_audio")
COLUMNS = ["name", "file", "loop", "licence", "source"]

RATE = 44100
SFX_PEAK_DB = -3.0          # 07 section 12 rule 7 (tune)
MUSIC_LUFS = -16.0          # 07 section 12 rule 7 (tune)
MUSIC_PEAK_CEILING_DB = -1.0
PEAK_TOL_DB, LUFS_TOL = 0.5, 1.0
TRIM_DB = -50.0             # one-shots: silence below this at either end is cut
GAP_MS = 5.0                # loops: more digital silence than this at an end is a gap
RE_NAME = re.compile(r"^(SFX|MUS)(_[A-Z0-9][A-Za-z0-9]*){1,3}$")   # 07 1.2: two inner underscores at most
OGG_QUALITY = 6


def ffmpeg():
    exe = shutil.which("ffmpeg")
    if not exe:
        raise SystemExit("ffmpeg not found (this tool installs nothing)")
    return exe


def encoder():
    """The OGG Vorbis encoder: ('oggenc', path) when vorbis-tools is installed (any channel count);
    else ('libvorbis', ffmpeg codec args) when this ffmpeg has it; else ('native', args) for ffmpeg's
    own `vorbis`, which encodes two channels only, so a mono effect becomes two identical channels."""
    exe = shutil.which("oggenc")
    if exe:
        return "oggenc", exe
    found = subprocess.run([ffmpeg(), "-hide_banner", "-encoders"], capture_output=True, text=True).stdout
    if re.search(r"\blibvorbis\b", found):
        return "libvorbis", ["-c:a", "libvorbis", "-q:a", str(OGG_QUALITY)]
    return "native", ["-c:a", "vorbis", "-strict", "-2", "-ac", "2"]


def encode(stage, gain_db, out, channels, tmp):
    """Apply one gain to the staged float WAV and write OGG Vorbis at RATE. channels None keeps the
    source's. Returns True when the requested channel count could be kept."""
    kind, enc = encoder()
    pre = ["-i", stage, "-af", "volume=%.4fdB" % gain_db, "-ar", str(RATE)] + (["-ac", str(channels)] if channels else [])
    if kind == "oggenc":
        wav = os.path.join(tmp, "level.wav")
        run_ff(pre + ["-c:a", "pcm_f32le", wav])
        done = subprocess.run([enc, "-Q", "-q", str(OGG_QUALITY), "-o", out, wav], capture_output=True)
        if done.returncode != 0:
            raise RuntimeError("oggenc: " + done.stderr.decode(errors="replace")[-400:])
        return True
    if kind == "libvorbis":
        run_ff(pre + enc + [out])
        return True
    run_ff(pre[:-2] + enc + [out] if channels else pre + enc + [out])
    return channels is None or channels == 2


def run_ff(args):
    done = subprocess.run([ffmpeg(), "-hide_banner", "-nostdin", "-y"] + args, capture_output=True)
    if done.returncode != 0:
        raise RuntimeError("ffmpeg: " + done.stderr.decode(errors="replace")[-400:])
    return done


def decode(path, channels=None):
    """Samples as floats, interleaved, and the channel count."""
    if channels is None:
        probe = subprocess.run(["ffprobe" if shutil.which("ffprobe") else ffmpeg().replace("ffmpeg", "ffprobe"),
                                "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=channels",
                                "-of", "csv=p=0", path], capture_output=True, text=True)
        channels = int(probe.stdout.strip() or 1)
    raw = run_ff(["-i", path, "-f", "f32le", "-acodec", "pcm_f32le", "-ar", str(RATE), "-ac", str(channels), "-"]).stdout
    data = array.array("f")
    data.frombytes(raw)
    if sys.byteorder != "little":
        data.byteswap()
    return data, channels


def db(x):
    return 20.0 * math.log10(x) if x > 0 else -200.0


def peak_db(data):
    return db(max((abs(v) for v in data), default=0.0))


def lufs(path):
    err = run_ff(["-i", path, "-af", "ebur128=framelog=quiet", "-f", "null", "-"]).stderr.decode(errors="replace")
    found = re.findall(r"I:\s*(-?[\d.]+|-inf)\s*LUFS", err)
    return float(found[-1]) if found and found[-1] != "-inf" else -200.0


def frames_of(data, channels):
    """Per-frame mono view (the loudest channel's value at each frame)."""
    n = len(data) // channels
    if channels == 1:
        return list(data)
    return [max((data[i * channels + c] for c in range(channels)), key=abs) for i in range(n)]


def loop_checks(mono):
    """(gap ok, click ok, detail): silence at the ends, and the step from the last sample to the
    first against the clip's own sample-to-sample steps."""
    floor = 10 ** (TRIM_DB / 20.0)
    lead = next((i for i, v in enumerate(mono) if abs(v) > floor), len(mono))
    tail = next((i for i, v in enumerate(reversed(mono)) if abs(v) > floor), len(mono))
    gap_ms = 1000.0 * max(lead, tail) / RATE
    steps = sorted(abs(b - a) for a, b in zip(mono, mono[1:]))
    typical = steps[int(0.99 * (len(steps) - 1))] if steps else 0.0
    seam = abs(mono[0] - mono[-1])
    click_ok = seam <= max(1.5 * typical, 1e-3)
    return gap_ms <= GAP_MS, click_ok, ("ends silent for %.1f ms; seam step %.4f against the clip's 99th-percentile step %.4f"
                                        % (gap_ms, seam, typical))


def read_sources(path):
    with open(path, newline="", encoding="utf-8") as f:
        rows = [r for r in csv.DictReader(f) if (r.get("name") or "").strip() and not r["name"].startswith("#")]
    return rows


def process(row, source_dir, out_root, licences_dir):
    name = row["name"].strip()
    res = {"name": name, "checks": []}

    def add(check, ok, detail=""):
        res["checks"].append({"check": check, "ok": bool(ok), "detail": detail})
        return ok

    add("naming", RE_NAME.match(name), name)
    licence, source = (row.get("licence") or "").strip(), (row.get("source") or "").strip()
    licence_ok = licence == "original" or (licence and os.path.isfile(os.path.join(licences_dir, licence)))
    add("licence and source", licence_ok and source,
        "licence %s, source %s" % (licence or "MISSING", source or "MISSING") +
        ("" if licence_ok or not licence else " (no file assets/licences/%s)" % licence))
    src = os.path.join(source_dir, (row.get("file") or "").strip())
    if not add("source file", os.path.isfile(src), os.path.relpath(src, REPO) if src.startswith(REPO) else src):
        res["ok"] = False
        return res
    music, loop = name.startswith("MUS_"), (row.get("loop") or "").strip().lower() in ("yes", "true", "1")
    channels = None if music else 1
    out = os.path.join(out_root, "music" if music else "sfx", name + ".ogg")
    os.makedirs(os.path.dirname(out), exist_ok=True)

    tmp = tempfile.mkdtemp(prefix="gulp_audio_")
    try:
        # 1. trim (one-shots), mono for effects, to a float WAV we can measure
        stage = os.path.join(tmp, "stage.wav")
        filters = []
        if not loop:
            edge = "silenceremove=start_periods=1:start_threshold=%gdB:start_silence=0.002" % TRIM_DB
            filters += [edge, "areverse", edge, "areverse"]
        args = ["-i", src] + (["-af", ",".join(filters)] if filters else []) + ["-ar", str(RATE)]
        if channels:
            args += ["-ac", str(channels)]
        run_ff(args + ["-c:a", "pcm_f32le", stage])
        data, ch = decode(stage)
        src_seconds = len(data) / float(ch * RATE)
        # 2. level: one gain for the whole file
        if music:
            gain = MUSIC_LUFS - lufs(stage)
            gain = min(gain, MUSIC_PEAK_CEILING_DB - peak_db(data))
        else:
            gain = SFX_PEAK_DB - peak_db(data)
        # 3. encode, then measure the file itself and correct once (the encoder moves peaks a little)
        for _ in range(2):
            encode(stage, gain, out, channels, tmp)
            got, ch = decode(out)
            pk = peak_db(got)
            target = None if music else SFX_PEAK_DB
            if target is None or abs(pk - target) <= 0.2:
                break
            gain += target - pk
        loud = lufs(out) if len(got) / float(ch * RATE) >= 0.4 else None   # EBU R128 gates on 400 ms blocks
        seconds = len(got) / float(ch * RATE)
        res.update(file=out, seconds=round(seconds, 4), channels=ch, gain_db=round(gain, 2), peak_db=round(pk, 2),
                   lufs=None if loud is None else round(loud, 1), loop=loop, licence=licence, source=source)
        same = ch == 2 and all(got[i] == got[i + 1] for i in range(0, len(got) - 1, 2))
        add("format", out.endswith(".ogg") and (music or ch == 1 or same),
            "OGG Vorbis, %d channel%s, %d Hz, %.3f s%s" % (ch, "" if ch == 1 else "s", RATE, seconds,
                                                          "" if music or ch == 1 else
                                                          "; DEVIATION from 07 section 11 (mono): two identical channels, "
                                                          "no oggenc and no libvorbis: ffmpeg's native encoder is stereo only"))
        # The encoder may pad the last block: harmless after a one-shot, a gap in a loop.
        add("length kept", abs(seconds - src_seconds) <= (0.002 if loop else 0.025),
            "%.4f s out, %.4f s %s" % (seconds, src_seconds, "in (a loop gains no padding)" if loop else
                                      "after trimming (up to 25 ms of encoder padding allowed)"))
        if music:
            add("level", abs(loud - MUSIC_LUFS) <= LUFS_TOL or pk >= MUSIC_PEAK_CEILING_DB - 0.3,
                "%.1f LUFS (target %.0f), peak %.2f dBFS" % (loud, MUSIC_LUFS, pk))
        else:
            add("level", abs(pk - SFX_PEAK_DB) <= PEAK_TOL_DB, "peak %.2f dBFS (target %.0f)" % (pk, SFX_PEAK_DB))
        add("no clipping", pk < 0.0, "peak %.2f dBFS" % pk)
        if loop:
            gap_ok, click_ok, detail = loop_checks(frames_of(got, ch))
            add("loop: no gap", gap_ok, detail.split(";")[0])
            add("loop: no click", click_ok, detail.split("; ")[1])
    except RuntimeError as e:
        add("processing", False, str(e))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    res["ok"] = all(c["ok"] for c in res["checks"])
    return res


def batch(rows, source_dir=SOURCE_DIR, out_root=EXPORT_DIR, licences_dir=LICENCES, report_dir=REVIEW):
    results = [process(r, source_dir, out_root, licences_dir) for r in rows]
    for r in results:
        fails = [c for c in r["checks"] if not c["ok"]]
        print("[audio] %-4s %-28s %s" % ("OK" if r["ok"] else "FAIL", r["name"],
                                         "; ".join("%s: %s" % (c["check"], c["detail"]) for c in fails) or
                                         "%.3f s, peak %s dBFS, %s LUFS%s" % (r.get("seconds", 0), r.get("peak_db"), r.get("lufs") or "n/a",
                                                                              ", loop" if r.get("loop") else "")))
    os.makedirs(report_dir, exist_ok=True)
    path = os.path.join(report_dir, "%s_audio_report.json" % datetime.date.today().isoformat())
    with open(path, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=1)
    print("[audio] report %s" % path)
    return results


# ---------------------------------------------------------------- self-test: two generated test tones

def selftest():
    tmp = tempfile.mkdtemp(prefix="gulp_audio_selftest_")
    src, out, lic, rep = (os.path.join(tmp, d) for d in ("src", "out", "licences", "review"))
    for d in (src, lic):
        os.makedirs(d)

    def tone(name, expr, seconds):
        run_ff(["-f", "lavfi", "-i", "aevalsrc='%s':d=%.3f:s=%d" % (expr, seconds, RATE), "-ac", "2",
                os.path.join(src, name + ".wav")])

    # one-shot: 0.2 s of silence, a quiet 0.3 s 1 kHz beep, 0.1 s of silence (to trim, then level up)
    tone("beep", "if(between(t,0.2,0.5),0.1*sin(2*PI*1000*t)*min(1,(t-0.2)/0.01)*min(1,(0.5-t)/0.01),0)", 0.6)
    # loop: 2 s of 220 Hz, exactly 440 cycles, so the end meets the start
    tone("loop", "0.3*sin(2*PI*220*t)", 2.0)
    # fault: 2 s of 233.3 Hz ends mid-cycle, so the loop clicks
    tone("badloop", "0.3*sin(2*PI*233.3*t+1)", 2.0)
    rows = [
        {"name": "SFX_Test_Beep", "file": "beep.wav", "loop": "no", "licence": "original", "source": "audio_batch selftest tone"},
        {"name": "SFX_Test_Loop", "file": "loop.wav", "loop": "yes", "licence": "original", "source": "audio_batch selftest tone"},
        {"name": "SFX_Test_BadLoop", "file": "badloop.wav", "loop": "yes", "licence": "original", "source": "selftest fault"},
        {"name": "SFX_Test_NoLicence", "file": "beep.wav", "loop": "no", "licence": "", "source": ""},
    ]
    results = {r["name"]: r for r in batch(rows, src, out, lic, rep)}

    def check(r, name):
        return next((c for c in results[r]["checks"] if c["check"] == name), {"ok": None})

    expects = [
        ("beep passes", results["SFX_Test_Beep"]["ok"]),
        ("beep trimmed to 0.3 s", abs(results["SFX_Test_Beep"].get("seconds", 0) - 0.3) < 0.02),
        ("beep levelled to -3 dBFS peak", abs(results["SFX_Test_Beep"].get("peak_db", 0) + 3.0) <= PEAK_TOL_DB),
        ("beep mixed to mono (or dual mono, see format)", check("SFX_Test_Beep", "format")["ok"] is True),
        ("loop passes, untrimmed 2.0 s", results["SFX_Test_Loop"]["ok"] and abs(results["SFX_Test_Loop"]["seconds"] - 2.0) < 0.002),
        ("bad loop fails the click check", check("SFX_Test_BadLoop", "loop: no click")["ok"] is False),
        ("missing licence fails", check("SFX_Test_NoLicence", "licence and source")["ok"] is False),
    ]
    for label, ok in expects:
        print("[audio-selftest] %s  %s" % ("PASS" if ok else "FAIL", label))
    print("[audio-selftest] outputs in %s" % out)
    return all(ok for _, ok in expects)


def main(argv):
    p = argparse.ArgumentParser(prog="audio_batch.py")
    p.add_argument("names", nargs="*")
    p.add_argument("--sources", default=SOURCES)
    p.add_argument("--selftest", action="store_true")
    a = p.parse_args(argv)
    if a.selftest:
        return 0 if selftest() else 1
    rows = read_sources(a.sources)
    if a.names:
        known = {r["name"] for r in rows}
        missing = [n for n in a.names if n not in known]
        if missing:
            raise SystemExit("not in %s: %s" % (os.path.relpath(a.sources, REPO), ", ".join(missing)))
        rows = [r for r in rows if r["name"] in a.names]
    if not rows:
        print("[audio] no rows in %s" % os.path.relpath(a.sources, REPO))
        return 0
    return 0 if all(r["ok"] for r in batch(rows)) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
