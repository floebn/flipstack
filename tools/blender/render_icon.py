"""App-Symbol: Entwürfe als 1024er-Bild ohne Transparenz.

Aufruf: Blender -b --python tools/blender/render_icon.py
Ergebnis: assets_src/icon/icon_<name>.png
Mit FS_ICON=a,b lassen sich einzelne Entwürfe rendern. Eingebaut ist Entwurf
g_fallend; FS_ICON_CUTOUT=1 rendert ihn freigestellt für das Startbild.

Der Boden füllt das ganze Bild und trägt die Hintergrundfarbe, so fallen echte
Schatten darauf. Apple rundet die Ecken selbst ab, das Bild bleibt quadratisch.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh
import bpy
import fs_scene as fs

OUT = os.path.join(fs.ROOT, "assets_src", "icon")
os.makedirs(OUT, exist_ok=True)

# name: (Bodenfarbe, sichtbare Breite in Würfeln, Blickziel, Würfel)
# Würfel: (x, y, z, farbe) – Würfelmitte liegt bei z + 0.5.
STAIRS = [
    (-0.5, -0.5, 0, "mint"), (0.5, -0.5, 0, "mint"), (-0.5, 0.5, 0, "mint"),
    (0.5, 0.5, 0, "mint"),
    (-0.5, 0.5, 1, "amber"), (0.5, 0.5, 1, "amber"),
    (0.5, 0.5, 2, "coral"),
]

# Die Bodenfarbe wird durch das Licht heller; die Werte sind so gewählt, dass
# im Bild Navy, Creme und Mint der App herauskommen.
VARIANTS = {
    # Treppe aus drei Farben auf dunklem Grund.
    "a_treppe": ("#18212C", 4.7, (0.05, 0.05, 1.3), STAIRS),
    # Derselbe Aufbau hell, wie das Hauptmenü.
    "b_hell": ("#CBC5B8", 4.7, (0.05, 0.05, 1.3), STAIRS),
    # Ein Stein schwebt über dem Stapel: der Moment vor dem Ablegen.
    "c_schwebend": ("#2A9C8C", 5.3, (0.0, 0.0, 1.75), [
        (-0.5, -0.5, 0, "cream"), (0.5, -0.5, 0, "cream"),
        (-0.5, 0.5, 0, "cream"), (0.5, 0.5, 0, "cream"),
        (-0.5, 0.5, 1, "amber"), (0.5, 0.5, 1, "amber"), (0.5, -0.5, 1, "amber"),
        (-0.5, -0.5, 2.25, "coral"),
    ]),
}

arrow = fs.add_arrow


def disc(color, radius, height):
    """Runder Drehteller, Oberseite bei z = 0."""
    me = bpy.data.meshes.new("FS_Disc")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=96, radius1=radius,
                          radius2=radius, depth=height)
    rim = [e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-6]
    bmesh.ops.bevel(bm, geom=rim, offset=0.07, segments=3, profile=0.5,
                    affect="EDGES")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.set_sharp_from_angle(angle=math.radians(40))
    ob = bpy.data.objects.new("Disc", me)
    ob.data.materials.append(fs.material(f"M_{color}", fs.CFG["colors"][color]))
    ob.location = (0, 0, -height / 2)
    fs.collection("Platform").objects.link(ob)
    return ob


def extras_ring():
    # Zwei Pfeile liegen um den Turm auf dem Boden.
    arrow("cream", 2.05, 0.34, 100, 125, 0.0)
    arrow("cream", 2.05, 0.34, 280, 125, 0.0)


def extras_turntable():
    # Drehteller mit eingelegtem Pfeil am Rand; alles steht 0,5 über dem Boden.
    d = disc("navy", 2.15, 0.5)
    d.location.z += 0.5
    arrow("cream", 1.72, 0.26, 150, 250, 0.5, thick=0.05)


def extras_orbit():
    # Ein Pfeil kreist auf halber Höhe um den Turm.
    arrow("navy", 1.45, 0.3, 75, 300, 1.35, thick=0.16)


# Bodenhöhe je Entwurf, wenn der Stapel nicht direkt auf dem Boden steht.
GROUND = {"g_fallend": -0.62}


def extras_platform():
    # Flache Plattform unter dem Stapel.
    slab = bpy.data.objects.new(
        "Slab", fs.beveled_box_mesh("FS_Slab", 3.36, 3.36, 0.42, 0.08, 4))
    slab.data.materials.append(fs.material("M_navy", fs.CFG["colors"]["navy"], 0.6))
    slab.location = (0, 0, -0.21)
    fs.collection("Platform").objects.link(slab)
    # Kleines Drehsymbol auf der freien Fläche der Plattform: gedreht wird sie.
    sym = arrow("cream", 0.5, 0.15, 20, 285, 0.0, thick=0.03, head=1.7)
    sym.location.x, sym.location.y = 0.55, -0.55


# Zweite Runde: das Drehen steckt mit im Bild.
# name: (Bodenfarbe, Breite, Blickziel, Würfel, Zusatz)
VARIANTS2 = {
    "d_drehpfeile": ("#18212C", 6.3, (0.0, 0.0, 1.0), STAIRS, extras_ring),
    "e_drehteller": ("#2A9C8C", 6.3, (0.0, 0.0, 1.2), [
        (-0.5, -0.5, 0.5, "cream"), (0.5, -0.5, 0.5, "cream"),
        (0.5, 0.5, 0.5, "cream"),
        (0.5, 0.5, 1.5, "amber"), (0.5, -0.5, 1.5, "amber"),
        (0.5, 0.5, 2.5, "coral"),
    ], extras_turntable),
    # Nach einer Vorlage des Nutzers, reduziert: Plattform, kleiner Stapel,
    # ein fallender Würfel über seiner Lücke, kleiner Drehpfeil.
    "g_fallend": ("#CBC5B8", 6.9, (0.0, 0.0, 1.75), [
        (-1, -1, 0, "mint"), (-1, 0, 0, "mint"), (-1, 1, 0, "mint"),
        (0, 1, 0, "amber"), (1, 1, 0, "amber"),
        (-1, 1, 1, "sky"), (0, 1, 1, "sky"),
        (0, 0, 3.75, "coral"),
    ], extras_platform),
    "f_umlauf": ("#CBC5B8", 5.2, (0.0, 0.0, 1.5), [
        (0, 0, 0, "mint"), (0, 0, 1, "amber"), (0, 0, 2, "coral"),
    ], extras_orbit),
}
for k, v in VARIANTS.items():
    VARIANTS2[k] = v + (None,)


SIZE = 1024
want = [v for v in os.environ.get("FS_ICON", "").split(",") if v]
CUTOUT = bool(os.environ.get("FS_ICON_CUTOUT"))

for name, (floor, width, target, cubes, extra) in VARIANTS2.items():
    if want and not any(name.startswith(w) for w in want):
        continue
    sc = fs.reset_scene()
    sc.render.film_transparent = False
    sc.render.image_settings.color_mode = "RGB"
    cam = fs.setup_camera(sc, SIZE, SIZE, target=target)
    cam.data.ortho_scale = width
    fs.setup_light()
    rig = fs.make_rig()
    for x, y, z, c in cubes:
        fs.add_cube(c, (x, y, z + 0.5), rig)

    if extra:
        extra()

    if CUTOUT:
        # Freigestellt für das Startbild: ohne Boden, mit Transparenz.
        sc.render.film_transparent = True
        sc.render.image_settings.color_mode = "RGBA"
        fs.render(os.path.join(OUT, f"launch_{name}.png"))
        continue

    bpy.ops.mesh.primitive_plane_add(
        size=200, location=(0, 0, GROUND.get(name, 0)))
    ground = bpy.context.active_object
    ground.data.materials.append(fs.material("M_floor", floor, 0.9))

    fs.render(os.path.join(OUT, f"icon_{name}.png"))

print("ICON_DONE")
