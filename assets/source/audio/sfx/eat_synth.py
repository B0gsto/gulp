#!/usr/bin/env python3
"""First eating sounds (sprint task S4-A2): SFX_Bite_Small (3 takes), SFX_EatPlankton (4 takes) and
SFX_Swallow_Small (3 takes), the three rows of docs/07-asset-list.md section 11.2 the first playable
needs (a tier 1-2 Minnow biting Krill, eating Plankton, swallowing). Procedural, made in-house: no
recordings, no library clips, so the licence is `original` (07 section 12, rule 5).

    python3 assets/source/audio/sfx/eat_synth.py            write the source WAVs (git-ignored)
    python3 assets/source/audio/sfx/eat_synth.py --measure  measure the exported OGGs into
                                                            assets/review/_audio/eat_loudness.csv

Then the audio batch levels and encodes them (peak -3 dBFS, mono intent, OGG; 07 section 12 rule 7):
    python3 assets/source/_shared/pipeline/audio_batch.py SFX_Bite_Small01 ...

Every sound is layered: an attack transient, a body, and a bubble tail. Every layer starts with a
raised-cosine ramp or at a zero crossing and the file ends on a raised-cosine fade, so nothing clicks
except the wooden click that is meant to. Takes differ by seeded pitch, timing and level jitter.
Needs numpy. 44.1 kHz, mono, 16-bit with TPDF dither, peak -1 dBFS before the batch levels it.
"""
import csv
import math
import os
import subprocess
import sys
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
GEN = os.path.join(HERE, "_gen")
EXPORT = os.path.join(ASSETS, "export", "audio", "sfx")
REVIEW = os.path.join(ASSETS, "review", "_audio")
SR = 44100

# name -> (takes, nominal length in s from 07 section 11.2)
SOUNDS = {"SFX_Bite_Small": (3, 0.15), "SFX_EatPlankton": (4, 0.08), "SFX_Swallow_Small": (3, 0.2)}


# ---------------------------------------------------------------- building blocks

def timeline(seconds):
    return np.arange(int(round(seconds * SR))) / SR


def ramp_in(n_ms, length):
    n = max(1, int(n_ms * SR / 1000.0))
    r = np.ones(length)
    m = min(n, length)
    r[:m] = 0.5 - 0.5 * np.cos(np.pi * np.arange(m) / n)
    return r


def mix(*parts):
    """Sum layers of different lengths (each starts at sample 0)."""
    out = np.zeros(max(len(x) for x in parts))
    for x in parts:
        out[:len(x)] += x
    return out


def place(buf, sig, at):
    i = int(round(at * SR))
    j = min(len(buf), i + len(sig))
    if j > i:
        buf[i:j] += sig[:j - i]


def sweep_phase(f_start, f_end, t, curve=1.0):
    """Phase of a tone gliding from f_start to f_end over len(t) (exponential glide, shaped by curve)."""
    u = (t / max(t[-1], 1e-9)) ** curve
    f = f_start * (f_end / f_start) ** u
    return 2 * np.pi * np.cumsum(f) / SR


def mode(freq, tau, seconds, attack_ms=0.0, drop=0.0):
    """A damped sine (a struck wooden or shell mode). Starts at phase 0, so it starts at zero."""
    t = timeline(seconds)
    f_end = freq * (1 - drop)
    ph = sweep_phase(freq, f_end, t, 0.5) if drop else 2 * np.pi * freq * t
    s = np.sin(ph) * np.exp(-t / tau)
    return s * (ramp_in(attack_ms, len(t)) if attack_ms else 1)


def bubble(f0, rise, tau, seconds, attack_ms=0.8):
    """Minnaert-style bubble: a sine whose pitch rises as it decays (f0 to f0 * (1 + rise))."""
    t = timeline(seconds)
    f = f0 * (1 + rise * (1 - np.exp(-t / (tau * 1.6))))
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / tau)
    return s * ramp_in(attack_ms, len(t))


