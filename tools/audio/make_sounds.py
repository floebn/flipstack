"""Erzeugt alle Spielklänge durch Synthese (keine fremden Aufnahmen, keine Lizenzfragen).

Aufruf: python3 tools/audio/make_sounds.py
Ergebnis: assets/audio/*.wav (44,1 kHz, 16 Bit, mono)

Klangidee: weiche, kurze, holzige Töne (Marimba-artig) in C-Dur-Pentatonik,
dumpfe Aufschläge, leises Rauschen für Bewegung. Nichts Schrilles.
"""
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "assets", "audio")
RNG = np.random.default_rng(7)


def t(dur):
    return np.arange(int(SR * dur)) / SR


def fade(x, a=0.004, r=0.02):
    n = len(x)
    env = np.ones(n)
    na, nr = max(1, int(SR * a)), max(1, int(SR * r))
    env[:na] = np.linspace(0, 1, na)
    env[-nr:] *= np.linspace(1, 0, nr)
    return x * env


def note(freq, dur=0.45, decay=9.0, bright=0.35):
    """Marimba-artiger Ton: Grundton + 4. Teilton, der schnell verklingt."""
    x = t(dur)
    y = np.sin(2 * np.pi * freq * x) * np.exp(-decay * x)
    y += bright * np.sin(2 * np.pi * freq * 4 * x) * np.exp(-decay * 3.5 * x)
    y += 0.12 * np.sin(2 * np.pi * freq * 2 * x) * np.exp(-decay * 1.5 * x)
    return fade(y, 0.002, 0.03)


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def noise(dur, cutoff):
    # zweifach gefiltert: weich, ohne Zischen
    return lowpass(lowpass(RNG.standard_normal(int(SR * dur)), cutoff), cutoff)


def sweep(f0, f1, dur, decay=6.0):
    x = t(dur)
    f = f0 + (f1 - f0) * (x / dur)
    phase = 2 * np.pi * np.cumsum(f) / SR
    return fade(np.sin(phase) * np.exp(-decay * x), 0.005, 0.03)


def mix(parts, total=None):
    """parts: Liste (startzeit, signal)."""
    n = total and int(SR * total) or max(int(SR * s) + len(y) for s, y in parts)
    out = np.zeros(n)
    for s, y in parts:
        i = int(SR * s)
        out[i:i + len(y)] += y[: n - i]
    return out


def save(name, y, peak=0.7):
    y = y / (np.max(np.abs(y)) + 1e-9) * peak
    data = (y * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{name:12s} {len(y) / SR:5.2f} s  {len(data) * 2 / 1024:6.1f} KB")


C4, D4, E4, G4, A4 = 261.63, 293.66, 329.63, 392.00, 440.00
C5, D5, E5, G5, A5, C6, E6 = 523.25, 587.33, 659.25, 783.99, 880.00, 1046.5, 1318.5

os.makedirs(OUT, exist_ok=True)

# Baustein erscheint: kurzer, heller Tupfer
save("spawn", note(G5, 0.16, 22, 0.2), 0.32)
# Baustein wird bewegt: sehr kurzes, weiches Ticken
save("move", fade(np.sin(2 * np.pi * 1150 * t(0.028)) * np.exp(-150 * t(0.028)), 0.001, 0.008), 0.26)
# Baustein fällt: leises, abfallendes Hauchen
save("drop", sweep(520, 230, 0.16, 9) * 0.6 + fade(noise(0.16, 1400), 0.01, 0.08) * 0.25, 0.3)
# Aufprall: dumpfer Holzschlag
thud = np.sin(2 * np.pi * (118 - 40 * t(0.22)) * t(0.22)) * np.exp(-26 * t(0.22))
save("land", mix([(0, fade(thud, 0.001, 0.05)), (0, fade(noise(0.045, 2600), 0.0005, 0.03) * 0.5),
                  (0, note(C4, 0.2, 30, 0.1) * 0.25)]), 0.72)
# Plattform dreht sich: weiches Gleiten
x = t(0.30)
glide = fade(noise(0.30, 900) * np.sin(np.pi * x / 0.30) ** 2, 0.02, 0.08)
save("rotate", glide * 0.8 + sweep(240, 330, 0.30, 5) * 0.35, 0.36)
# Ungültig: zwei tiefe, gedämpfte Töne
save("invalid", mix([(0, note(196, 0.14, 26, 0.05)), (0.085, note(174.6, 0.2, 20, 0.05))]), 0.42)
# Combo: aufsteigende Tonleiter, ein Ton je Stufe
for i, f in enumerate([C5, D5, E5, G5, A5, C6, D5 * 2, E6]):
    save(f"combo_{i + 1}", note(f, 0.42, 9.5, 0.3), 0.46)
# Volle Ebene: zwei helle Töne
save("layer", mix([(0, note(E5, 0.5, 7)), (0.09, note(A5, 0.6, 6))]), 0.5)
# Höhenmeilenstein: Dreiklang nach oben
save("milestone", mix([(0, note(C5, 0.5, 7)), (0.1, note(E5, 0.5, 7)), (0.2, note(G5, 0.7, 5))]), 0.52)
# Neuer Bestwert: aufsteigende Folge mit Ausklang
save("highscore", mix([(0, note(C5, 0.5, 6)), (0.11, note(E5, 0.5, 6)), (0.22, note(G5, 0.5, 6)),
                       (0.33, note(C6, 1.0, 3.5)), (0.33, note(E6, 0.9, 5) * 0.4)]), 0.55)
# Spielende: zwei ruhige, absteigende Töne
save("gameover", mix([(0, note(G4, 0.7, 4.5, 0.15)), (0.24, note(C4, 1.1, 3.2, 0.15))]), 0.5)
# Belohnung freigeschaltet (ab Phase 5 genutzt)
save("reward", mix([(0, note(G5, 0.4, 8)), (0.08, note(C6, 0.5, 7)), (0.16, note(E6, 0.9, 4))]), 0.5)
# Knopf in der Oberfläche
save("tap", note(A5, 0.07, 55, 0.1), 0.22)
