"""Rendert die Münze für die Oberfläche.

Aufruf: Blender -b --python tools/blender/render_coin.py
Ergebnis (assets/ui/):
  coin.png        144 px, für grosse Darstellung
  coin_small.png   60 px, vereinfachte Prägung für 16–20 pt

Licht und Material folgen den Würfeln (fs_scene). Die Kamera blickt leicht
geneigt auf die liegende Münze, damit unten die Kante sichtbar ist.
"""
import math
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import bmesh
from mathutils import Euler, Vector
import fs_scene as fs

OUT = os.path.join(fs.ROOT, "assets", "ui")
TMP = os.path.join(fs.ROOT, "build", "sprites_tmp")
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)

TILT = math.radians(34)  # Neigung der Blickachse gegen die Münzachse
THICK = 0.36
BODY, FIELD, MARK = "#E6A22F", "#C07E1C", "#F5C95F"


def mat(name, hex_color):
    m = fs.material(name, hex_color, 0.42)
    b = m.node_tree.nodes["Principled BSDF"]
    for spec in ("Specular IOR Level", "Specular"):
        if spec in b.inputs:
            b.inputs[spec].default_value = 0.45
            break
    return m


def disc(name, radius, depth, z, material, bevel):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=96, radius1=radius,
                          radius2=radius, depth=depth)
    rim = [e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-6]
    bmesh.ops.bevel(bm, geom=rim, offset=bevel, segments=4, profile=0.5,
                    affect="EDGES")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.set_sharp_from_angle(angle=math.radians(40))
    ob = bpy.data.objects.new(name, me)
    ob.data.materials.append(material)
    ob.location = (0, 0, z)
    fs.collection("Coin").objects.link(ob)
    return ob


def render_coin(path, px, rim, mark, mark_h):
    sc = fs.reset_scene()
    fs.setup_light()
    cam = bpy.data.cameras.new("Coin_Camera")
    cam.type = "ORTHO"
    cam.ortho_scale = 2.42
    ob = bpy.data.objects.new("Coin_Camera", cam)
    rot = Euler((TILT, 0, 0))
    ob.rotation_euler = rot
    ob.location = Vector((0, 0, -0.05)) + rot.to_matrix() @ Vector((0, 0, 40))
    fs.collection("Camera_Light").objects.link(ob)
    sc.camera = ob
    sc.render.resolution_x = sc.render.resolution_y = px
    sc.render.resolution_percentage = 100

    top = THICK / 2
    disc("Coin_Body", 1.0, THICK, 0, mat("M_coin", BODY), 0.075)
    # dunkleres Feld und erhabener Randwulst
    disc("Coin_Field", 1.0 - rim, 0.02, top + 0.004, mat("M_coin_field", FIELD), 0.008)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.0 - rim / 2 - 0.02, minor_radius=rim / 2,
        major_segments=96, minor_segments=16, location=(0, 0, top - rim * 0.18))
    ring = bpy.context.active_object
    ring.name = "Coin_Rim"
    ring.scale.z = 0.55
    ring.data.materials.append(mat("M_coin", BODY))
    for p in ring.data.polygons:
        p.use_smooth = True
    # Prägung: die Würfel-Oberseite als Raute
    box = bpy.data.objects.new(
        "Coin_Mark", fs.beveled_box_mesh("Coin_Mark", mark, mark, mark_h, 0.03, 3))
    box.data.materials.append(mat("M_coin_mark", MARK))
    box.rotation_euler = (0, 0, math.radians(45))
    box.location = (0, 0, top + mark_h / 2)
    fs.collection("Coin").objects.link(box)
    fs.render(path)


def scale(src, dst, px):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-vf",
                    f"scale={px}:{px}:flags=lanczos", dst], check=True)


big, small = os.path.join(TMP, "coin_big.png"), os.path.join(TMP, "coin_small.png")
render_coin(big, 576, rim=0.17, mark=0.62, mark_h=0.08)
render_coin(small, 480, rim=0.22, mark=0.70, mark_h=0.10)
scale(big, os.path.join(OUT, "coin.png"), 144)
scale(small, os.path.join(OUT, "coin_small.png"), 60)
print("COIN_DONE", OUT)
