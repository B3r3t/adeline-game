"""Builds every sound in the game into ../audio, and writes audio/manifest.json.

Usage: python3 -I build_audio.py voice ../audio

Two kinds of sound go in:
  * Recorded voices (Merlin's lines, Adeline's shouts, goblin grunts, Spirit's whinny).
    These are trimmed, levelled, and for goblins pitched up.
  * Effects made here from scratch with plain maths (chimes, whooshes, hoofbeats, knocks),
    so they are small, clean and always the same.
"""
import json
import os
import subprocess
import sys

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(SR * seconds)) / SR


def env_decay(n, tau):
    return np.exp(-np.arange(n) / (SR * tau))


def fade(x, attack=0.004, release=0.02):
    a = int(SR * attack)
    r = int(SR * release)
    x = x.copy()
    x[:a] *= np.linspace(0.0, 1.0, a)
    x[-r:] *= np.linspace(1.0, 0.0, r)
    return x


def lowpass(x, hz, order=2):
    b, a = signal.butter(order, hz / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def highpass(x, hz, order=2):
    b, a = signal.butter(order, hz / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def sweep_noise(seconds, centre_from, centre_to, width=0.6):
    """Noise whose colour slides from one pitch to another: the heart of any whoosh."""
    n = int(SR * seconds)
    out = np.zeros(n)
    pieces = 24
    hop = n // pieces
    noise = rng.standard_normal(n + hop)
    window = np.hanning(hop * 2)
    for i in range(pieces - 1):
        k = i / (pieces - 2)
        centre = centre_from * (centre_to / centre_from) ** k
        seg = bandpass(noise, centre * (1 - width / 2), centre * (1 + width / 2))[i * hop : i * hop + hop * 2]
        out[i * hop : i * hop + hop * 2] += seg[: len(out[i * hop : i * hop + hop * 2])] * window[: len(out[i * hop : i * hop + hop * 2])]
    return out


def thud(seconds, f_from, f_to, tau):
    """A low drum-like knock that drops in pitch as it dies away."""
    n = int(SR * seconds)
    f = f_from * (f_to / f_from) ** (np.arange(n) / n)
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase) * env_decay(n, tau)


def place(parts, seconds):
    out = np.zeros(int(SR * seconds))
    for start, x, gain in parts:
        i = int(SR * start)
        x = x[: len(out) - i]
        out[i : i + len(x)] += x * gain
    return out


def chime():
    n = t(0.9)
    f0 = 1318.5
    x = np.zeros(len(n))
    for mult, gain, tau in [(1.0, 1.0, 0.28), (2.0, 0.45, 0.2), (3.0, 0.12, 0.12), (4.0, 0.3, 0.16), (5.4, 0.08, 0.07)]:
        x += gain * np.sin(2 * np.pi * f0 * mult * n) * np.exp(-n / tau)
    sparkle = highpass(rng.standard_normal(len(n)), 6000) * np.exp(-n / 0.03) * 0.25
    return fade(x + sparkle, 0.002, 0.05)


def shield():
    n = t(0.8)
    x = np.zeros(len(n))
    for mult, gain, tau in [(1.0, 1.0, 0.3), (1.5, 0.5, 0.25), (2.0, 0.5, 0.22), (2.99, 0.35, 0.15), (4.1, 0.2, 0.1)]:
        x += gain * np.sin(2 * np.pi * 660.0 * mult * n) * np.exp(-n / tau)
    x *= 1.0 + 0.3 * np.sin(2 * np.pi * 11.0 * n)
    knock = bandpass(rng.standard_normal(len(n)), 1500, 5000) * np.exp(-n / 0.012) * 0.8
    return fade(x + knock, 0.001, 0.06)


def swish():
    x = sweep_noise(0.2, 900, 4200, 0.7) * np.hanning(int(SR * 0.2)) ** 0.7
    return fade(x, 0.01, 0.03)


def whoosh():
    n = int(SR * 0.5)
    shape = np.hanning(n) ** 0.6
    shape[: n // 5] *= np.linspace(0.0, 1.0, n // 5)
    air = sweep_noise(0.5, 500, 2600, 0.8) * shape
    roar = bandpass(rng.standard_normal(n), 220, 900) * shape * 0.9
    foom = thud(0.5, 240, 110, 0.3) * shape * 0.5
    return fade(air * 1.3 + roar + foom, 0.01, 0.06)


def burst():
    n = int(SR * 0.45)
    noise = rng.standard_normal(n)
    bright = highpass(noise, 1500) * env_decay(n, 0.035)
    body = bandpass(noise, 280, 1900) * env_decay(n, 0.11)
    boom = thud(0.45, 300, 130, 0.08) * 0.45
    crackle = np.zeros(n)
    for _ in range(14):
        i = rng.integers(int(SR * 0.03), n - 400)
        crackle[i : i + 200] += highpass(rng.standard_normal(200), 3000) * np.hanning(200) * (1 - i / n) * 0.9
    return fade(bright * 0.7 + body * 1.2 + boom + crackle, 0.001, 0.05)


def hit():
    n = int(SR * 0.18)
    smack = bandpass(rng.standard_normal(n), 700, 2800) * env_decay(n, 0.018)
    return fade(smack * 1.3 + thud(0.18, 320, 140, 0.04) * 0.9, 0.001, 0.03)


def clop(variant):
    """A hoof coming down on turf: a soft, dull thud with a little grass in it.

    There is no note in it. Ground does not ring, and an earlier version that had a tone
    sounded like a woodblock. Every variant is a little different, as real steps are."""
    local = np.random.default_rng(40 + variant)
    seconds = 0.2
    n = int(SR * seconds)

    def level(x, peak):
        return x / (np.abs(x).max() + 1e-9) * peak

    centre = local.uniform(380, 620)
    # The thud: noise kept to the low middle, which small tablet speakers can still play.
    body = level(bandpass(local.standard_normal(n), centre * 0.55, centre * 1.7) * env_decay(n, local.uniform(0.018, 0.03)), 1.0)
    # Weight underneath, for headphones and bigger speakers.
    weight = thud(seconds, local.uniform(125, 160), 60, 0.035) * 0.45
    # The first touch of the hoof, kept soft.
    touch = level(bandpass(local.standard_normal(n), 1200, 3200) * env_decay(n, 0.004), local.uniform(0.16, 0.26))
    # Grass and earth giving way.
    grass = level(bandpass(local.standard_normal(n), 900, 4200) * env_decay(n, local.uniform(0.035, 0.06)), 0.1)
    return fade(lowpass(body + weight + touch + grass, 5000), 0.002, 0.05)


def voice_wave(folder, stem):
    """A recorded voice as plain numbers, one channel, at our sample rate."""
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", os.path.join(folder, stem + ".mp3"), "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"], capture_output=True, check=True).stdout
    wave = np.frombuffer(raw, dtype=np.float32).astype(np.float64)
    return wave / (np.abs(wave).max() + 1e-9)


def crowd(folder, seed, seconds, voices, claps):
    """A small crowd cheering: a handful of recorded cheers layered at different pitches and
    moments so four voices sound like more people, over a patter of clapping, all a little
    muffled as if heard from across a field."""
    local = np.random.default_rng(seed)
    n = int(SR * seconds)
    out = np.zeros(n)
    stems = ["c_kid", "c_man", "c_man2", "c_girl"]
    for k in range(voices):
        wave = voice_wave(folder, stems[(k + seed) % len(stems)])
        rate = local.uniform(0.86, 1.2)  # faster and higher, or slower and lower: another person
        wave = np.interp(np.arange(0, len(wave) - 1, rate), np.arange(len(wave)), wave)
        start = int(local.uniform(0.0, max(1.0, n - len(wave) * 0.7)))
        end = min(n, start + len(wave))
        out[start:end] += wave[: end - start] * local.uniform(0.3, 0.7)
    for _ in range(claps):
        length = int(SR * 0.05)
        clap = bandpass(local.standard_normal(length), local.uniform(800, 1300), local.uniform(2800, 3800)) * env_decay(length, local.uniform(0.005, 0.011))
        start = int(local.uniform(0, n - length))
        out[start:start + length] += clap / (np.abs(clap).max() + 1e-9) * local.uniform(0.08, 0.26)
    # It swells and dies away, and the far side of the field takes the edge off it.
    swell = np.minimum(1.0, np.arange(n) / (SR * 0.35)) * np.minimum(1.0, (n - np.arange(n)) / (SR * 0.9))
    out = lowpass(out * swell, 5200)
    for delay, share in [(0.07, 0.28), (0.15, 0.16)]:
        echo = np.zeros(n)
        shift = int(SR * delay)
        echo[shift:] = out[:-shift] * share
        out = out + echo
    return fade(out, 0.02, 0.3)


def land():
    first = clop(1)
    rng.standard_normal(2 * int(SR * 0.16))  # the old hoofbeat used these; keeps later effects unchanged
    heavy = thud(0.3, 260, 120, 0.05) * 0.55
    grass = bandpass(rng.standard_normal(int(SR * 0.3)), 300, 2500) * env_decay(int(SR * 0.3), 0.07) * 0.9
    return fade(place([(0.0, heavy, 1.0), (0.0, grass, 1.0), (0.07, first, 0.9), (0.15, first, 0.5)], 0.42), 0.001, 0.05)


def knock(freq, tau):
    n = int(SR * 0.14)
    x = np.zeros(n)
    for mult, gain in [(1.0, 1.0), (2.3, 0.5), (3.9, 0.3)]:
        x += gain * np.sin(2 * np.pi * freq * mult * np.arange(n) / SR) * env_decay(n, tau / mult ** 0.5)
    return x + bandpass(rng.standard_normal(n), 1500, 6000) * env_decay(n, 0.004) * 0.6


def clatter(seed):
    local = np.random.default_rng(seed)
    parts = []
    when = 0.0
    for i in range(7):
        parts.append((when, knock(local.uniform(420, 980), local.uniform(0.02, 0.045)), 1.0 * 0.78 ** i))
        when += local.uniform(0.035, 0.12)
    return fade(place(parts, when + 0.2), 0.001, 0.05)


def thump():
    n = int(SR * 0.3)
    soft = bandpass(rng.standard_normal(n), 320, 1500) * env_decay(n, 0.05)
    rustle = bandpass(rng.standard_normal(n), 2000, 6000) * env_decay(n, 0.06) * 0.3
    return fade(soft * 1.6 + thud(0.3, 240, 120, 0.05) * 0.35 + rustle, 0.002, 0.05)


def snort():
    n = int(SR * 0.55)
    air = bandpass(rng.standard_normal(n), 180, 3200)
    flutter = 0.35 + 0.65 * np.clip(np.sin(2 * np.pi * 27.0 * np.arange(n) / SR), 0.0, 1.0) ** 0.5
    shape = np.minimum(np.arange(n) / (SR * 0.02), 1.0) * env_decay(n, 0.16)
    return fade(air * flutter * shape + lowpass(rng.standard_normal(n), 300) * shape * 0.8, 0.003, 0.05)


def horn(freq, seconds):
    n = t(seconds)
    vib = 1.0 + 0.004 * np.sin(2 * np.pi * 5.5 * n) * np.minimum(n / 0.25, 1.0)
    phase = 2 * np.pi * np.cumsum(freq * vib) / SR
    x = sum(np.sin(phase * k) / k ** 1.25 for k in range(1, 9))
    shape = np.minimum(n / 0.02, 1.0) * np.exp(-n / (seconds * 1.6))
    bell = np.sin(phase * 2) * np.exp(-n / 0.25) * 0.5
    return fade(lowpass(x, 3600) * shape + bell, 0.004, 0.06)


def fanfare():
    c, e, g, c2 = 523.25, 659.25, 783.99, 1046.5
    parts = [(0.0, horn(c, 0.18), 0.8), (0.14, horn(e, 0.18), 0.8), (0.28, horn(g, 0.18), 0.8)]
    for note, gain in [(c2, 1.0), (g, 0.6), (e, 0.5), (c, 0.5)]:
        parts.append((0.44, horn(note, 1.1), gain * 0.6))
    return place(parts, 1.6)


def munch():
    """Three crunchy bites."""
    parts = []
    for i in range(3):
        n = int(SR * 0.11)
        bite = bandpass(rng.standard_normal(n), 700, 4200) * env_decay(n, 0.02)
        for _ in range(5):
            j = rng.integers(0, n - 120)
            bite[j : j + 120] += highpass(rng.standard_normal(120), 2000) * np.hanning(120) * 0.8
        parts.append((0.02 + i * 0.26, fade(bite, 0.002, 0.02), 1.0 - 0.12 * i))
    return place(parts, 0.8)


def brush():
    """One stroke of a stiff brush over a coat."""
    x = sweep_noise(0.28, 1800, 3600, 0.9) * np.hanning(int(SR * 0.28)) ** 0.5
    return fade(x, 0.02, 0.05)


def pop():
    """A soft rising blip, for hearts."""
    n = t(0.14)
    f = 520 * (980 / 520) ** (n / n[-1])
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-n / 0.06)
    return fade(x + 0.3 * np.sin(4 * np.pi * np.cumsum(f) / SR) * np.exp(-n / 0.04), 0.004, 0.03)


def squirt():
    """Toothpaste coming out of the tube."""
    n = int(SR * 0.22)
    x = sweep_noise(0.22, 2600, 900, 0.9) * np.hanning(n) ** 0.6
    wet = np.sin(2 * np.pi * np.cumsum(300 + 500 * np.linspace(1, 0, n)) / SR) * np.hanning(n) * 0.5
    return fade(x + wet, 0.01, 0.04)


def whinny_fallback():
    """Only used if no recorded whinny is supplied: a bright, falling, quavering call."""
    n = t(1.3)
    k = n / n[-1]
    f = 1500 * (520 / 1500) ** (k ** 1.3) + 220 * np.exp(-k * 9)
    f *= 1.0 + (0.03 + 0.07 * k) * np.sin(2 * np.pi * 13.0 * n)
    phase = 2 * np.pi * np.cumsum(f) / SR
    x = sum(np.sin(phase * h) / h for h in range(1, 6))
    shape = np.minimum(n / 0.04, 1.0) * (1 - k) ** 0.6
    return fade(x * shape + bandpass(rng.standard_normal(len(n)), 1500, 5000) * shape * 0.12, 0.004, 0.05)


def save(folder, name, x, peak=0.7):
    x = x / (np.abs(x).max() + 1e-9) * peak
    wav = os.path.join(folder, name + ".wav")
    wavfile.write(wav, SR, (x * 32767).astype(np.int16))
    ogg = os.path.join(folder, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", ogg], check=True)
    os.remove(wav)
    return name + ".ogg"


def voice(src, folder, name, pitch=1.0, speed=1.0, level=-17.0):
    """Trims the silence off both ends of a recording, evens out its loudness and saves it."""
    quiet = "silenceremove=start_periods=1:start_threshold=-42dB:start_silence=0.02"
    chain = [quiet, "areverse", quiet, "areverse"]
    if pitch != 1.0 or speed != 1.0:
        chain += ["aresample=%d" % SR, "asetrate=%d" % int(SR * pitch), "aresample=%d" % SR, "atempo=%.4f" % (speed / pitch)]
    chain += ["loudnorm=I=%.1f:TP=-1.5:LRA=11" % level, "afade=t=in:d=0.005", "aresample=%d" % SR]
    out = os.path.join(folder, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-ac", "1", "-af", ",".join(chain), "-c:a", "libvorbis", "-q:a", "4", out], check=True)
    return name + ".ogg"


MERLIN = [
    "Adeline! Thank goodness you're here.",
    "Goblins are causing trouble all over our island. They work for the ogre across the water.",
    "Pick a mission and I'll tell you what to do.",
    "The goblins are east of here, past the signpost.",
    "Watch what a goblin does before it attacks. It always gives itself away.",
    "You did it! The island is safe again.",
    "Here is your reward: the Magic Shield.",
    "Tap SHIELD just before an attack lands and it will bounce right off.",
    "Head east past the signpost and send those goblins packing.",
    "Your wand strikes fast up close. Your fireball hits three times as hard, but it needs a moment between casts.",
    "The ogre has locked your mother and father in his fort on the island across the water.",
    "Its gate only opens when two stones are pressed at the very same moment. Nobody can do that alone.",
    "Fetch your little sister. Then take the flying boat at the river.",
    "You brought them home! I never doubted the two of you for a moment.",
]

# name in the game -> the recordings (file stems) that can play for it
ADELINE = {
    "strike": ["a_hah", "a_hyah", "a_yah"],
    "hurt": ["a_ow", "a_oof"],
    "hup": ["a_hup"],
    "ride_jump": ["a_hup", "a_up_we_go"],
    "call": ["a_call"],
    "lets_go": ["a_lets_go"],
    "lets_ride": ["a_lets_ride"],
    "whoa": ["a_whoa"],
    "we_did_it": ["a_we_did_it"],
    "take_that": ["a_take_that"],
    "defeat": ["a_defeat"],
    "fireball": ["a_fireball"],
    "woohoo": ["a_woohoo"],
    "feed": ["a_feed"],
    "shiny": ["a_shiny"],
    "love": ["a_love"],
    "happy": ["a_happy"],
    "lovely": ["a_lovely", "a_like_it"],
    "goodnight": ["a_goodnight"],
    "brush_teeth": ["a_brush_teeth"],
    "all_clean": ["a_all_clean"],
}
SISTER = {
    "sister_hello": ["s_hi"],
    "sister_whee": ["s_whee", "s_look"],
    "sister_race": ["s_race"],
    "sister_love": ["s_love"],
    "sister_coming": ["s_coming"],
    "sister_charge": ["s_charge"],
    "sister_stay": ["s_stay"],
    "sister_family": ["s_family"],
    "sister_balloon": ["s_balloon"],
    "sister_again": ["s_again"],
    "sister_pretty": ["s_pretty"],
}
OGRE = {
    "ogre_roar": ["o_roar"],
    "ogre_hurt": ["o_hurt"],
    "ogre_down": ["o_down"],
}
GOBLIN = {
    "goblin_taunt": ["g_taunt", "g_nyeh"],
    "goblin_attack": ["g_graah", "g_rargh"],
    "goblin_hurt": ["g_ow", "g_eek"],
    "goblin_down": ["g_waah"],
}


def main():
    raw, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    sounds = {}
    lines = {}
    done = {}

    def recorded(stem, **how):
        if stem not in done:
            src = os.path.join(raw, stem + ".mp3")
            done[stem] = voice(src, out, stem, **how) if os.path.exists(src) else None
        return done[stem]

    for i, text in enumerate(MERLIN):
        file = recorded("merlin_%d" % i, level=-16.0)
        if file:
            lines[text] = file
    for name, stems in ADELINE.items():
        sounds[name] = [f for f in (recorded(s, level=-17.0) for s in stems) if f]
    for name, stems in SISTER.items():
        # The little sister is the same kind of voice pitched a little higher.
        sounds[name] = [f for f in (recorded(s, pitch=1.1, speed=1.0, level=-17.0) for s in stems) if f]
    for name, stems in OGRE.items():
        # The ogre is the goblin voice slowed and dropped a long way, so he sounds huge.
        sounds[name] = [f for f in (recorded(s, pitch=0.7, speed=0.92, level=-15.0) for s in stems) if f]
    for name, stems in GOBLIN.items():
        # Goblins are small and nasty: the recordings are pitched up and hurried a little.
        sounds[name] = [f for f in (recorded(s, pitch=1.32, speed=1.1, level=-18.0) for s in stems) if f]

    whinnies = [f for f in (recorded(s, level=-17.0) for s in ["whinny_a", "whinny_b"]) if f]
    sounds["whinny"] = whinnies or [save(out, "whinny", whinny_fallback())]

    sounds["chime"] = [save(out, "chime", chime(), 0.6)]
    sounds["shield"] = [save(out, "shield", shield(), 0.7)]
    sounds["swish"] = [save(out, "swish", swish(), 0.6)]
    sounds["whoosh"] = [save(out, "whoosh", whoosh(), 0.8)]
    sounds["burst"] = [save(out, "burst", burst(), 0.85)]
    sounds["hit"] = [save(out, "hit", hit(), 0.8)]
    sounds["clop"] = [save(out, "clop_%d" % v, clop(v), 0.6) for v in range(6)]
    sounds["crowd_cheer"] = [save(out, "crowd_%d" % v, crowd(raw, 11 + v, 2.9, 5, 60), 0.7) for v in range(3)]
    sounds["crowd_big"] = [save(out, "crowd_big", crowd(raw, 31, 4.6, 11, 190), 0.75)]
    sounds["clop_far"] = sounds["clop"]  # other horses: the same steps, limited separately
    rng.standard_normal(6 * int(SR * 0.16))  # the old hoofbeats used these; keeps later effects unchanged
    sounds["land"] = [save(out, "land", land(), 0.85)]
    sounds["clatter"] = [save(out, "clatter_%d" % v, clatter(40 + v), 0.75) for v in range(2)]
    sounds["thump"] = [save(out, "thump", thump(), 0.85)]
    sounds["snort"] = [save(out, "snort", snort(), 0.7)]
    sounds["fanfare"] = [save(out, "fanfare", fanfare(), 0.7)]
    sounds["munch"] = [save(out, "munch", munch(), 0.75)]
    sounds["brush"] = [save(out, "brush", brush(), 0.5)]
    sounds["pop"] = [save(out, "pop", pop(), 0.6)]
    sounds["squirt"] = [save(out, "squirt", squirt(), 0.55)]

    with open(os.path.join(out, "manifest.json"), "w") as f:
        json.dump({"sounds": sounds, "lines": lines}, f, indent=1)
    print("sounds:", {k: len(v) for k, v in sounds.items()})
    print("spoken lines:", len(lines))


main()
