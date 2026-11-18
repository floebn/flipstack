"""Referenz („Zielbild“) der Plattformrotation: echte 3D-Szene mit echten Schatten.

Aufruf: Blender -b --python tools/blender/render_reference.py
Ergebnis: assets_src/reference/ref_XXX.png (0..90° in 5°-Schritten) + ref_scene.blend
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import fs_scene as fs

OUT = os.path.join(fs.ROOT, "assets_src", "reference")
os.makedirs(OUT, exist_ok=True)

# kleiner Testturm: (i, j, k, farbe)
TOWER = [
    (1, 1, 0, "mint"), (2, 1, 0, "mint"), (1, 2, 0, "mint"),          # L
    (3, 3, 0, "coral"), (3, 2, 0, "coral"),                            # Doppel
    (1, 1, 1, "amber"), (1, 2, 1, "amber"), (2, 2, 1, "amber"),        # L auf Ebene 1
    (2, 2, 0, "cream"),
    (1, 1, 2, "coral"),
    (4, 0, 0, "amber"),
    (0, 4, 0, "cream"), (0, 4, 1, "mint"),
]

sc = fs.reset_scene()
sc.render.film_transparent = False
bg = sc.world.node_tree.nodes["Background"]
fs.setup_camera(sc, 1024, 1024, target=(0, 0, 1.0))
fs.setup_light()
rig = fs.make_rig()
fs.add_platform(rig)
for i, j, k, c in TOWER:
    fs.add_cube(c, fs.cell_center(i, j, k), rig)

# Hintergrund für die Referenz: Kamera sieht die Welt -> eigene Farbe nur für Kamera-Strahlen
nt = sc.world.node_tree
lp = nt.nodes.new("ShaderNodeLightPath")
bg2 = nt.nodes.new("ShaderNodeBackground")
bg2.inputs[0].default_value = fs.hex_rgba("#EFE6D6")
bg2.inputs[1].default_value = 1.0
mix = nt.nodes.new("ShaderNodeMixShader")
nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
nt.links.new(bg.outputs[0], mix.inputs[1])
nt.links.new(bg2.outputs[0], mix.inputs[2])
nt.links.new(mix.outputs[0], nt.nodes["World Output"].inputs["Surface"])

angles = [int(a) for a in os.environ.get("FS_ANGLES", "").split(",") if a] or range(0, 91, 5)
for a in angles:
    rig.rotation_euler = (0, 0, math.radians(a))
    fs.render(os.path.join(OUT, f"ref_{a:03d}.png"))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "ref_scene.blend"))
print("REFERENCE_DONE")
