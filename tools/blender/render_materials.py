"""Rendert die freischaltbaren Block-Materialien als graue Würfel-Atlanten.

Aufruf: Blender -b --python tools/blender/render_materials.py
Ergebnis (assets/sprites/), jeweils Atlas 6×5 wie cube.png:
  cube_pebble.png     Kiesel: stark gerundete Kanten
  cube_plank.png      Planke: zwei Lagen mit Nut, Kassette auf der Oberseite
  cube_facet.png      Facette: breite, hart geschliffene Fasen
  cube_stud.png       Noppe: Klemmbaustein mit runder Noppe oben
  cube_ice.png        Eis: glatter Würfel
  cube_ice_gloss.png  Eis: weisse Lichtkanten und Glanzstreifen (wird im Spiel
                      uneingefärbt über den Würfel gelegt)
Dazu je Material ein Einzelbild für den Shop (assets/ui/mat_*.png).

Alle Formen sind um die Hochachse vierfach symmetrisch, weil das Spiel die
Drehwinkel 0..87° für jede Vierteldrehung wiederverwendet. Grauwert und
Licht entsprechen cube.png, damit die Einfärbung im Spiel gleich wirkt.
"""
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
TMP = os.path.join(fs.ROOT, "build", "sprites_tmp")
for d in (OUT, UI, TMP):
    os.makedirs(d, exist_ok=True)
STEP = fs.CFG["angle_step_deg"]
ANGLES = list(range(0, 90, STEP))
COLS = 6
ROWS = math.ceil(len(ANGLES) / COLS)
PX = 256
GRAY = fs.CFG["colors"]["block_gray"]


def fresh():
    sc = fs.reset_scene()
    fs.setup_camera(sc, PX, PX, (0, 0, 0))
    fs.setup_light()
    return sc


def gray(roughness=0.65):
    return fs.material(f"M_gray_{roughness}", GRAY, roughness)


def part(name, mesh, parent, loc=(0, 0, 0), mat=None):
    ob = bpy.data.objects.new(name, mesh)
    ob.data.materials.append(mat or gray())
    ob.location = loc
    ob.parent = parent
    fs.collection("Pieces").objects.link(ob)
    return ob


def rig():
    r = bpy.data.objects.new("Block", None)
    fs.collection("Pieces").objects.link(r)
    return r


def render_set(prefix, ob):
    for n, a in enumerate(ANGLES):
        ob.rotation_euler = (0, 0, math.radians(a))
        fs.render(os.path.join(TMP, f"{prefix}_{n:03d}.png"))


def atlas(prefix, out_name, vf=""):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-start_number", "0",
                    "-i", os.path.join(TMP, prefix + "_%03d.png"),
                    "-vf", f"{vf}tile={COLS}x{ROWS}", "-frames:v", "1",
                    os.path.join(OUT, out_name)], check=True)


def pebble():
    fresh()
    r = rig()
    part("Pebble", fs.beveled_box_mesh("Pebble", 1, 1, 1, 0.23, 8), r)
    return r


def facet():
    fresh()
    r = rig()
    me = fs.beveled_box_mesh("Facet", 1, 1, 1, 0.17, 1)
    for p in me.polygons:  # harte, ebene Schliffflächen
        p.use_smooth = False
    part("Facet", me, r, mat=gray(0.5))
    return r


def plank():
    fresh()
    r = rig()
    gap, lift = 0.05, 0.03
    h = (1 - gap - lift) / 2
    part("Core", fs.beveled_box_mesh("Core", 0.9, 0.9, 0.96, 0.02, 2), r)
    for i in range(2):
        z = -0.5 + h / 2 + i * (h + gap)
        part(f"Layer_{i}", fs.beveled_box_mesh(f"Layer_{i}", 1, 1, h, 0.04, 3), r,
             (0, 0, z))
    # Kassette: erhabene Platte auf der Oberseite
    part("Panel", fs.beveled_box_mesh("Panel", 0.7, 0.7, lift * 2, 0.025, 2), r,
         (0, 0, 0.5 - lift))
    return r


