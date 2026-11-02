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


def build_bush_round():
    clear_scene()

    c_shadow = hex_to_rgba("#256d4b")
    c_mid = hex_to_rgba("#3aa13b")
    c_bright = hex_to_rgba("#5bb94f")
    c_high = hex_to_rgba("#81d465")
    c_top = hex_to_rgba("#c1e6a8")

    # Target: 300-800 tris -> 6 overlapping icospheres (subdiv=2 is 80 tris each -> 6 * 80 = 480 tris)
    bm = bmesh.new()
    spheres = [
        (0.0, 0.0, 0.46, 0.62, 0.60, 0.50),
        (0.38, 0.20, 0.34, 0.45, 0.44, 0.38),
        (-0.36, 0.24, 0.35, 0.44, 0.42, 0.37),
        (0.22, -0.35, 0.33, 0.46, 0.43, 0.36),
        (-0.28, -0.28, 0.36, 0.42, 0.44, 0.38),
        (0.05, 0.08, 0.64, 0.44, 0.42, 0.36),
    ]
    for cx, cy, cz, rx, ry, rz in spheres:
        ret = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
        for v in ret["verts"]:
            nx, ny, nz = v.co.x, v.co.y, v.co.z
            puff = 1.0 + 0.06 * math.sin(nx * 4.0 + cx * 3.0) * math.cos(ny * 4.0 + cy * 3.0)
            z = max(0.0, cz + nz * rz * puff)
            v.co = Vector((cx + nx * rx * puff, cy + ny * ry * puff, z))

    bush_obj = finalize_bmesh_object(bm, "BushRound", smooth=True)
    bm.free()

    def bush_color(co, no, idx):
        # Strong dark teal-green AO at bottom (as observed in frame_50s.jpg)
        h_factor = max(0.0, min(1.0, co.z / 0.95))
        n_factor = max(0.0, min(1.0, (no.z + 0.7) / 1.7))
        t = h_factor * 0.6 + n_factor * 0.4
        if t < 0.32:
            return lerp_color(c_shadow, c_mid, t / 0.32)
        elif t < 0.62:
            return lerp_color(c_mid, c_bright, (t - 0.32) / 0.30)
        elif t < 0.88:
            return lerp_color(c_bright, c_high, (t - 0.62) / 0.26)
        else:
            return lerp_color(c_high, c_top, (t - 0.88) / 0.12)

    apply_vertex_color_fn(bush_obj, bush_color, smooth=True)

    out_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "nature", "bush_round.glb")
    )
    export_glb(out_path)


if __name__ == "__main__":
    build_bush_round()
