"""Rendert die freischaltbaren Block-Materialien als graue Würfel-Atlanten.

Aufruf: Blender -b --python tools/blender/render_materials.py
Ergebnis (assets/sprites/), jeweils Atlas 6×5 wie cube.png:
  cube_pebble.png     Kiesel: stark gerundete Kanten
  cube_plank.png      Planke: zwei Lagen mit Nut, Kassette auf der Oberseite
  cube_facet.png      Facette: breite, hart geschliffene Fasen
  cube_stud.png       Noppe: Klemmbaustein mit runder Noppe oben
  cube_concrete.png   Beton: Poren, Ankerlöcher, Schalungsfuge
  cube_fabric.png     Stoff: Flechtmuster aus Polstern
  cube_volcano.png    Vulkan: dunkler Stein, Risse leuchten in der Blockfarbe
  cube_neon.png       Neonglas: dunkler Glaskörper, leuchtende Kanten
  cube_neon_gloss.png Neonglas: weisser Kern der Kanten (uneingefärbt)
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


def spin4(parent, name="Side"):
    """Vier Träger, je um 90° gedreht: Was an einem hängt, erscheint auf allen
    vier Seiten gleich (hält die Form vierfach symmetrisch)."""
    out = []
    for i in range(4):
        sub = bpy.data.objects.new(f"{name}_{i}", None)
        sub.parent = parent
        sub.rotation_euler = (0, 0, math.radians(90 * i))
        fs.collection("Pieces").objects.link(sub)
        out.append(sub)
    return out


def ico(radius, sub=1):
    me = bpy.data.meshes.new("ico")
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=radius)
    bm.to_mesh(me)
    bm.free()
    return me


def concrete():
    """Beton: Sichtbeton mit Poren, Ankerlöchern und einer Schalungsfuge."""
    import random
    rng = random.Random(4)
    fresh()
    r = rig()
    me = fs.beveled_box_mesh("Body", 1, 1, 1, 0.03, 1)
    for p in me.polygons:  # eben schattiert, sonst verschmiert der Schnitt die Flächen
        p.use_smooth = False
    body = part("Body", me, r, mat=gray(0.92))
    cut = gray()
    cutters = []
    side_pores = [(rng.uniform(-0.42, 0.42), rng.uniform(-0.42, 0.42), rng.uniform(0.018, 0.045))
                  for _ in range(9)]
    top_pores = [(rng.uniform(0.06, 0.42), rng.uniform(0.06, 0.42), rng.uniform(0.018, 0.04))
                 for _ in range(3)]
    for sub in spin4(r):
        for x, z, rad in side_pores:
            cutters.append(part("Pore", ico(rad), sub, (x, -0.5, z), cut))
        for x in (-0.22, 0.22):  # Ankerlöcher
            cutters.append(part("Tie", ico(0.05, 2), sub, (x, -0.52, 0.2), cut))
        for x, y, rad in top_pores:
            cutters.append(part("PoreTop", ico(rad), sub, (x, y, 0.5), cut))
        cutters.append(part("TieTop", ico(0.05, 2), sub, (0.24, 0.24, 0.52), cut))
    # Schalungsfuge rundum
    cutters.append(part("Seam", fs.beveled_box_mesh("Seam", 1.012, 1.012, 0.012, 0.001, 1), r,
                        (0, 0, -0.12), cut))
    for c in cutters:
        c.hide_render = True
        m = body.modifiers.new("Cut", "BOOLEAN")
        m.operation = "DIFFERENCE"
        m.object = c
    return r


def fabric():
    """Stoff: weicher Körper mit Flechtmuster aus abwechselnd hohen und
    flachen Polstern (5×5 je Fläche, damit das Muster drehsymmetrisch bleibt)."""
    fresh()
    r = rig()
    m = gray(0.97)
    part("Core", fs.beveled_box_mesh("Core", 0.955, 0.955, 0.955, 0.13, 5), r, mat=m)
    step, size = 0.18, 0.168

    def pad(parent, a, b, face_axis, raised):
        h = 0.07 if raised else 0.045
        me = fs.beveled_box_mesh("Pad", size, size, h, 0.03, 3)
        ob = part("Pad", me, parent, mat=m)
        depth = 0.5 - h / 2 - (0.0 if raised else 0.012)
        if face_axis == "top":
            ob.location = (a, b, depth)
        else:
            ob.rotation_euler = (math.radians(90), 0, 0)
            ob.location = (a, -depth, b)

    for i in range(5):
        for j in range(5):
            pad(r, (i - 2) * step, (j - 2) * step, "top", (i + j) % 2 == 0)
    for sub in spin4(r):
        for i in range(5):
            for j in range(5):
                pad(sub, (i - 2) * step, (j - 2) * step, "side", (i + j) % 2 == 0)
    return r


def strip(name, pts, width, y, parent, m, top=False):
    """Zackenlinie aus flachen Vierecken auf einer Seitenfläche (x, z) oder
    auf der Oberseite (x, y)."""
    for k in range(len(pts) - 1):
        (ax, az), (bx, bz) = pts[k], pts[k + 1]
        dx, dz = bx - ax, bz - az
        n = math.hypot(dx, dz)
        ox, oz = -dz / n * width / 2, dx / n * width / 2
        ex, ez = dx / n * width * 0.35, dz / n * width * 0.35  # Überlappung am Knick
        corners = [(ax - ex + ox, az - ez + oz), (ax - ex - ox, az - ez - oz),
                   (bx + ex - ox, bz + ez - oz), (bx + ex + ox, bz + ez + oz)]
        if top:
            quad(f"{name}_{k}", [(cx, cz, y) for cx, cz in corners], parent, m)
        else:
            quad(f"{name}_{k}", [(cx, y, cz) for cx, cz in reversed(corners)], parent, m)


def volcano():
    """Vulkan: dunkler, kantig gebrochener Stein mit glühenden Rissen. Der
    Stein bleibt dunkel, die Risse leuchten in der Blockfarbe."""
    fresh()
    r = rig()
    me = fs.beveled_box_mesh("Rock", 1, 1, 1, 0.09, 1)
    for p in me.polygons:
        p.use_smooth = False
    part("Rock", me, r, mat=fs.material("M_basalt", "#747474", 0.85))
    glow, core = emission("E_lava_glow", 0.62), emission("E_lava", 1.0)
    side = [[(-0.40, 0.30), (-0.18, 0.12), (-0.05, -0.10), (0.16, -0.18), (0.38, -0.40)],
            [(-0.05, -0.10), (-0.14, -0.36)]]
    top = [[(0.0, 0.0), (0.16, 0.10), (0.26, 0.30), (0.40, 0.38)]]
    for sub in spin4(r):
        for n, line in enumerate(side):
            strip(f"Glow{n}", line, 0.07, -0.5015, sub, glow)
            strip(f"Core{n}", line, 0.034, -0.503, sub, core)
        for n, line in enumerate(top):
            strip(f"TGlow{n}", line, 0.07, 0.5015, sub, glow, top=True)
            strip(f"TCore{n}", line, 0.034, 0.503, sub, core, top=True)
    return r


def edge_tubes(parent, m, thick, inset):
    """Stäbe entlang aller zwölf Würfelkanten."""
    e = 0.5 - inset
    length = 2 * e + thick
    for sub in spin4(parent, "Edges"):
        for z in (-e, e):
            part("EdgeH", fs.beveled_box_mesh("EdgeH", length, thick, thick, thick * 0.3, 2),
                 sub, (0, -e, z), m)
        part("EdgeV", fs.beveled_box_mesh("EdgeV", thick, thick, length, thick * 0.3, 2),
             sub, (-e, -e, 0), m)


def neon_base():
    """Neonglas: dunkler, glatter Glaskörper mit leuchtenden Kanten. Die Kanten
    sind hell und werden im Spiel zur kräftigen Blockfarbe."""
    fresh()
    r = rig()
    part("Glass", fs.beveled_box_mesh("Glass", 0.97, 0.97, 0.97, 0.04, 3), r,
         mat=fs.material("M_glass", "#7C7C7C", 0.22))
    edge_tubes(r, emission("E_neon", 1.0), 0.07, 0.035)
    inner = emission("E_inner", 0.50)
    for sub in spin4(r):
        y = -0.4875
        quad("Inner", [(-0.30, y, 0.30), (0.30, y, 0.30), (0.30, y, -0.30), (-0.30, y, -0.30)][::-1],
             sub, inner)
    z = 0.4875
    quad("InnerTop", [(-0.30, -0.30, z), (0.30, -0.30, z), (0.30, 0.30, z), (-0.30, 0.30, z)], r,
         emission("E_inner_top", 0.58))
    return r


def neon_gloss():
    """Weisser Kern der Leuchtkanten und ein schwacher Lichtreflex."""
    fresh()
    r = rig()
    mask = part("Mask", fs.beveled_box_mesh("Mask", 0.97, 0.97, 0.97, 0.04, 3), r)
    mask.is_holdout = True
    edge_tubes(r, emission("E_core", 0.85), 0.022, 0.012)
    soft = emission("E_reflex", 0.20)
    for sub in spin4(r):
        y = -0.503
        quad("Reflex", [(-0.26, y, 0.26), (-0.14, y, 0.26), (0.02, y, -0.26), (-0.10, y, -0.26)],
             sub, soft)
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
    ("concrete", concrete, ""),
    ("fabric", fabric, ""),
    ("volcano", volcano, ""),
    ("neon", neon_base, ""),
    ("neon_gloss", neon_gloss, GLOSS),
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
