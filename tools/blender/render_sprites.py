"""Rendert alle Sprites für die Sprite-Komposition (Option C1).

Aufruf: Blender -b --python tools/blender/render_sprites.py
Ergebnis (assets/sprites/):
  cube_<farbe>.png   Atlas 6×5, Winkel 0..87° in 3°-Schritten (90° ≡ 0° wegen Symmetrie)
  tile_marker.png    Atlas 6×5, Eck-Markierung
  platform_still.png Plattform bei 0° in voller Auflösung
  platform_XXX.png   Plattform ohne Markierung, 0..87°, halbe Auflösung
  sprites.json       Metadaten (ppu, Kachelgrössen, Ankerpunkte)
"""
import json
import math
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import fs_scene as fs

OUT = os.path.join(fs.ROOT, "assets", "sprites")
TMP = os.path.join(fs.ROOT, "build", "sprites_tmp")
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)
STEP = fs.CFG["angle_step_deg"]
ANGLES = list(range(0, 90, STEP))
COLS = 6
ROWS = math.ceil(len(ANGLES) / COLS)


def fresh(w, h, target):
    sc = fs.reset_scene()
    fs.setup_camera(sc, w, h, target)
    fs.setup_light()
    return sc


def atlas(prefix, out_name):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-start_number", "0",
                    "-i", os.path.join(TMP, prefix + "_%03d.png"),
                    "-vf", f"tile={COLS}x{ROWS}", "-frames:v", "1",
                    os.path.join(OUT, out_name)], check=True)


def render_set(prefix, ob):
    for n, a in enumerate(ANGLES):
        ob.rotation_euler = (0, 0, math.radians(a))
        fs.render(os.path.join(TMP, f"{prefix}_{n:03d}.png"))


CUBE_PX = 256
for color in fs.CFG["cube_colors"]:
    fresh(CUBE_PX, CUBE_PX, (0, 0, 0))
    render_set(f"cube_{color}", fs.add_cube(color))
    atlas(f"cube_{color}", f"cube_{color}.png")

TILE_W, TILE_H = 192, 128
fresh(TILE_W, TILE_H, (0, 0, -fs.TILE_H / 2))
n = fs.CFG["grid"]
t = fs.add_tile((n - 1) // 2, (n - 1) // 2, "coral", fs.CFG["colors"]["coral"])
t.location = (0, 0, -fs.TILE_H / 2)
render_set("tile_marker", t)
atlas("tile_marker", "tile_marker.png")

PLAT_W, PLAT_H = 1024, 640
PLAT_TARGET_Z = -0.3
fresh(PLAT_W, PLAT_H, (0, 0, PLAT_TARGET_Z))
rig = fs.make_rig()
fs.add_platform(rig, with_marker=False)
# Standbild in voller Auflösung, Drehbilder in halber (spart ca. 75 % Bildspeicher;
# während der 0,3 s Drehung ist der Unterschied nicht sichtbar).
sc = bpy.context.scene
rig.rotation_euler = (0, 0, 0)
fs.render(os.path.join(OUT, "platform_still.png"))
sc.render.resolution_percentage = 50
for k, a in enumerate(ANGLES):
    rig.rotation_euler = (0, 0, math.radians(a))
    fs.render(os.path.join(OUT, f"platform_{k:03d}.png"))

tilt = math.radians(fs.CFG["camera"]["tilt_deg"])
meta = {
    "ppu": fs.CFG["ppu"],
    "tiltDeg": fs.CFG["camera"]["tilt_deg"],
    "angleStepDeg": STEP,
    "frames": len(ANGLES),
    "atlasCols": COLS,
    "cube": {"w": CUBE_PX, "h": CUBE_PX, "colors": fs.CFG["cube_colors"],
             "hex": [fs.CFG["colors"][c] for c in fs.CFG["cube_colors"]]},
    "tile": {"w": TILE_W, "h": TILE_H, "centerZ": -fs.TILE_H / 2},
    # Bildmitte der Plattform-Sprites entspricht Weltpunkt (0, 0, targetZ)
    "platform": {"w": PLAT_W, "h": PLAT_H, "targetZ": PLAT_TARGET_Z, "frameScale": 0.5},
    "sunDir": fs.CFG["sun"]["dir"],
}
json.dump(meta, open(os.path.join(OUT, "sprites.json"), "w"), indent=2)
print("SPRITES_DONE")
