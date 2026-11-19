"""Rendert die freischaltbaren Plattformen als eigene Sprite-Sätze.

Aufruf: Blender -b --python tools/blender/render_platforms.py
        (FS_ONLY=oak,island rendert nur einzelne)
Ergebnis je Plattform <id> (assets/sprites/):
  platform_<id>_still.png  Ruhebild in voller Auflösung
  platform_<id>_NNN.png    Drehbilder 0..87° in halber Auflösung
dazu assets/sprites/platforms.json (Bildmitte je Plattform) und ein
Vorschaubild assets/ui/plat_<id>.png für den Shop.

Regeln: Oberseite der Kacheln bei z = 0, 5×5-Raster wie bei der
Standardplattform, alles um die Hochachse vierfach symmetrisch (die Drehbilder
werden für jede Vierteldrehung wiederverwendet). Details sind Geometrie,
keine Texturen.
"""
import json
import math
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import bmesh
import fs_scene as fs

OUT = os.path.join(fs.ROOT, "assets", "sprites")
UI = os.path.join(fs.ROOT, "assets", "ui")
os.makedirs(UI, exist_ok=True)
STEP = fs.CFG["angle_step_deg"]
ANGLES = list(range(0, 90, STEP))
N = fs.CFG["grid"]
SIZE = N + 2 * fs.BASE_MARGIN
TOP = -fs.TILE_H * 0.6  # Oberkante des Sockels unter den Kacheln
PPU = fs.CFG["ppu"]
ZPX = PPU * math.sin(math.radians(fs.CFG["camera"]["tilt_deg"]))  # Pixel je Höhe
WIDTH = 1024
DIAMOND_H = SIZE * math.sqrt(2) * PPU * math.cos(math.radians(fs.CFG["camera"]["tilt_deg"]))


def mat(name, hex_color, rough=0.65):
    return fs.material("P_" + name, hex_color, rough)


def link(ob, parent):
    ob.parent = parent
    fs.collection("Platform").objects.link(ob)
    return ob


def box(name, sx, sy, sz, z_top, m, parent, bevel=0.06, seg=3, flat=False, xy=(0, 0)):
    me = fs.beveled_box_mesh(name, sx, sy, sz, bevel, seg)
    if flat:
        for p in me.polygons:
            p.use_smooth = False
    ob = bpy.data.objects.new(name, me)
    ob.data.materials.append(m)
    ob.location = (xy[0], xy[1], z_top - sz / 2)
    return link(ob, parent)