def biquad(x, kind, fc, q, gain_db=0.0):
    """RBJ cookbook biquad, direct form I (short signals, so a Python loop is fine)."""
    w0 = 2 * math.pi * fc / SR
    al, cw = math.sin(w0) / (2 * q), math.cos(w0)
    if kind == "bp":
        b, a = (al, 0, -al), (1 + al, -2 * cw, 1 - al)
    elif kind == "lp":
        b, a = ((1 - cw) / 2, 1 - cw, (1 - cw) / 2), (1 + al, -2 * cw, 1 - al)
    elif kind == "hp":
        b, a = ((1 + cw) / 2, -(1 + cw), (1 + cw) / 2), (1 + al, -2 * cw, 1 - al)
    elif kind == "hs":
        A = 10 ** (gain_db / 40.0)
        sa = 2 * math.sqrt(A) * al
        b = (A * ((A + 1) + (A - 1) * cw + sa), -2 * A * ((A - 1) + (A + 1) * cw), A * ((A + 1) + (A - 1) * cw - sa))
        a = ((A + 1) - (A - 1) * cw + sa, 2 * ((A - 1) - (A + 1) * cw), (A + 1) - (A - 1) * cw - sa)
    else:
        raise ValueError(kind)
    b = [v / a[0] for v in b]
    a = [1.0, a[1] / a[0], a[2] / a[0]]
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        o = b[0] * v + b[1] * x1 + b[2] * x2 - a[1] * y1 - a[2] * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y[i] = o
    return y


def noise_burst(rng, fc, q, tau, seconds, attack_ms=0.3):
    t = timeline(seconds)
    n = biquad(rng.standard_normal(len(t)), "bp", fc, q)
    n /= max(np.abs(n).max(), 1e-9)
    return n * np.exp(-t / tau) * ramp_in(attack_ms, len(t))


def gulp_voice(f0a, f0b, fa, fb, seconds, attack_ms=9.0, curve=0.7):
    """Cartoon throat 'ulp': a harmonic source gliding up in pitch, shaped by one formant that also
    glides up (additive synthesis, so no aliasing and no filter ringing)."""
    t = timeline(seconds)
    u = (t / t[-1]) ** curve
    f0 = f0a * (f0b / f0a) ** u
    fc = fa * (fb / fa) ** u
    ph = 2 * np.pi * np.cumsum(f0) / SR
    out = np.zeros(len(t))
    for k in range(1, 18):
        fk = k * f0
        g = np.exp(-0.5 * (np.log2(np.maximum(fk, 1) / fc) / 0.55) ** 2) / (k ** 0.35)
        g = np.where(fk < SR * 0.45, g, 0)
        out += g * np.sin(k * ph)
    env = ramp_in(attack_ms, len(t)) * np.clip(1.0 - np.maximum(u - 0.55, 0) / 0.45, 0, 1) ** 1.6
    return out * env


def finish(x, fade_ms=6.0, hp=45.0, lp=None):
    x = biquad(x, "hp", hp, 0.707)
    if lp:
        x = biquad(x, "lp", lp, 0.707)
    x = np.tanh(x * 1.2) / np.tanh(1.2)                 # gentle glue, rounds the loudest peak
    n = int(fade_ms * SR / 1000.0)
    x[-n:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(n) / n)
    return np.concatenate([np.zeros(int(0.002 * SR)), x, np.zeros(int(0.010 * SR))])


# ---------------------------------------------------------------- the three sounds

