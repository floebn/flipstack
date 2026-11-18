"""FLIPSTACK – zentrale Blender-Szene (Kamera, Licht, Materialien, Geometrie).

Wird von render_reference.py und render_sprites.py importiert.
Einheiten: 1 Würfel = 1 Blender-Einheit. Plattform-Oberseite liegt bei z = 0,
Plattformmitte im Ursprung. Die Kamera und das Licht sind welt-/kamerafest;
gedreht wird ausschliesslich das Objekt "Rig" (Plattform + Würfel).
"""
import json
import math
import os

import bpy
import bmesh
from mathutils import Euler, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
CFG = json.load(open(os.path.join(HERE, "config.json")))


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgba(h):
    h = h.lstrip("#")
    return tuple(srgb_to_linear(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4)) + (1.0,)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"  # Palette bleibt farbtreu
    sc.view_settings.look = "None"
    ee = sc.eevee
    for attr, val in (
        ("taa_render_samples", 64),
        ("use_shadows", True),
        ("use_raytracing", True),
        ("ray_tracing_method", "SCREEN"),
        ("use_fast_gi", True),
        ("fast_gi_method", "AMBIENT_OCCLUSION_ONLY"),
        ("fast_gi_distance", 0.6),
    ):
        try:
            setattr(ee, attr, val)
        except Exception as e:  # API-Unterschiede zwischen Versionen sichtbar machen
            print("EEVEE_SETTING_SKIPPED", attr, e)
    # Welt / Umgebungslicht
    w = bpy.data.worlds.new("FS_World")
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = hex_rgba(CFG["ambient"]["color"])
    bg.inputs[1].default_value = CFG["ambient"]["strength"]
    sc.world = w
    return sc


def collection(name):
    c = bpy.data.collections.get(name)
    if not c:
        c = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(c)
    return c


def setup_camera(sc, width_px, height_px, target=(0, 0, 0)):
    """Orthografische, echte Isometrie. ppu Pixel pro Welteinheit."""
    cam = bpy.data.cameras.new("FS_Camera")
    cam.type = "ORTHO"
    cam.sensor_fit = "HORIZONTAL"
    cam.ortho_scale = width_px / CFG["ppu"]
    cam.clip_start, cam.clip_end = 0.1, 200
    ob = bpy.data.objects.new("FS_Camera", cam)
    rot = Euler((math.radians(CFG["camera"]["tilt_deg"]), 0,
                 math.radians(CFG["camera"]["azimuth_deg"])))
    ob.rotation_euler = rot
    ob.location = Vector(target) + rot.to_matrix() @ Vector((0, 0, 60))
    collection("Camera_Light").objects.link(ob)
    sc.camera = ob
    sc.render.resolution_x, sc.render.resolution_y = width_px, height_px
    sc.render.resolution_percentage = 100
    return ob


def setup_light():
    s = CFG["sun"]
    sun = bpy.data.lights.new("FS_Sun", "SUN")
    sun.energy = s["strength"]
    sun.angle = math.radians(s["angle_deg"])
    sun.use_shadow = True
    ob = bpy.data.objects.new("FS_Sun", sun)
    ob.rotation_euler = Vector(s["dir"]).normalized().to_track_quat("Z", "Y").to_euler()
    collection("Camera_Light").objects.link(ob)
    return ob


def material(name, hex_color, roughness=0.65):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = hex_rgba(hex_color)
    b.inputs["Roughness"].default_value = roughness
    for spec in ("Specular IOR Level", "Specular"):
        if spec in b.inputs:
            b.inputs[spec].default_value = 0.25
            break
    return m


def beveled_box_mesh(name, sx, sy, sz, bevel, segments=3):
    """Box, zentriert im Ursprung, mit Fase und sauberen Normalen."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z *= sz
    bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=segments,
                    profile=0.5, affect="EDGES")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.set_sharp_from_angle(angle=math.radians(40))
    return me


def make_rig():
    rig = bpy.data.objects.new("Rig", None)
    collection("Platform").objects.link(rig)
    return rig


def cube_mesh():
    me = bpy.data.meshes.get("FS_Cube")
    if not me:
        c = CFG["cube"]
        me = beveled_box_mesh("FS_Cube", 1, 1, 1, c["bevel"], c["segments"])
    return me


def add_cube(color, pos=(0, 0, 0), parent=None, name=None):
    """pos = Würfelmitte in Rig-Koordinaten."""
    ob = bpy.data.objects.new(name or f"Cube_{color}", cube_mesh().copy())
    ob.data.materials.append(material(f"M_{color}", CFG["colors"][color]))
    ob.location = pos
    ob.parent = parent
    collection("Pieces").objects.link(ob)
    return ob


TILE = 0.93
TILE_H = 0.06
BASE_H = 0.55
BASE_MARGIN = 0.12


def tile_mesh():
    me = bpy.data.meshes.get("FS_Tile")
    if not me:
        me = beveled_box_mesh("FS_Tile", TILE, TILE, TILE_H, 0.02, 2)
    return me


def add_tile(i, j, color_name, hex_color, parent=None):
    n = CFG["grid"]
    ob = bpy.data.objects.new(f"Tile_{i}_{j}", tile_mesh().copy())
    ob.data.materials.append(material(f"M_{color_name}", hex_color, 0.7))
    ob.location = (i - (n - 1) / 2, j - (n - 1) / 2, -TILE_H / 2)
    ob.parent = parent
    collection("Grid").objects.link(ob)
    return ob


def add_platform(parent=None, with_marker=True, marker_cell=(0, 0)):
    """Sockel + n×n leicht erhabene Kacheln. Oberseite der Kacheln bei z = 0."""
    n = CFG["grid"]
    col = CFG["colors"]
    size = n + 2 * BASE_MARGIN
    base = bpy.data.objects.new(
        "Platform_Base", beveled_box_mesh("FS_Base", size, size, BASE_H, 0.09, 4))
    base.data.materials.append(material("M_navy", col["navy"], 0.6))
    base.location = (0, 0, -TILE_H * 0.6 - BASE_H / 2)
    base.parent = parent
    collection("Platform").objects.link(base)
    for i in range(n):
        for j in range(n):
            if with_marker and (i, j) == marker_cell:
                add_tile(i, j, "coral", col["coral"], parent)
            else:
                add_tile(i, j, "platform_top", col["platform_top"], parent)
    return base


def cell_center(i, j, k):
    n = CFG["grid"]
    return (i - (n - 1) / 2, j - (n - 1) / 2, k + 0.5)


def render(path):
    sc = bpy.context.scene
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
