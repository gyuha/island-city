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


def build_rock_b():
    clear_scene()

    c_base_teal = hex_to_rgba("#325560")
    c_mid_gray = hex_to_rgba("#648191")
    c_light_gray = hex_to_rgba("#96aebd")
    c_moss_mid = hex_to_rgba("#3aa13b")
    c_moss_high = hex_to_rgba("#81d465")

    # Taller angular spire rock + side slab (3 * 80 = 240 tris)
    bm = bmesh.new()
    chunks = [
        (0.0, 0.0, 0.68, 0.56, 0.50, 0.85, 0.7),
        (-0.38, 0.18, 0.36, 0.44, 0.38, 0.48, 1.9),
        (0.32, -0.24, 0.25, 0.38, 0.35, 0.32, 3.1),
    ]
    for cx, cy, cz, rx, ry, rz, phase in chunks:
        ret = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
        for v in ret["verts"]:
            nx, ny, nz = v.co.x, v.co.y, v.co.z
            taper = 1.0 - max(0.0, nz) * 0.28
            facet = (
                1.0
                + 0.15 * math.cos(nx * 3.5 + phase)
                + 0.12 * math.sin(ny * 3.1 - phase)
            )
            x = cx + nx * rx * taper * facet
            y = cy + ny * ry * taper * facet
            z = cz + nz * rz * facet
            if z < 0.0:
                z *= 0.1
            v.co = Vector((x, y, z))

    rock_obj = finalize_bmesh_object(bm, "RockB", smooth=False)
    bm.free()

    def rock_color(co, no, idx):
        if no.z > 0.62 and co.z > 0.65:
            return lerp_color(c_moss_mid, c_moss_high, min(1.0, (no.z - 0.62) / 0.38))
        h = max(0.0, min(1.0, co.z / 1.45))
        n = max(0.0, min(1.0, (no.z + 0.8) / 1.8))
        t = h * 0.55 + n * 0.45
        if t < 0.45:
            return lerp_color(c_base_teal, c_mid_gray, t / 0.45)
        return lerp_color(c_mid_gray, c_light_gray, (t - 0.45) / 0.55)

    apply_vertex_color_fn(rock_obj, rock_color, smooth=False)

    out_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "nature", "rock_b.glb")
    )
    export_glb(out_path)


if __name__ == "__main__":
    build_rock_b()