def bite_small(take):
    """'Light wooden click with a wet edge' (07 11.2): a two-tooth wooden clack, a small hollow
    'tock' body, then a wet smack and one bubble."""
    rng = np.random.default_rng(1100 + take)
    p = 1 + rng.uniform(-0.05, 0.05) + (take - 1) * 0.03        # each take sits at its own pitch
    L = 0.15
    buf = np.zeros(int(L * SR))
    # 1. attack: the jaws meet. Short bright noise + three wooden modes; a second, softer tooth 9-13 ms later
    click = mix(0.55 * noise_burst(rng, 3600 * p, 1.4, 0.0016, 0.02),
                1.0 * mode(1750 * p, 0.011, 0.06), 0.55 * mode(2840 * p, 0.007, 0.04),
                0.30 * mode(4250 * p, 0.004, 0.03))
    place(buf, click, 0.0)
    gap = rng.uniform(0.009, 0.013)
    place(buf, 0.5 * mix(mode(1960 * p, 0.008, 0.04), 0.5 * mode(3150 * p, 0.005, 0.03),
                         0.35 * noise_burst(rng, 4200 * p, 1.6, 0.0012, 0.015)), gap)
    # 2. body: a hollow little 'tock' that drops in pitch (the mouth as a wood block)
    place(buf, 0.62 * mode(520 * p, 0.028, 0.12, attack_ms=0.8, drop=0.22), 0.0005)
    place(buf, 0.22 * mode(1040 * p, 0.016, 0.06, attack_ms=0.6), 0.0005)
    # 3. wet edge: a soft smack and one bright bubble rising out of the mouth
    place(buf, 0.16 * noise_burst(rng, 1250 * p, 2.2, 0.012, 0.05, attack_ms=2.0), 0.014)
    place(buf, 0.42 * bubble(1350 * p * rng.uniform(0.95, 1.05), 0.75, 0.018, 0.09), 0.02 + rng.uniform(0, 0.006))
    return finish(buf, lp=12000)


def eat_plankton(take):
    """'Tiny soft tick. Quiet, because it can fire many times a second' (07 11.2): a soft glassy tick
    and a tiny plip. Rounded attack and low-passed so it never pricks the ear when repeated."""
    rng = np.random.default_rng(2200 + take)
    p = 1 + rng.uniform(-0.04, 0.04) + (take - 1.5) * 0.045
    L = 0.08
    buf = np.zeros(int(L * SR))
    tick = mix(0.7 * mode(2900 * p, 0.0055, 0.03, attack_ms=0.5), 0.3 * mode(4650 * p, 0.003, 0.02, attack_ms=0.4),
               0.18 * noise_burst(rng, 5200 * p, 1.2, 0.0012, 0.01, attack_ms=0.4))
    place(buf, tick, 0.0)
    place(buf, 0.25 * mode(880 * p, 0.012, 0.05, attack_ms=1.0), 0.0)          # a little weight under it
    place(buf, 0.75 * bubble(1900 * p, 0.6, 0.011, 0.06, attack_ms=0.7), 0.005 + rng.uniform(0, 0.003))
    return finish(buf, fade_ms=5.0, hp=120, lp=9000)


def swallow_small(take):
    """'Quick rising gulp after a small bite' (07 11.2): a soft throat thump, a rising cartoon 'ulp',
    then two little bubbles."""
    rng = np.random.default_rng(3300 + take)
    p = 1 + rng.uniform(-0.04, 0.04) + (take - 1) * 0.04
    L = 0.2
    buf = np.zeros(int(L * SR))
    # 1. attack: throat closes: a short low thump and a wet 'g' of filtered noise
    place(buf, 0.55 * mode(125 * p, 0.022, 0.1, attack_ms=2.5, drop=0.3), 0.0)
    place(buf, 0.22 * noise_burst(rng, 950 * p, 1.8, 0.007, 0.03, attack_ms=1.2), 0.002)
    # 2. body: the rising gulp
    dur = 0.13 * rng.uniform(0.95, 1.05)
    place(buf, 0.78 * gulp_voice(150 * p, 330 * p, 480 * p, 1150 * p, dur), 0.008)
    # 3. bubble tail: two small bubbles, the second higher and quieter
    t1 = 0.008 + dur * 0.82
    place(buf, 0.34 * bubble(980 * p, 0.7, 0.016, 0.08), t1)
    place(buf, 0.24 * bubble(1450 * p * rng.uniform(0.96, 1.04), 0.6, 0.012, 0.06), t1 + rng.uniform(0.026, 0.034))
    return finish(buf, lp=10000)


MAKERS = {"SFX_Bite_Small": bite_small, "SFX_EatPlankton": eat_plankton, "SFX_Swallow_Small": swallow_small}


