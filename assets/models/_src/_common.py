import bpy
import bmesh
import math
import os
import sys
from mathutils import Vector, Matrix, Euler


def srgb_to_linear(c: float) -> float:
    if c <= 0.04045:
        return c / 12.92
    return ((c + 0.055) / 1.055) ** 2.4


def hex_to_rgba(hex_str: str, alpha: float = 1.0) -> tuple:
    h = hex_str.lstrip("#")
    r = srgb_to_linear(int(h[0:2], 16) / 255.0)
    g = srgb_to_linear(int(h[2:4], 16) / 255.0)
    b = srgb_to_linear(int(h[4:6], 16) / 255.0)
    return (r, g, b, alpha)


def lerp_color(c1: tuple, c2: tuple, t: float) -> tuple:
    t = max(0.0, min(1.0, t))
    return tuple(c1[i] + (c2[i] - c1[i]) * t for i in range(4))


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def get_vertex_color_material(name: str = "VertexColorMat"):
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out_node = nodes.new(type="ShaderNodeOutputMaterial")
    bsdf = nodes.new(type="ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.0

    vc_node = nodes.new(type="ShaderNodeVertexColor")
    vc_node.layer_name = "Color"

    links.new(vc_node.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(bsdf.outputs["BSDF"], out_node.inputs["Surface"])
    return mat


def apply_vertex_color_fn(obj, color_fn, smooth: bool = True, attr_name: str = "Color"):
    """
    color_fn(world_co, normal, loop_vert_idx) -> (r, g, b, a) in linear space
    """
    mesh = obj.data
    if smooth:
        for poly in mesh.polygons:
            poly.use_smooth = True
    else:
        for poly in mesh.polygons:
            poly.use_smooth = False

    if attr_name in mesh.color_attributes:
        color_attr = mesh.color_attributes[attr_name]
    else:
        color_attr = mesh.color_attributes.new(
            name=attr_name,
            type="BYTE_COLOR",
            domain="CORNER",
        )
    mesh.color_attributes.active_color = color_attr
    mesh.color_attributes.render_color_index = mesh.color_attributes.find(attr_name)

    mat_world = obj.matrix_world
    rot_world = mat_world.to_3x3()

    for poly in mesh.polygons:
        for loop_idx in poly.loop_indices:
            v_idx = mesh.loops[loop_idx].vertex_index
            v = mesh.vertices[v_idx]
            w_co = mat_world @ v.co
            w_no = (rot_world @ v.normal).normalized()
            rgba = color_fn(w_co, w_no, v_idx)
            color_attr.data[loop_idx].color = rgba

    mat = get_vertex_color_material()
    if len(mesh.materials) == 0:
        mesh.materials.append(mat)
    else:
        mesh.materials[0] = mat


def color_bm_faces(bm, faces, rgba: tuple):
    layer = bm.loops.layers.color.get("Color")
    if layer is None:
        layer = bm.loops.layers.color.new("Color")
    for f in faces:
        for loop in f.loops:
            loop[layer] = rgba


def finalize_bmesh_object(bm, name: str, smooth: bool = True, parent=None, location=(0.0, 0.0, 0.0)):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    for poly in mesh.polygons:
        poly.use_smooth = smooth

    if "Color" in mesh.color_attributes:
        mesh.color_attributes.active_color = mesh.color_attributes["Color"]
        mesh.color_attributes.render_color_index = mesh.color_attributes.find("Color")

    mat = get_vertex_color_material()
    mesh.materials.append(mat)

    obj = bpy.data.objects.new(name, mesh)
    obj.location = Vector(location)
    bpy.context.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    return obj


def count_scene_tris() -> int:
    total = 0
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            total += sum(len(p.vertices) - 2 for p in obj.data.polygons)
    return total


def export_glb(filepath: str):
    os.makedirs(os.path.dirname(os.path.abspath(filepath)), exist_ok=True)
    tris = count_scene_tris()
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=True,
        export_active_vertex_color_when_no_material=True,
        export_cameras=False,
        export_lights=False,
    )
    print(f"[EXPORTED] {filepath} | Total Tris: {tris}")
