#!/usr/bin/env python3
"""Schneidet die Kurzvideos (1080×1920, 30 Bilder/s, ohne Ton).

Aufruf: python3 tool/tiktok_videos.py <ordner mit aufnahmen und ov/> <zielordner>
Die Aufnahmen kommen aus tool/record_gameplay.sh, die Textbilder aus
tool/tiktok_overlays.swift. Die Statusleiste oben und die Knöpfe unten werden
weggeschnitten, damit nur das Spiel zu sehen ist.
"""
import subprocess
import sys

SRC, OUT = sys.argv[1], sys.argv[2]
END = 2.6  # Dauer der Schlusskarte

# name: (Abschnitte [(datei, start, dauer, tempo)], Untertitel [(bild, von, bis)], Schlusskarte)
VIDEOS = {
    "flipstack_tiktok_1_regel": (
        [("a_default.mov", 8.3, 13.0, 1.0)],
        [("v1_a", 0.0, 2.7), ("v1_b", 2.7, 6.0), ("v1_c", 6.0, 9.3), ("v1_d", 9.3, 12.6)],
        "end_1",
    ),
    "flipstack_tiktok_2_combo": (
        [("b_neon.mov", 13.0, 25.6, 1.6)],
        [("v2_a", 0.0, 3.0), ("v2_b", 3.0, 6.8), ("v2_c", 6.8, 10.8), ("v2_d", 12.6, 15.6)],
        "end_2",
    ),
    "flipstack_tiktok_3_hoehe": (
        [("c_winter.mov", 3.5, 66.0, 5.5), ("c_winter.mov", 71.6, 3.2, 1.0)],
        [("v3_a", 0.0, 3.2), ("v3_b", 3.2, 7.4), ("v3_c", 7.4, 11.6), ("v3_d", 12.2, 15.0)],
        "end_3",
    ),
}

for name, (segments, captions, end) in VIDEOS.items():
    cmd = ["ffmpeg", "-y", "-loglevel", "error"]
    for f, *_ in segments:
        cmd += ["-i", f"{SRC}/{f}"]
    images = [c[0] for c in captions] + [end]
    for img in images:
        cmd += ["-loop", "1", "-framerate", "30", "-i", f"{SRC}/ov/{img}.png"]

    parts, length = [], 0.0
    for i, (_, start, dur, speed) in enumerate(segments):
        parts.append(
            f"[{i}:v]trim=start={start}:duration={dur},setpts=(PTS-STARTPTS)/{speed},"
            f"fps=30,scale=1100:-2,crop=1080:1920:10:132,setsar=1[s{i}]")
        length += dur / speed
    joined = "".join(f"[s{i}]" for i in range(len(segments)))
    # letztes Bild stehen lassen, darüber blendet die Schlusskarte ein
    parts.append(f"{joined}concat=n={len(segments)}:v=1:a=0,"
                 f"tpad=stop_mode=clone:stop_duration={END}[v0]")
    n = len(segments)
    cur = "v0"
    for k, (_, a, b) in enumerate(captions):
        parts.append(f"[{n + k}:v]format=rgba,fade=t=in:st={a}:d=0.18:alpha=1,"
                     f"fade=t=out:st={b - 0.18}:d=0.18:alpha=1[c{k}]")
        parts.append(f"[{cur}][c{k}]overlay=enable='between(t,{a},{b})'[v{k + 1}]")
        cur = f"v{k + 1}"
    e = n + len(captions)
    parts.append(f"[{e}:v]format=rgba,fade=t=in:st={length}:d=0.35:alpha=1[e]")
    parts.append(f"[{cur}][e]overlay=enable='gte(t,{length})',format=yuv420p[out]")
    total = length + END
    cmd += ["-filter_complex", ";".join(parts), "-map", "[out]", "-t", f"{total:.2f}",
            "-r", "30", "-c:v", "libx264", "-preset", "slow", "-crf", "18",
            "-movflags", "+faststart", "-an", f"{OUT}/{name}.mp4"]
    subprocess.run(cmd, check=True)
    print(f"{name}.mp4  {total:.1f} s")
