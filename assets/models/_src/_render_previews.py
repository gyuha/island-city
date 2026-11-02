import os
import sys
import math
import bpy
from mathutils import Vector, Euler

MODELS = [
    ("characters/player.glb", "player.png", (1.05, 1.55, 1.25), (0.0, 0.0, 0.50)),
    ("gear/glider_wings.glb", "glider_wings.png", (0.0, 2.2, 0.85), (0.0, 0.0, 0.05)),
    ("nature/tree_round_a.glb", "tree_round_a.png", (4.5, 5.2, 5.2), (0.0, 0.0, 2.3)),
    ("nature/tree_round_b.glb", "tree_round_b.png", (5.0, 5.8, 5.6), (0.0, 0.0, 2.5)),
    ("nature/bush_round.glb", "bush_round.png", (1.4, 1.6, 1.45), (0.0, 0.0, 0.42)),
    ("nature/rock_a.glb", "rock_a.png", (1.6, 1.9, 1.5), (0.0, 0.0, 0.40)),
    ("nature/rock_b.glb", "rock_b.png", (1.8, 2.1, 1.8), (0.0, 0.0, 0.65)),
    ("nature/rock_c.glb", "rock_c.png", (1.5, 1.8, 1.4), (0.0, 0.0, 0.25)),
    ("nature/cattail.glb", "cattail.png", (1.3, 1.6, 1.25), (0.0, 0.0, 0.62)),
    ("nature/lilypad.glb", "lilypad.png", (0.85, 1.0, 0.95), (0.0, 0.0, 0.05)),
    ("nature/seagrass.glb", "seagrass.png", (1.3, 1.6, 1.25), (0.0, 0.0, 0.60)),
    ("buildings/cottage.glb", "cottage.png", (5.5, 6.2, 5.2), (0.0, 0.0, 1.85)),
    ("buildings/pier.glb", "pier.png", (7.5, -1.5, 5.5), (0.0, -6.5, 0.40)),
    ("creatures/slime.glb", "slime.png", (1.0, 1.35, 0.95), (0.0, 0.0, 0.35)),
]


def setup_toon_preview_material(obj):
    """Ensure imported GLB mesh displays its COLOR_0 attribute with stylized cel-ramp + teal shadow."""
    for slot in obj.material_slots:
        mat = slot.material
        if not mat:
            continue
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        links = mat.node_tree.links
        nodes.clear()

        out_node = nodes.new(type="ShaderNodeOutputMaterial")
        bsdf = nodes.new(type="ShaderNodeBsdfPrincipled")
        bsdf.inputs["Roughness"].default_value = 0.95
        bsdf.inputs["Metallic"].default_value = 0.0
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.05

        vc_node = nodes.new(type="ShaderNodeVertexColor")
        if obj.data.color_attributes:
            vc_node.layer_name = obj.data.color_attributes[0].name

        links.new(vc_node.outputs["Color"], bsdf.inputs["Base Color"])
        links.new(bsdf.outputs["BSDF"], out_node.inputs["Surface"])


def render_all():
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    out_dir = "/tmp/art_preview"
    os.makedirs(out_dir, exist_ok=True)

    for rel_glb, out_png, cam_pos, target_pos in MODELS:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        scene = bpy.context.scene

        # Use EEVEE or CYCLES/WORKBENCH depending on availability
        engines = [e.identifier for e in scene.render.bl_rna.properties["engine"].enum_items]
        if "BLENDER_EEVEE_NEXT" in engines:
            scene.render.engine = "BLENDER_EEVEE_NEXT"
        elif "BLENDER_EEVEE" in engines:
            scene.render.engine = "BLENDER_EEVEE"
        else:
            scene.render.engine = "CYCLES"
            scene.cycles.samples = 16

        scene.render.resolution_x = 512
        scene.render.resolution_y = 512
        scene.render.film_transparent = False

        # World background: soft meadow-teal sky tint (#4eb790 / #5bb94f) so shadows are teal-green
        world = bpy.data.worlds.new("PreviewWorld")
        scene.world = world
        world.use_nodes = True
        bg = world.node_tree.nodes.get("Background")
        if bg:
            bg.inputs[0].default_value = (0.14, 0.42, 0.32, 1.0)
            bg.inputs[1].default_value = 1.15

        glb_path = os.path.join(base_dir, rel_glb)
        bpy.ops.import_scene.gltf(filepath=glb_path)

        for obj in scene.objects:
            if obj.type == "MESH":
                setup_toon_preview_material(obj)

        # Sun light (bright midday sun)
        sun_data = bpy.data.lights.new(name="Sun", type="SUN")
        sun_data.energy = 3.8
        sun_data.color = (1.0, 0.98, 0.90)
        sun_obj = bpy.data.objects.new(name="Sun", object_data=sun_data)
        bpy.context.collection.objects.link(sun_obj)
        sun_obj.rotation_euler = Euler((math.radians(42), math.radians(18), math.radians(-30)), "XYZ")

        # Teal fill light from opposite side for stylized teal shadows
        fill_data = bpy.data.lights.new(name="TealFill", type="SUN")
        fill_data.energy = 1.2
        fill_data.color = (0.20, 0.65, 0.52)
        fill_obj = bpy.data.objects.new(name="TealFill", object_data=fill_data)
        bpy.context.collection.objects.link(fill_obj)
        fill_obj.rotation_euler = Euler((math.radians(-50), math.radians(-30), math.radians(140)), "XYZ")

        # Camera looking at target_pos
        cam_data = bpy.data.cameras.new(name="Cam")
        cam_data.lens = 45.0
        cam_obj = bpy.data.objects.new(name="Cam", object_data=cam_data)
        bpy.context.collection.objects.link(cam_obj)
        cam_obj.location = Vector(cam_pos)
        direction = Vector(target_pos) - cam_obj.location
        cam_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.camera = cam_obj

        out_file = os.path.join(out_dir, out_png)
        scene.render.filepath = out_file
        bpy.ops.render.render(write_still=True)
        print(f"[PREVIEW RENDERED] {out_file}")


if __name__ == "__main__":
    render_all()
