"""Render the original NEON RIFT sound bank. Python 3 + NumPy, offline."""
from pathlib import Path
import wave
import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RNG = np.random.default_rng(70607)


def time(seconds):
    return np.arange(round(RATE * seconds), dtype=np.float64) / RATE


def write(name, samples):
    samples = np.asarray(samples)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as track:
        track.setparams((1 if samples.ndim == 1 else 2, 2, RATE, 0, "NONE", "not compressed"))
        track.writeframes((np.clip(samples, -0.96, 0.96) * 32767).astype("<i2").tobytes())


def voice(seconds, start, end, gain, color=0.20, noise=0.0, attack=0.006):
    t = time(seconds)
    theta = 2 * np.pi * (start * t + (end - start) * t * t / (2 * seconds))
    signal = np.sin(theta) + color * np.sin(theta * 2.005) + color * 0.27 * np.sin(theta * 3.02)
    if noise:
        grain = RNG.normal(0.0, 0.75, len(t))
        signal += noise * (grain + np.roll(grain, 1) * 0.55)
    env = np.minimum(t / attack, 1.0) * (np.maximum(0.0, 1.0 - t / seconds) ** 2.5)
    return gain * signal * env


def layered(name, ingredients):
    size = max(offset + len(signal) / RATE for offset, signal in ingredients) + 0.01
    result = np.zeros(round(size * RATE))
    for offset, signal in ingredients:
        pos = round(offset * RATE)
        result[pos:pos + len(signal)] += signal
    write(name, result)


def fx(name, *parts):
    layered(name, [(offset, voice(*values)) for offset, *values in parts])


def tune(name, notes, beat, gain):
    layered(name, [(beat * i, voice(0.38, pitch, pitch * 1.005, gain, 0.15, 0.01, 0.012))
                   for i, pitch in enumerate(notes)])


def make_effects():
    fx("pulse", (0, .17, 750, 127, .33, .19, .46), (0, .09, 170, 57, .33, .25, .13))
    fx("volt", (0, .28, 249, 48, .45, .48, .74), (.032, .12, 1900, 222, .19, .4, .68))
    fx("prism", (0, .15, 930, 168, .35, .57, .13), (.011, .16, 403, 89, .22, .1, .22))
    fx("nova", (0, .49, 169, 30, .47, .31, .61), (.043, .38, 434, 81, .32, .6, .03))
    fx("nova_impact", (0, .52, 106, 36, .52, .46, .72), (.013, .28, 1170, 163, .19, .1, .35))
    fx("charge_up", (0, .89, 94, 590, .23, .41, .06, .082), (.10, .72, 184, 1010, .12, .16))
    fx("reload", (0, .24, 306, 78, .21, .38, .28), (.14, .28, 106, 350, .14, .33, .09))
    tune("charged", [490, 740], .072, .20)
    tune("low", [665, 431], .11, .16)
    fx("switch", (0, .16, 265, 90, .16, .46, .32))
    fx("hit", (0, .087, 1080, 435, .18, .09, .42))
    fx("armor", (0, .16, 1230, 380, .22, .63, .26), (.027, .14, 1900, 244, .11, .24))
    fx("shield", (0, .20, 680, 162, .27, .38, .19))
    fx("break", (0, .30, 1200, 147, .23, .48, .8), (.055, .32, 230, 57, .22, .40))
    fx("hull", (0, .26, 210, 53, .41, .21, .38))
    fx("enemy", (0, .18, 427, 176, .26, .45, .08))
    fx("heavy", (0, .34, 278, 78, .34, .41, .20), (.018, .24, 480, 113, .17, .5))
    fx("slash", (0, .21, 840, 161, .24, .10, .73))
    fx("tell", (0, .20, 440, 640, .18, .19), (.12, .15, 710, 950, .18, .18))
    fx("kill", (0, .22, 492, 112, .25, .36, .45), (.06, .19, 720, 234, .14, .22, .16))
    fx("jump", (0, .19, 170, 320, .11, .11, .19))
    fx("land", (0, .16, 152, 55, .17, .31, .31))
    fx("slide", (0, .38, 197, 57, .16, .21, 1.12))
    fx("click", (0, .12, 520, 260, .12, .08, .18))
    tune("pickup", [330, 495, 660], .063, .22)
    tune("upgrade", [262, 392, 523, 784], .075, .21)
    tune("wave", [175, 262, 349], .10, .23)
    tune("phase", [190, 240, 315, 408], .082, .26)
    tune("boss", [140, 106, 84], .13, .30)
    fx("wave_hit", (0, .67, 93, 27, .57, .46, .41), (.03, .35, 260, 62, .20, .20, .61))
    tune("win", [262, 330, 392, 523, 659, 784], .13, .25)
    tune("loss", [294, 247, 196, 147], .18, .21)


