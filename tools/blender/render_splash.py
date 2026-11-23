"""Bilder für den animierten Startbildschirm, freigestellt und deckungsgleich.

Aufruf: Blender -b --python tools/blender/render_splash.py
Ergebnis in assets/ui/:
  splash_base.png   Plattform mit zwei Ebenen, vorn fehlt ein L aus drei Würfeln
  splash_piece.png  der fehlende Stein an seinem Zielplatz
  splash_final.png  alles zusammen, mit den richtigen Schatten
Alle drei haben dieselbe Kamera. Senkrecht im Bild heißt senkrecht in der
Welt, die App lässt den Stein also einfach von oben ins Bild fallen.
splash_base.png ist zugleich das native Startbild (LaunchImage).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import fs_scene as fs

OUT = os.path.join(fs.ROOT, "assets", "ui")

# Vorn im Bild liegt (+x, -y). (x, y, z, farbe)
BASE = [
    (-1, 1, 0, "mint"), (-1, 0, 0, "mint"), (0, 1, 0, "mint"),
    (1, 1, 0, "amber"), (1, 0, 0, "amber"), (0, 0, 0, "amber"),
    (-1, -1, 0, "plum"), (0, -1, 0, "plum"), (1, -1, 0, "plum"),
    (-1, 1, 1, "sky"), (0, 1, 1, "sky"), (1, 1, 1, "sky"),
    (-1, 0, 1, "block_cream"), (-1, -1, 1, "block_cream"), (0, 0, 1, "block_cream"),
]
PIECE = [(1, 0, 1, "coral"), (1, -1, 1, "coral"), (0, -1, 1, "coral")]


def scene(cubes, slab):
    sc = fs.reset_scene()
    cam = fs.setup_camera(sc, 900, 900, target=(0, 0, 0.95))
    cam.data.ortho_scale = 6.4
    fs.setup_light()
    rig = fs.make_rig()
    if slab:
        ob = bpy.data.objects.new(
            "Slab", fs.beveled_box_mesh("FS_Slab", 3.36, 3.36, 0.42, 0.08, 4))
        ob.data.materials.append(fs.material("M_navy", fs.CFG["colors"]["navy"], 0.6))
        ob.location = (0, 0, -0.21)
        fs.collection("Platform").objects.link(ob)
    for x, y, z, c in cubes:
        fs.add_cube(c, (x, y, z + 0.5), rig)


scene(BASE, True)
fs.render(os.path.join(OUT, "splash_base.png"))
scene(PIECE, False)
fs.render(os.path.join(OUT, "splash_piece.png"))
scene(BASE + PIECE, True)
fs.render(os.path.join(OUT, "splash_final.png"))
print("SPLASH_DONE")
