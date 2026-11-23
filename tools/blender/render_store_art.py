"""Bausteine für die Store-Grafiken (Header, Suchergebnis), freigestellt.

Aufruf: Blender -b --python tools/blender/render_store_art.py
Ergebnis: assets_src/store/hero.png (Turm auf der Spielplattform mit fallendem
Stein und Drehpfeilen) und assets_src/store/cube_<farbe>.png (einzelne Würfel).
Zusammengesetzt werden die Grafiken von tool/store_creative.swift.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import fs_scene as fs

OUT = os.path.join(fs.ROOT, "assets_src", "store")
os.makedirs(OUT, exist_ok=True)

# Höhe je Feld; d = Abstand von der hinteren Ecke (i=0, j=4) zur vorderen.
STEPS = [4, 3, 3, 2, 2, 1, 1, 0, 0]
LOWER = {(2, 2), (4, 3), (1, 0)}       # kleine Lücken, damit es gebaut wirkt
COLORS = ["mint", "amber", "sky", "plum", "leaf", "block_cream", "rose"]


def tower():
    cubes = []
    for i in range(5):
        for j in range(5):
            h = STEPS[i + (4 - j)] - (1 if (i, j) in LOWER else 0)
            for k in range(max(h, 0)):
                # Farbe in Blöcken aus mehreren Würfeln, wie abgelegte Bausteine.
                c = COLORS[(i // 2 + 2 * ((j + 1) // 2) + 3 * k) % len(COLORS)]
                cubes.append((i, j, k, c))
    return cubes


# --- Turm ---------------------------------------------------------------
sc = fs.reset_scene()
cam = fs.setup_camera(sc, 2400, 2400, target=(0, 0, 3.3))
cam.data.ortho_scale = 13.8
fs.setup_light()
rig = fs.make_rig()
fs.add_platform(rig, with_marker=False)
for i, j, k, c in tower():
    fs.add_cube(c, fs.cell_center(i, j, k), rig)
# Fallender Stein (L aus drei Würfeln) über der Mitte.
for i, j in ((2, 2), (3, 2), (2, 1)):
    x, y, _ = fs.cell_center(i, j, 0)
    fs.add_cube("coral", (x, y, 8.0), rig, name="Falling")
# Drehpfeile um die Plattform.
fs.add_arrow("mint", 4.55, 0.42, 100, 120, -0.6, thick=0.12)
fs.add_arrow("mint", 4.55, 0.42, 280, 120, -0.6, thick=0.12)
fs.render(os.path.join(OUT, "hero.png"))

# --- Einzelne Würfel ------------------------------------------------------
for c in ["mint", "amber", "sky", "plum", "coral", "leaf", "block_cream"]:
    sc = fs.reset_scene()
    cam = fs.setup_camera(sc, 600, 600, target=(0, 0, 0))
    cam.data.ortho_scale = 2.0
    fs.setup_light()
    fs.add_cube(c, (0, 0, 0))
    fs.render(os.path.join(OUT, f"cube_{c}.png"))

print("STORE_ART_DONE")
