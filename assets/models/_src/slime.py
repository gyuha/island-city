import os
import sys
import math
import bpy
import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import (
    clear_scene,
    hex_to_rgba,
    lerp_color,
    finalize_bmesh_object,
    apply_vertex_color_fn,
    export_glb,
)


def build_slime():
    clear_scene()

    c_base_deep = hex_to_rgba("#13b4c3")
    c_mid_teal = hex_to_rgba("#57d3b6")
    c_top_highlight = hex_to_rgba("#ddf8d1")
    c_cheek_coral = hex_to_rgba("#f08c7d")
    c_eye_dark = hex_to_rgba("#1a3836")
    c_eye_sparkle = hex_to_rgba("#ffffff")
    c_crown_leaf = hex_to_rgba("#81d465")

    # Original Dew-Drop Island Slime: plump teardrop jelly body facing -Z in Godot (+Y in Blender)
    bm_body = bmesh.new()
    ret = bmesh.ops.create_icosphere(bm_body, subdivisions=3, radius=1.0)
    for v in ret["verts"]:
        nx, ny, nz = v.co.x, v.co.y, v.co.z
        # Squish bottom flat at Z=0, plump belly, cute pointed droplet crest at top
        if nz < 0.0:
            z = (nz + 1.0) * 0.34
            r_scale = 0.44 + (1.0 + nz) * 0.06
        else:
            z = 0.34 + (nz ** 0.85) * 0.42
            r_scale = 0.50 * (1.0 - 0.32 * (nz ** 1.4))
        # Slight pudding wobble lobes around circumference
        ang = math.atan2(ny, nx)
        wobble = 1.0 + 0.035 * math.cos(ang * 5.0) * (1.0 - abs(nz))
        v.co = Vector((nx * r_scale * wobble, ny * r_scale * wobble, max(0.0, z)))

    # Add two cute jelly ear-droplets on top sides
    for sign in (-1.0, 1.0):
        ear_ret = bmesh.ops.create_icosphere(bm_body, subdivisions=2, radius=1.0)
        for v in ear_ret["verts"]:
            v.co = Vector((
                sign * (0.20 + v.co.x * 0.09),
                -0.02 + v.co.y * 0.08,
                0.68 + v.co.z * 0.12 + (v.co.x * sign * 0.04),
            ))

    body_obj = finalize_bmesh_object(bm_body, "SlimeBody", smooth=True)
    bm_body.free()

    def body_color(co, no, idx):
        # Rosy coral cheeks on front (+Y in Blender = -Z in Godot)
        if co.y > 0.30 and 0.24 < co.z < 0.38 and 0.14 < abs(co.x) < 0.28:
            return lerp_color(c_mid_teal, c_cheek_coral, 0.75)
        t = max(0.0, min(1.0, co.z / 0.78))
        if t < 0.40:
            return lerp_color(c_base_deep, c_mid_teal, t / 0.40)
        elif t < 0.82:
            return lerp_color(c_mid_teal, c_top_highlight, (t - 0.40) / 0.42)
        return lerp_color(c_top_highlight, c_crown_leaf, (t - 0.82) / 0.18)

    apply_vertex_color_fn(body_obj, body_color, smooth=True)

    # Eyes on front (+Y in Blender = -Z in Godot)
    bm_eyes = bmesh.new()
    for sign in (-1.0, 1.0):
        e_ret = bmesh.ops.create_icosphere(bm_eyes, subdivisions=2, radius=1.0)
        for v in e_ret["verts"]:
            v.co = Vector((
                sign * 0.145 + v.co.x * 0.045,
                0.455 + v.co.y * 0.025,
                0.365 + v.co.z * 0.062,
            ))
        # Eye highlight dot
        s_ret = bmesh.ops.create_icosphere(bm_eyes, subdivisions=1, radius=1.0)
        for v in s_ret["verts"]:
            v.co = Vector((
                sign * 0.130 + v.co.x * 0.018,
                0.480 + v.co.y * 0.012,
                0.390 + v.co.z * 0.018,
            ))

    eyes_obj = finalize_bmesh_object(bm_eyes, "SlimeEyes", smooth=True)
    bm_eyes.free()

    def eye_color(co, no, idx):
        if co.y > 0.472 and co.z > 0.375:
            return c_eye_sparkle
        return c_eye_dark

    apply_vertex_color_fn(eyes_obj, eye_color, smooth=True)

    out_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "creatures", "slime.glb")
    )
    export_glb(out_path)


if __name__ == "__main__":
    build_slime()