def stud():
    """Klemmbaustein: kantiger Körper mit einer runden Noppe auf der Oberseite.
    Die Öffnung an der Unterseite ist aus der Spielkamera nie zu sehen."""
    fresh()
    r = rig()
    mat = gray(0.42)
    part("Body", fs.beveled_box_mesh("Body", 1, 1, 1, 0.035, 3), r, mat=mat)
    me = bpy.data.meshes.new("Stud")
    bm = bmesh.new()
    h = 0.17
    bmesh.ops.create_cone(bm, cap_ends=True, segments=64, radius1=0.27,
                          radius2=0.27, depth=h)
    top = [e for e in bm.edges
           if e.verts[0].co.z > 0 and e.verts[1].co.z > 0]
    bmesh.ops.bevel(bm, geom=top, offset=0.035, segments=3, profile=0.5,
                    affect="EDGES")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.set_sharp_from_angle(angle=math.radians(40))
    part("Stud", me, r, (0, 0, 0.5 + h / 2 - 0.005), mat)
    return r


def ice_base():
    fresh()
    r = rig()
    part("Ice", fs.beveled_box_mesh("Ice", 1, 1, 1, 0.09, 4), r, mat=gray(0.35))
    return r


def emission(name, level):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    v = fs.srgb_to_linear(level)
    em.inputs["Color"].default_value = (v, v, v, 1)
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


def quad(name, pts, parent, mat):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bm.faces.new([bm.verts.new(p) for p in pts])
    bm.to_mesh(me)
    bm.free()
    return part(name, me, parent, mat=mat)


def ice_gloss():
    """Nur die Glanzlichter; der Würfel selbst verdeckt, ist aber unsichtbar."""
    fresh()
    r = rig()
    mask = part("Mask", fs.beveled_box_mesh("Mask", 1, 1, 1, 0.09, 4), r)
    mask.is_holdout = True
    edge, glint, soft = emission("E_edge", 0.8), emission("E_glint", 0.24), emission("E_soft", 0.22)
    e = 0.462  # Lage der Kantenmitte auf der Fase
    for i in range(4):
        sub = bpy.data.objects.new(f"Side_{i}", None)
        sub.parent = r
        sub.rotation_euler = (0, 0, math.radians(90 * i))
        fs.collection("Pieces").objects.link(sub)
        # Lichtkante oben und an der senkrechten Kante
        part(f"EdgeTop_{i}", fs.beveled_box_mesh(f"EdgeTop_{i}", 0.78, 0.032, 0.032, 0.012, 2),
             sub, (0, -e, e), edge)
        part(f"EdgeSide_{i}", fs.beveled_box_mesh(f"EdgeSide_{i}", 0.032, 0.032, 0.72, 0.012, 2),
             sub, (-e, -e, 0), edge)
        # ein schwacher schräger Glanzstreifen auf der Seitenfläche
        y = -0.503
        quad(f"Glint_{i}", [(-0.36, y, 0.38), (-0.20, y, 0.38), (0.00, y, -0.38), (-0.16, y, -0.38)],
             sub, glint)
    # ruhige Aufhellung der Oberseite
    z = 0.503
    quad("Top", [(-0.38, -0.38, z), (0.38, -0.38, z), (0.38, 0.38, z), (-0.38, 0.38, z)], r, soft)
    return r


# Glanz: Helligkeit wird zur Deckkraft, die Farbe ist reines Weiss
GLOSS = "format=rgba,geq=r=255:g=255:b=255:a='r(X\\,Y)*alpha(X\\,Y)/255',"

ONLY = os.environ.get("FS_ONLY", "")
for name, build, vf in (
    ("pebble", pebble, ""),
    ("facet", facet, ""),
    ("plank", plank, ""),
    ("stud", stud, ""),
    ("ice", ice_base, ""),
    ("ice_gloss", ice_gloss, GLOSS),
):
    if ONLY and name not in ONLY.split(","):
        continue
    render_set("cube_" + name, build())
    atlas("cube_" + name, f"cube_{name}.png", vf)
    # Einzelbild (0°) für die Karte im Shop
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i",
                    os.path.join(TMP, f"cube_{name}_000.png"), "-vf",
                    (vf + "scale=160:160:flags=lanczos"),
                    os.path.join(UI, f"mat_{name}.png")], check=True)

subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i",
                os.path.join(OUT, "cube.png"), "-vf",
                "crop=256:256:0:0,scale=160:160:flags=lanczos",
                os.path.join(UI, "mat_matte.png")], check=True)
print("MATERIALS_DONE")
