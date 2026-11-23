#!/usr/bin/env python3
"""Schneidet das App-Store-Vorschauvideo (App Preview) je Sprache.

Apples Vorgaben: 886×1920, 15–30 s, H.264 High 4.0, 30 Bilder/s, 10–12 Mbit/s,
Stereoton AAC 256 kbit/s. Gezeigt wird nur die App selbst; der Schluss ist der
Startbildschirm der App. Der Ton ist eine stille Stereospur.
Aufruf: python3 tool/app_preview.py <ordner mit aufnahmen und ov/> <zielordner>
"""
import subprocess
import sys

SRC, OUT = sys.argv[1], sys.argv[2]
# (aufnahme, start, dauer, tempo)
SEGMENTS = [("a", 6.0, 8.0, 1.0), ("b", 14.0, 10.5, 1.5), ("c", 6.0, 42.0, 7.0), ("m", 2.3, 6.4, 1.0)]
CAPTIONS = [(1, 0.3, 7.6), (2, 8.2, 14.6), (3, 15.2, 20.6)]

for lang in ("de", "en"):
    cmd = ["ffmpeg", "-y", "-loglevel", "error"]
    for f, *_ in SEGMENTS:
        cmd += ["-i", f"{SRC}/{f}_{lang}.mov"]
    for k, *_ in CAPTIONS:
        cmd += ["-loop", "1", "-framerate", "30", "-i", f"{SRC}/ov/{lang}_{k}.png"]
    cmd += ["-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=44100"]
    parts, total = [], 0.0
    for i, (_, start, dur, speed) in enumerate(SEGMENTS):
        parts.append(f"[{i}:v]trim=start={start}:duration={dur},setpts=(PTS-STARTPTS)/{speed},"
                     f"fps=30,scale=886:-2,crop=886:1920,setsar=1[s{i}]")
        total += dur / speed
    n = len(SEGMENTS)
    parts.append("".join(f"[s{i}]" for i in range(n)) + f"concat=n={n}:v=1:a=0[v0]")
    cur = "v0"
    for k, (_, a, b) in enumerate(CAPTIONS):
        parts.append(f"[{n + k}:v]format=rgba,fade=t=in:st={a}:d=0.2:alpha=1,"
                     f"fade=t=out:st={b - 0.2}:d=0.2:alpha=1[c{k}]")
        parts.append(f"[{cur}][c{k}]overlay=enable='between(t,{a},{b})'[v{k + 1}]")
        cur = f"v{k + 1}"
    parts.append(f"[{cur}]format=yuv420p[out]")
    name = f"{OUT}/flipstack_app_preview_{lang}.mp4"
    cmd += ["-filter_complex", ";".join(parts), "-map", "[out]", "-map", f"{n + len(CAPTIONS)}:a",
            "-t", f"{total:.2f}", "-r", "30", "-c:v", "libx264", "-profile:v", "high",
            "-level", "4.0", "-b:v", "10M", "-maxrate", "12M", "-bufsize", "20M",
            "-c:a", "aac", "-b:a", "256k", "-ar", "44100", "-ac", "2",
            "-movflags", "+faststart", name]
    subprocess.run(cmd, check=True)
    print(name, f"{total:.1f} s")
