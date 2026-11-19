"""Rendert die Szenerien der freischaltbaren Hintergründe.

Aufruf: Blender -b --python tools/blender/render_backgrounds.py
Ergebnis: assets/backgrounds/<name>.png (transparent, 1242×1100). Das Spiel
zeichnet Himmel, Lichtschein und Partikel selbst und legt die Szenerie an den
unteren Bildrand.

Aufbau: Low-Poly-Formen, hart facettiert, in drei Tiefenstaffeln. Entfernte
Staffeln sind zur Himmelsfarbe hin aufgehellt (Dunst), damit die Szenerie
hinter dem Turm ruhig bleibt. Die Mitte ist niedriger als die Ränder.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import bmesh
from mathutils import Euler, Vector
import fs_scene as fs

OUT = os.path.join(fs.ROOT, "assets", "backgrounds")
os.makedirs(OUT, exist_ok=True)
W, H = 1242, 1100
VIEW_W = 9.0  # sichtbare Breite in Welteinheiten
VIEW_H = VIEW_W * H / W
# Der Boden (z = 0) liegt auf 35 % der Bildhöhe: Der Streifen darunter liegt im
# Spiel hinter den Bedienknöpfen, die Bäume stehen seitlich neben der Plattform.
GROUND_AT = 0.35


def mix(a, b, t):
    a, b = a.lstrip("#"), b.lstrip("#")
    return "#" + "".join(
        f"{round(int(a[i:i+2], 16) * (1 - t) + int(b[i:i+2], 16) * t):02X}" for i in (0, 2, 4))


def scene():
    sc = fs.reset_scene()
    cam = bpy.data.cameras.new("BG_Camera")
    cam.type = "ORTHO"
    cam.ortho_scale = VIEW_W
    ob = bpy.data.objects.new("BG_Camera", cam)
    ob.rotation_euler = Euler((math.radians(84), 0, 0))  # fast frontal, leicht von oben
    ob.location = Vector((0, -60, VIEW_H * (0.5 - GROUND_AT) + 60 * math.tan(math.radians(6))))
    fs.collection("Camera_Light").objects.link(ob)
    sc.camera = ob
    sc.render.resolution_x, sc.render.resolution_y = W, H
    sc.render.resolution_percentage = 100
    sun = bpy.data.lights.new("BG_Sun", "SUN")
    sun.energy = 3.0
    sun.angle = math.radians(20)
    so = bpy.data.objects.new("BG_Sun", sun)
    so.rotation_euler = Vector((-0.55, -0.6, 1.0)).normalized().to_track_quat("Z", "Y").to_euler()
    fs.collection("Camera_Light").objects.link(so)
    return sc


def obj(name, me, color, loc, scale=(1, 1, 1), rot_z=0.0, rough=0.8):
    for p in me.polygons:
        p.use_smooth = False
    ob = bpy.data.objects.new(name, me)
    ob.data.materials.append(fs.material("BG_" + color, color, rough))
    ob.location, ob.scale = loc, scale
    ob.rotation_euler = (0, 0, rot_z)
    fs.collection("Scenery").objects.link(ob)
    return ob


def cone(seg, r1, r2, depth):
    me = bpy.data.meshes.new("cone")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=depth)
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=(0, 0, depth / 2))
    bm.to_mesh(me)
    bm.free()
    return me


def ico(sub, r):
    me = bpy.data.meshes.new("ico")
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    bm.to_mesh(me)
    bm.free()
    return me


def fir(x, y, z, s, leaf, trunk, rng, snow=None):
    obj("trunk", cone(5, 0.09 * s, 0.07 * s, 0.5 * s), trunk, (x, y, z))
    rot = rng.random() * 3
    for k, (r, h, up) in enumerate(((0.62, 0.95, 0.35), (0.48, 0.85, 0.85), (0.33, 0.75, 1.32))):
        obj("fir", cone(6, r * s, 0.0, h * s), leaf, (x, y, z + up * s), rot_z=rot + k)
        if snow:
            obj("snow", cone(6, r * s * 0.62, 0.0, h * s * 0.62), snow,
                (x, y, z + (up + h * 0.40) * s), rot_z=rot + k)


def leafy(x, y, z, s, leaf, trunk, rng):
    obj("trunk", cone(5, 0.10 * s, 0.07 * s, 0.9 * s), trunk, (x, y, z))
    obj("crown", ico(1, 0.62 * s), leaf, (x, y, z + 1.25 * s),
        (1, 1, 0.92), rng.random() * 3)
    obj("crown2", ico(1, 0.40 * s), leaf, (x + 0.38 * s, y - 0.1, z + 0.95 * s),
        rot_z=rng.random() * 3)


def hill(x, y, z, rx, rz, color):
    me = bpy.data.meshes.new("hill")
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=14, v_segments=7, radius=1.0)
    bm.to_mesh(me)
    bm.free()
    obj("hill", me, color, (x, y, z), (rx, 2.0, rz))


def mountain(x, y, z, r, h, rock, snow, rng):
    rot = rng.random() * 3
    obj("mountain", cone(5, r, 0.0, h), rock, (x, y, z), rot_z=rot)
    obj("cap", cone(5, r * 0.40, 0.0, h * 0.40), snow, (x, y, z + h * 0.61), (1.03, 1.03, 1.0), rot)


def ground(color):
    """Füllt den Bildstreifen unter dem Horizont."""
    me = bpy.data.meshes.new("ground")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bm.to_mesh(me)
    bm.free()
    obj("ground", me, color, (0, -1.0, -2.6), (40, 3, 5))


def edge_weight(x):
    """Ränder höher, Mitte niedriger (0 in der Mitte, 1 am Rand)."""
    return min(1.0, abs(x) / (VIEW_W / 2))


def rows(rng, count, y, jitter=0.5):
    step = (VIEW_W + 2) / count
    return [(-VIEW_W / 2 - 1 + (i + 0.5) * step + (rng.random() - 0.5) * jitter * step, y)
            for i in range(count)]


def forest(haze, greens, trunk, ground_color, snow=None, peaks=None):
    rng = random.Random(7)
    scene()
    ground(mix(ground_color, haze, 0.55))
    if peaks:
        rock, cap = peaks
        for x, r, h in ((-3.7, 2.4, 2.9), (-1.1, 1.9, 2.0), (1.7, 2.2, 2.3), (3.9, 2.6, 3.2)):
            mountain(x, 14, 0.2, r, h, mix(rock, haze, 0.55), mix(cap, haze, 0.35), rng)
    for layer, (y, fog, size, count) in enumerate(((8, 0.62, 1.0, 11), (4, 0.36, 1.25, 9),
                                                    (0, 0.12, 1.6, 7))):
        hill(0, y + 0.6, -0.9 + layer * 0.05, 9.5, 1.5 - layer * 0.25,
             mix(ground_color, haze, fog))
        for x, yy in rows(rng, count, y):
            w = edge_weight(x)
            if layer == 2 and w < 0.42:
                continue  # vorne bleibt die Mitte frei
            s = size * (0.55 + 0.55 * w) * (0.85 + rng.random() * 0.3)
            fir(x, yy, 0.25 - layer * 0.12, s, mix(rng.choice(greens), haze, fog),
                mix(trunk, haze, fog), rng, mix(snow, haze, fog * 0.6) if snow else None)


def autumn(haze):
    rng = random.Random(11)
    scene()
    ground(mix("#C9A45E", haze, 0.6))
    leaves = ["#E9A23B", "#E2703A", "#C8502E", "#F0C05A", "#B8862F"]
    for layer, (y, fog, size, count) in enumerate(((8, 0.6, 1.0, 10), (4, 0.34, 1.3, 8),
                                                    (0, 0.10, 1.7, 6))):
        hill(-3.5 + layer * 2.6, y + 0.6, -1.2, 7.5, 2.2 - layer * 0.35,
             mix("#C9A45E", haze, fog))
        hill(4.0 - layer * 2.0, y + 0.8, -1.2, 7.0, 1.9 - layer * 0.3,
             mix("#B98F4E", haze, fog))
        for x, yy in rows(rng, count, y):
            w = edge_weight(x)
            if layer == 2 and w < 0.42:
                continue
            s = size * (0.55 + 0.55 * w) * (0.85 + rng.random() * 0.3)
            leafy(x, yy, 0.3 - layer * 0.1, s, mix(rng.choice(leaves), haze, fog),
                  mix("#6B4A35", haze, fog), rng)


def space():
    rng = random.Random(3)
    scene()
    haze = "#1B2536"
    # grosser Planet unten rechts, angeschnitten, mit schmalem Ring
    centre = (3.3, 6, -1.3)
    obj("planet", ico(2, 2.7), "#3F7C9A", centre, rot_z=0.4, rough=0.7)
    me = bpy.data.meshes.new("ring")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=48, radius1=4.2, radius2=3.8, depth=0.02)
    bm.to_mesh(me)
    bm.free()
    ring = obj("ring", me, mix("#C9B48A", haze, 0.35), centre, rough=0.7)
    ring.rotation_euler = (math.radians(72), math.radians(-16), 0)
    mod = ring.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = 0.05
    # kleiner Mond und Gesteinsbrocken links
    obj("moon", ico(2, 0.85), mix("#B9C2D6", haze, 0.3), (-2.9, 8, 2.4), rot_z=1.0)
    for i in range(9):
        x = -4.4 + rng.random() * 3.4
        z = -1.6 + rng.random() * 1.6
        obj("rock", ico(1, 0.14 + rng.random() * 0.22), mix("#6E7B93", haze, rng.random() * 0.4),
            (x, 2 + rng.random() * 3, z), (1.3, 1, 0.8), rng.random() * 3)


def glow(hex_color, strength=1.4):
    """Selbstleuchtendes Material (Fenster, Leuchtreklame)."""
    name = f"BG_glow_{hex_color}_{strength}"
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = fs.hex_rgba(hex_color)
    em.inputs["Strength"].default_value = strength
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


def box(color, loc, size, material=None):
    me = bpy.data.meshes.new("box")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=(0, 0, 0.5))
    bm.to_mesh(me)
    bm.free()
    ob = obj("box", me, color or "#000000", loc, size)
    if material:
        ob.data.materials.clear()
        ob.data.materials.append(material)
    return ob


def tilted(me, color, loc, rx, ry, rz=0.0):
    ob = obj("branch", me, color, loc)
    ob.rotation_euler = (rx, ry, rz)
    return ob


def coral(x, y, z, s, color, rng):
    """Verzweigte Koralle aus schlanken Kegeln."""
    obj("stem", cone(5, 0.10 * s, 0.07 * s, 0.55 * s), color, (x, y, z))
    for k in range(5):
        a = k * 1.26 + rng.random() * 0.5
        lean = 0.35 + rng.random() * 0.35
        tilted(cone(5, 0.075 * s, 0.03 * s, (0.55 + rng.random() * 0.5) * s), color,
               (x, y, z + (0.25 + 0.1 * k) * s), math.cos(a) * lean, math.sin(a) * lean)


def underwater():
    rng = random.Random(21)
    scene()
    haze = "#BFE4E8"
    ground(mix("#E6DCBC", haze, 0.45))
    reef = ["#F27C65", "#E88CA3", "#F1BD58", "#9585CC", "#F4A08C"]
    weed = ["#4FA58E", "#5DB39A", "#3F957F"]
    for layer, (y, fog, size, count) in enumerate(((8, 0.62, 1.0, 10), (4, 0.36, 1.3, 8),
                                                    (0, 0.12, 1.7, 7))):
        hill(0, y + 0.6, -0.95 + layer * 0.05, 9.5, 1.45 - layer * 0.22,
             mix("#E6DCBC", haze, fog))
        for x, yy in rows(rng, count, y):
            w = edge_weight(x)
            if layer == 2 and w < 0.42:
                continue
            s = size * (0.6 + 0.6 * w) * (0.85 + rng.random() * 0.3)
            z = 0.25 - layer * 0.12
            kind = rng.random()
            if kind < 0.45:
                coral(x, yy, z, s * 1.2, mix(rng.choice(reef), haze, fog), rng)
            elif kind < 0.8:  # Seegras: hohe, leicht geneigte Halme
                for k in range(3):
                    tilted(cone(4, 0.07 * s, 0.0, (1.3 + rng.random() * 0.9) * s),
                           mix(rng.choice(weed), haze, fog),
                           (x + (k - 1) * 0.16 * s, yy, z), 0.0, (rng.random() - 0.5) * 0.4)
            else:  # runde Hirnkoralle oder Fels
                obj("brain", ico(1, 0.42 * s), mix(rng.choice(reef + ["#8FA3A6"]), haze, fog),
                    (x, yy, z + 0.2 * s), (1.2, 1.0, 0.8), rng.random() * 3)


def neon_city():
    rng = random.Random(33)
    scene()
    haze = "#1A1632"
    ground(mix("#0F0D1E", haze, 0.3))
    signs = ["#FF4FA3", "#4FE3F0", "#F1BD58", "#9D7CFF"]
    for layer, (y, fog, count) in enumerate(((8, 0.55, 12), (4, 0.30, 9), (0, 0.08, 7))):
        body = mix("#2B2A52", haze, fog)
        for x, yy in rows(rng, count, y, 0.3):
            w = edge_weight(x)
            if layer == 2 and w < 0.45:
                continue
            width = 0.55 + rng.random() * 0.55
            height = (1.0 + 2.9 * w + rng.random() * 0.9) * (0.75 + layer * 0.12)
            z = -0.3
            box(body, (x, yy, z), (width, width, height))
            front = yy - width / 2 - 0.01
            color = rng.choice(signs)
            lit = glow(mix(color, haze, fog * 0.8), 1.5 - fog)
            if rng.random() < 0.55:  # senkrechtes Lichtband
                box(None, (x + (rng.random() - 0.5) * width * 0.5, front, z + height * 0.15),
                    (0.05, 0.02, height * 0.7), lit)
            else:  # Fensterreihen
                rows_n = max(2, int(height / 0.55))
                for k in range(rows_n):
                    if rng.random() < 0.25:
                        continue
                    box(None, (x, front, z + 0.3 + k * 0.5), (width * 0.7, 0.02, 0.07), lit)
            if rng.random() < 0.4:  # Antenne mit Positionslicht
                box(body, (x, yy, z + height), (0.04, 0.04, 0.5))
                box(None, (x, yy, z + height + 0.5), (0.07, 0.07, 0.07),
                    glow(mix("#FF4FA3", haze, fog * 0.6)))


SCENES = {
    "forest": lambda: forest("#DCEBDD", ["#4E8F6A", "#5E9C6C", "#437F63"], "#5E4A3A", "#7FAF7C"),
    "winter": lambda: forest("#E3ECF5", ["#4F7F86", "#5B8C8C", "#456F7C"], "#5A4C46", "#EEF3F8",
                             snow="#FFFFFF", peaks=("#7E93AB", "#FFFFFF")),
    "autumn": lambda: autumn("#F6E2C8"),
    "space": space,
    "underwater": underwater,
    "city": neon_city,
}
ONLY = os.environ.get("FS_ONLY", "")
for name, build in SCENES.items():
    if ONLY and name not in ONLY.split(","):
        continue
    build()
    fs.render(os.path.join(OUT, f"{name}.png"))
print("BACKGROUNDS_DONE")
