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


def build_rock_c():
    clear_scene()

    c_base_teal = hex_to_rgba("#2b8277")
    c_mid_slate = hex_to_rgba("#5d8494")
    c_light_slate = hex_to_rgba("#8fb0bd")
    c_moss = hex_to_rgba("#5bb94f")

    # Flat cluster of 3 rounded-faceted coastal/stream stones (3 * 80 = 240 tris)
    bm = bmesh.new()
    stones = [
        (-0.22, 0.08, 0.24, 0.58, 0.48, 0.32, 0.4),
        (0.36, -0.15, 0.18, 0.45, 0.38, 0.24, 1.7),
        (0.06, 0.38, 0.14, 0.34, 0.30, 0.19, 2.9),
    ]
    for cx, cy, cz, rx, ry, rz, phase in stones:
        ret = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
        for v in ret["verts"]:
            nx, ny, nz = v.co.x, v.co.y, v.co.z
            facet = 1.0 + 0.10 * math.sin(nx * 3.0 + phase) * math.cos(ny * 3.0 - phase)
            x = cx + nx * rx * facet
            y = cy + ny * ry * facet
            z = max(0.0, cz + nz * rz * facet)
            v.co = Vector((x, y, z))

    rock_obj = finalize_bmesh_object(bm, "RockC", smooth=False)
    bm.free()

    def rock_color(co, no, idx):
        if no.z > 0.72 and co.z > 0.32:
            return lerp_color(c_light_slate, c_moss, 0.65)
        h = max(0.0, min(1.0, co.z / 0.55))
        n = max(0.0, min(1.0, (no.z + 0.7) / 1.7))
        t = h * 0.5 + n * 0.5
        if t < 0.45:
            return lerp_color(c_base_teal, c_mid_slate, t / 0.45)
        return lerp_color(c_mid_slate, c_light_slate, (t - 0.45) / 0.55)

    apply_vertex_color_fn(rock_obj, rock_color, smooth=False)

    out_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "nature", "rock_c.glb")
    )
    export_glb(out_path)


if __name__ == "__main__":
    build_rock_c()