def make_uprising_effects():
    fx("rail", (0, .13, 1850, 270, .44, .26, .31), (.028, .38, 155, 73, .23, .19))
    fx("lance", (0, .32, 880, 1820, .32, .37), (.012, .43, 185, 45, .42, .26, .19))
    fx("ion", (0, .075, 503, 865, .28, .22, .45), (.015, .09, 1120, 648, .13, .17))
    fx("mortar", (0, .24, 143, 85, .37, .31, .27), (.023, .28, 385, 264, .17, .27))
    fx("boost", (0, .22, 290, 910, .24, .24, .32), (.034, .18, 790, 520, .16, .19))
    fx("repair", (0, .2, 485, 620, .19, .21), (.08, .22, 729, 802, .17, .24))


def cycle_mix(track, signal, offset, pan=0.0):
    indices = (np.arange(len(signal)) + round(offset * RATE)) % len(track)
    track[indices, 0] += signal * (1.0 - pan) * .65
    track[indices, 1] += signal * (1.0 + pan) * .65


def make_loops():
    t = time(8.0)
    hum = (.05 * np.sin(2 * np.pi * 48 * t) + .027 * np.sin(2 * np.pi * 60 * t)) \
        * (.72 + .18 * np.sin(2 * np.pi * .25 * t))
    hiss = .008 * np.sin(2 * np.pi * 373.25 * t) * np.sin(2 * np.pi * .75 * t) ** 2
    write("reactor", np.column_stack((hum + hiss, hum - hiss)))
    for name, beat, action in [("menu", .52, False), ("combat", .42, True)]:
        track = np.zeros((round(32 * beat * RATE), 2))
        progression = [(130.81, 155.56, 196.0, 293.66), (103.83, 130.81, 155.56, 233.08),
                       (116.54, 146.83, 174.61, 261.63), (98, 130.81, 155.56, 220.0)]
        for bar, chord in enumerate(progression):
            for j, pitch in enumerate(chord):
                pad = voice(beat * 10, pitch, pitch * 1.001, .078, .086, 0, .38)
                cycle_mix(track, pad, bar * beat * 8 + j * .012, [-.51, -.21, .26, .54][j])
            for j in range(8):
                idx = (j * 3 + (1 if j % 2 else 0)) % 4
                pitch = chord[idx] * (4 if j % 4 == 3 else 2)
                cycle_mix(track, voice(.51, pitch, pitch * .995, .055, .16), (bar * 8 + j) * beat,
                          -.33 if j % 2 else .33)
                if action:
                    cycle_mix(track, voice(.22, chord[0] / 2, chord[0] / 2, .13, .37), (bar * 8 + j) * beat)
                    if j % 4 in (0, 2):
                        cycle_mix(track, voice(.27, 118, 41, .30, .13, .06), (bar * 8 + j) * beat)
                    cycle_mix(track, voice(.105, 2200, 330, .047, .19, .8), (bar * 8 + j + .52) * beat, .29)
        write(name, track)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    make_effects()
    make_loops()

if __name__ == '__main__':
    make_uprising_effects()
