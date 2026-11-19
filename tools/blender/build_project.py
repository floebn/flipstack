"""Baut das zentrale Blender-Projekt und rendert das Übersichtsblatt.

Aufruf: Blender -b --python tools/blender/build_project.py
Ergebnis:
  assets_src/blender/flipstack.blend   zentrales Projekt mit Collection-Struktur
  docs/img/phase3_bausteine.png        Übersichtsblatt aller Bausteine (Selbstkontrolle)

Collections: Camera_Light, Platform, Grid, Pieces, Background, Particles_Ref, Export.
Die Materialbibliothek besteht aus je einem Material pro Palettenfarbe (M_<name>).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import fs_scene as fs

PIECES = json.load(open(os.path.join(fs.HERE, "pieces.json")))
PALETTE = fs.CFG["block_palette"]

sc = fs.reset_scene()
sc.render.film_transparent = False
bg = sc.world.node_tree.nodes["Background"]
nt = sc.world.node_tree
lp = nt.nodes.new("ShaderNodeLightPath")
bg2 = nt.nodes.new("ShaderNodeBackground")
bg2.inputs[0].default_value = fs.hex_rgba("#EFE6D6")
mix = nt.nodes.new("ShaderNodeMixShader")
nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
nt.links.new(bg.outputs[0], mix.inputs[1])
nt.links.new(bg2.outputs[0], mix.inputs[2])
nt.links.new(mix.outputs[0], nt.nodes["World Output"].inputs["Surface"])

fs.setup_camera(sc, 1800, 1500, target=(9.9, -4.7, 0.0))
sc.camera.data.ortho_scale = 29
fs.setup_light()

# Plattform mit Marke
rig = fs.make_rig()
fs.add_platform(rig)
rig.location = (15.6, -10.4, 0)

# Schattenfänger-Boden für das Übersichtsblatt
bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, -0.9))
floor = bpy.context.active_object
floor.name = "Sheet_Floor"
floor.data.materials.append(fs.material("M_sheet_floor", "#C9BDA8", 0.95))
for c in list(floor.users_collection):
    c.objects.unlink(floor)
fs.collection("Background").objects.link(floor)

# Alle Bausteine, aus Einheitswürfeln zusammengesetzt, in einem Raster ausgelegt
# Bildschirm-rechts entspricht (1, 1), Bildschirm-unten (1, -1).
cols = 5
for i, piece in enumerate(PIECES):
    root = bpy.data.objects.new(f"Piece_{piece['name']}", None)
    fs.collection("Pieces").objects.link(root)
    c, r = i % cols, i // cols
    root.location = (c * 2.9 + r * 3.5 - 1.5, c * 2.9 - r * 3.5 - 1.5, -0.88)
    color = PALETTE[piece["color"]]
    for x, y, z in piece["cells"]:
        fs.add_cube(color, (x, y, z + 0.5), root, name=f"{piece['name']}_{x}{y}{z}")

# Materialbibliothek vollständig anlegen (auch unbenutzte Farben bleiben erhalten)
for name in PALETTE:
    fs.material(f"M_{name}", fs.CFG["colors"][name]).use_fake_user = True

# Export-Objekte (für render_sprites.py; im Übersichtsblatt ausgeblendet)
exp = fs.collection("Export")
for ob in (fs.add_cube("block_gray", name="Export_Cube"), fs.add_peg()):
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    exp.objects.link(ob)
    ob.hide_render = True
    ob.location.x += 30

# Partikel-Referenz: Staubkorn
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.08, location=(30, 2, 0))
dust = bpy.context.active_object
dust.name = "Dust_Ref"
dust.data.materials.append(fs.material("M_dust", "#FFFAF0", 0.9))
for c in list(dust.users_collection):
    c.objects.unlink(dust)
fs.collection("Particles_Ref").objects.link(dust)
dust.hide_render = True

out_blend = os.path.join(fs.ROOT, "assets_src", "blender")
os.makedirs(out_blend, exist_ok=True)
fs.render(os.path.join(fs.ROOT, "docs", "img", "phase3_bausteine.png"))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_blend, "flipstack.blend"))
print("PROJECT_DONE", [c.name for c in bpy.data.collections])