def write_wav(path, x, peak_db=-1.0):
    x = x / max(np.abs(x).max(), 1e-9) * 10 ** (peak_db / 20.0)
    rng = np.random.default_rng(7)
    q = np.clip(np.round(x * 32767 + (rng.random(len(x)) - rng.random(len(x)))), -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(q.tobytes())


def take_name(name, k):
    """A take's file name: the 07 row name with the two-digit take number appended to its last word
    (SFX_Bite_Small01, SFX_EatPlankton03). 07 section 1.2 has no rule for takes; this form keeps every
    row name whole and stays within its "two inner underscores at most" rule, which `_01` would break
    for a sized row such as SFX_Bite_Small. Code finds a row's takes by stripping the two digits."""
    return "%s%02d" % (name, k)


def take_names():
    for name, (takes, _) in SOUNDS.items():
        for k in range(1, takes + 1):
            yield name, k, take_name(name, k)


def synth():
    os.makedirs(GEN, exist_ok=True)
    for name, k, file_name in take_names():
        x = MAKERS[name](k)
        path = os.path.join(GEN, file_name + ".wav")
        write_wav(path, x)
        print("wrote %s  %.3f s" % (os.path.relpath(path, os.path.dirname(ASSETS)), len(x) / SR))


# ---------------------------------------------------------------- measurement

def k_weight(x):
    """ITU-R BS.1770 K-weighting (pre-filter shelf + RLB high-pass) at 44.1 kHz."""
    x = biquad(x, "hs", 1681.9744509555319, 0.7071752369554193, 3.99984385397)
    return biquad(x, "hp", 38.13547087613982, 0.5003270373253953)


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-acodec", "pcm_f32le", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=channels",
                            "-of", "csv=p=0", path], capture_output=True, text=True, check=True).stdout
    ch = int(probe.strip() or 1)
    return np.frombuffer(raw, "<f4").astype(np.float64).reshape(-1, ch), ch


def db(v):
    return 20 * math.log10(max(v, 1e-12))


def measure():
    os.makedirs(REVIEW, exist_ok=True)
    rows = []
    for name, k, file_name in take_names():
        path = os.path.join(EXPORT, file_name + ".ogg")
        if not os.path.isfile(path):
            raise SystemExit("missing %s: run the audio batch first" % path)
        data, ch = decode(path)
        mono = data[:, 0]                              # mono since the batch encodes with oggenc; else two identical channels
        kw = k_weight(mono)
        ms = float(np.mean(kw ** 2))
        win = int(0.4 * SR)                            # BS.1770 momentary window; a clip shorter than it is zero-padded
        padded = np.concatenate([kw ** 2, np.zeros(win)])
        mom = max(float(np.sum(padded[i:i + win])) / win for i in range(0, max(1, len(kw)), 441))
        rows.append({
            "file": file_name + ".ogg", "seconds": round(len(mono) / SR, 3), "channels": ch,
            "identical_channels": bool(ch == 1 or np.allclose(data[:, 0], data[:, 1:].T, atol=1e-6)),
            "peak_dbfs": round(db(np.abs(mono).max()), 2),
            "rms_dbfs": round(db(math.sqrt(np.mean(mono ** 2))), 2),
            "lufs_clip": round(-0.691 + 10 * math.log10(ms), 1),
            "lufs_momentary_max": round(-0.691 + 10 * math.log10(mom), 1),
            "first_last_sample": "%.4f / %.4f" % (abs(mono[0]), abs(mono[-1])),
            "licence": "original", "source": "procedural, made in-house (assets/source/audio/sfx/eat_synth.py)",
        })
    out = os.path.join(REVIEW, "eat_loudness.csv")
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]), lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    for r in rows:
        print("%-24s %.3f s  ch %d  peak %6.2f dBFS  rms %6.2f dBFS  %5.1f LUFS clip  %5.1f LUFS momentary max"
              % (r["file"], r["seconds"], r["channels"], r["peak_dbfs"], r["rms_dbfs"], r["lufs_clip"], r["lufs_momentary_max"]))
    print("wrote", os.path.relpath(out, os.path.dirname(ASSETS)))


if __name__ == "__main__":
    if "--measure" in sys.argv[1:]:
        measure()
    else:
        synth()