def frustum(name, half_top, half_bottom, height, z_top, m, parent):
    """Umgekehrter Pyramidenstumpf mit quadratischem Querschnitt, hart facettiert."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=4,
                          radius1=max(half_bottom, 0.001) * math.sqrt(2),
                          radius2=half_top * math.sqrt(2), depth=height)
    bmesh.ops.rotate(bm, verts=bm.verts[:], cent=(0, 0, 0),
                     matrix=__import__("mathutils").Matrix.Rotation(math.radians(45), 3, "Z"))
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.data.materials.append(m)
    ob.location = (0, 0, z_top - height / 2)
    return link(ob, parent)


def tiles(parent, color_a, color_b=None, rough=0.7):
    for i in range(N):
        for j in range(N):
            c = color_b if color_b and (i + j) % 2 else color_a
            ob = bpy.data.objects.new(f"Tile_{i}_{j}", fs.tile_mesh().copy())
            ob.data.materials.append(mat("tile_" + c, c, rough))
            ob.location = (i - (N - 1) / 2, j - (N - 1) / 2, -fs.TILE_H / 2)
            link(ob, parent)


def oak(r):
    """Eiche: Parkett aus zwei Holztönen, dunkler Rahmen, Messingecken."""
    box("Base", SIZE, SIZE, 0.5, TOP, mat("oak_dark", "#8A5C3A"), r, 0.07, 4)
    box("Foot", SIZE - 0.84, SIZE - 0.84, 0.26, TOP - 0.48, mat("oak_foot", "#4A3121"), r, 0.05)
    tiles(r, "#D6AA7C", "#C7965F")
    brass = mat("brass", "#D9A441", 0.35)
    h = SIZE / 2 - 0.2
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(f"Corner_{sx}_{sy}", 0.5, 0.5, 0.56, TOP + 0.015, brass, r, 0.05, 3,
                xy=(sx * h, sy * h))
    return 0.80


def marble(r):
    """Marmor: weisse Platten auf warmgrauem Stein, zwei auskragende Stufen."""
    box("Base", SIZE, SIZE, 0.34, TOP, mat("stone", "#B9B1A4", 0.55), r, 0.10, 5)
    box("Step1", SIZE + 0.16, SIZE + 0.16, 0.22, TOP - 0.30, mat("stone2", "#A39B8E", 0.55), r,
        0.05)
    box("Step2", SIZE + 0.32, SIZE + 0.32, 0.22, TOP - 0.50, mat("stone3", "#8D867A", 0.55), r,
        0.05)
    tiles(r, "#F3EFE7", "#E9E3D8", 0.45)
    return 0.74


# Unterseiten müssen steil zulaufen: Aus der Spielkamera (bei 0°) ist eine
# Flanke nur sichtbar, wenn sie je Einheit Einzug mehr als eine Einheit
# abfällt. Eine echte Spitze wäre deshalb unsichtbar; die Unterseiten sind
# gestufte Stümpfe mit Einzug/Abfall zwischen 0,5 und 0,8.
def glacier(r):
    """Gletscher: Eisplatte, darunter ein nach unten spitz zulaufender Kristall."""
    box("Base", SIZE, SIZE, 0.46, TOP, mat("ice", "#9CCBE2", 0.3), r, 0.10, 1, flat=True)
    frustum("Crystal1", SIZE / 2 - 0.12, 2.15, 0.70, TOP - 0.44, mat("ice2", "#7DB7D8", 0.3), r)
    frustum("Crystal2", 2.15, 1.50, 1.00, TOP - 1.13, mat("ice3", "#5E9FC8", 0.3), r)
    frustum("Crystal3", 1.50, 0.80, 0.90, TOP - 2.12, mat("ice4", "#4688B4", 0.3), r)
    tiles(r, "#E1F1F8", "#D2E8F3", 0.4)
    return 3.05


def island(r):
    """Insel: Grasdeck, Erdschicht und Fels, der nach unten spitz zuläuft."""
    box("Grass", SIZE, SIZE, 0.26, TOP, mat("grass", "#74AC57"), r, 0.08, 4)
    box("Earth", SIZE - 0.16, SIZE - 0.16, 0.40, TOP - 0.22, mat("earth", "#8F6549"), r, 0.07, 1,
        flat=True)
    frustum("Rock1", SIZE / 2 - 0.12, 2.20, 0.60, TOP - 0.60, mat("rock1", "#7C665A"), r)
    frustum("Rock2", 2.20, 1.68, 0.82, TOP - 1.19, mat("rock2", "#6B574C"), r)
    frustum("Rock3", 1.68, 1.05, 0.82, TOP - 2.00, mat("rock3", "#5B4A41"), r)
    tiles(r, "#A2CF80", "#93C470")
    return 2.85


PLATFORMS = {"oak": oak, "marble": marble, "glacier": glacier, "island": island}
ONLY = os.environ.get("FS_ONLY", "")
META_PATH = os.path.join(OUT, "platforms.json")
meta = json.load(open(META_PATH)) if os.path.exists(META_PATH) else {}

for name, build in PLATFORMS.items():
    if ONLY and name not in ONLY.split(","):
        continue
    sc = fs.reset_scene()
    fs.setup_light()
    rig = fs.make_rig()
    depth = build(rig)
    # Bildhöhe aus der Tiefe der Plattform; Bildmitte = Weltpunkt (0, 0, target_z)
    height = int(math.ceil((DIAMOND_H + depth * ZPX + 64) / 32) * 32)
    target_z = -depth / 2
    fs.setup_camera(sc, WIDTH, height, (0, 0, target_z))
    still = os.path.join(OUT, f"platform_{name}_still.png")
    fs.render(still)
    sc.render.resolution_percentage = 50
    for k, a in enumerate(ANGLES):
        rig.rotation_euler = (0, 0, math.radians(a))
        fs.render(os.path.join(OUT, f"platform_{name}_{k:03d}.png"))
    meta[name] = {"targetZ": target_z, "w": WIDTH, "h": height}
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", still, "-vf",
                    "scale=360:-1:flags=lanczos", os.path.join(UI, f"plat_{name}.png")],
                   check=True)

json.dump(meta, open(META_PATH, "w"), indent=2, sort_keys=True)

# Vorschau der Standardplattform und ihrer beiden Umfärbungen (Ton, Moos);
# die Werte entsprechen Looks._platforms im Spiel.
base = os.path.join(OUT, "platform_still.png")
for name, lut in (
    ("slate", None),
    ("clay", "lutrgb=r='val*0.84+46':g='val*0.92+12':b='val*0.94'"),
    ("moss", "lutrgb=r='val*0.93+6':g='val*0.88+30':b='val*0.90+2'"),
):
    vf = (lut + "," if lut else "") + "scale=360:-1:flags=lanczos"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", base, "-vf", vf,
                    os.path.join(UI, f"plat_{name}.png")], check=True)
print("PLATFORMS_DONE")
