import os
import sys
import math
import random
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


def build_rock_a():
    clear_scene()
    random.seed(101)

    c_base_teal = hex_to_rgba("#385b66")
    c_mid_gray = hex_to_rgba("#6c8796")
    c_light_gray = hex_to_rgba("#9bb2bf")
    c_moss_mid = hex_to_rgba("#5bb94f")
    c_moss_high = hex_to_rgba("#81d465")

    # Target: 100-400 tris -> 2 intersecting faceted boulders (icosphere subdiv=2 = 80 tris * 2 = 160 tris)
    bm = bmesh.new()
    chunks = [
        (0.0, 0.0, 0.42, 0.78, 0.68, 0.56, 1.0),
        (0.45, -0.22, 0.26, 0.46, 0.42, 0.36, 2.3),
    ]
    for cx, cy, cz, rx, ry, rz, phase in chunks:
        ret = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
        for v in ret["verts"]:
            nx, ny, nz = v.co.x, v.co.y, v.co.z
            # Angular faceted planar distortion
            facet = (
                1.0
                + 0.14 * math.sin(nx * 3.2 + phase)
                + 0.11 * math.cos(ny * 2.8 - phase)
                + 0.09 * math.sin(nz * 3.7 + phase * 0.5)
            )
            x = cx + nx * rx * facet
            y = cy + ny * ry * facet
            z = cz + nz * rz * facet
            if z < 0.0:
                z *= 0.15
            v.co = Vector((x, y, z))

    rock_obj = finalize_bmesh_object(bm, "RockA", smooth=False)
    bm.free()

    def rock_color(co, no, idx):
        # Mossy green cap on upward-facing top faces, blue-gray facets on sides, teal shadow at bottom
        if no.z > 0.58 and co.z > 0.52:
            t_moss = min(1.0, (no.z - 0.58) / 0.42)
            return lerp_color(c_moss_mid, c_moss_high, t_moss)
        h = max(0.0, min(1.0, co.z / 0.90))
        n = max(0.0, min(1.0, (no.z + 0.8) / 1.8))
        t = h * 0.5 + n * 0.5
        if t < 0.45:
            return lerp_color(c_base_teal, c_mid_gray, t / 0.45)
        return lerp_color(c_mid_gray, c_light_gray, (t - 0.45) / 0.55)

    apply_vertex_color_fn(rock_obj, rock_color, smooth=False)

    out_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "nature", "rock_a.glb")
    )
    export_glb(out_path)


if __name__ == "__main__":
    build_rock_a()
