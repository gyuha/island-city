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


def build_seagrass():
    clear_scene()

    c_root = hex_to_rgba("#256d4b")
    c_mid = hex_to_rgba("#2b8277")
    c_upper = hex_to_rgba("#4eb790")
    c_tip = hex_to_rgba("#57d3b6")

    # Target: 200-500 tris -> 9 wavy double-sided/thickened ribbon blades
    bm = bmesh.new()
    blade_specs = [
        (0.00, 0.00, 1.35, 0.055, 0.10, 0.0),
        (0.14, 0.08, 1.18, 0.050, 0.65, 0.8),
        (-0.12, 0.10, 1.25, 0.052, 1.35, 1.5),
        (0.10, -0.14, 1.05, 0.048, 2.10, 2.2),
        (-0.15, -0.09, 1.12, 0.048, 2.85, 3.0),
        (0.22, -0.02, 0.92, 0.044, 3.60, 0.5),
        (-0.04, 0.20, 0.98, 0.045, 4.30, 1.9),
        (0.05, -0.22, 0.88, 0.042, 5.05, 2.7),
        (-0.22, 0.03, 0.95, 0.044, 5.75, 1.1),
    ]

    segs = 6
    for bx, by, height, width, yaw, phase in blade_specs:
        side = Vector((-math.sin(yaw), math.cos(yaw), 0.0))
        fwd = Vector((math.cos(yaw), math.sin(yaw), 0.0))
        rings = []
        for i in range(segs + 1):
            t = i / segs
            z = t * height
            # Graceful underwater S-wave sway
            wave = math.sin(t * math.pi * 1.6 + phase) * 0.11 * (t ** 1.1)
            drift = (t ** 1.7) * 0.08
            center = Vector((bx, by, z)) + fwd * (wave + drift)
            w = width * math.sin((1.0 - t * 0.82) * math.pi * 0.5)
            if i == segs:
                w = 0.004
            thickness = 0.009 * (1.0 - t * 0.7)
            vl = bm.verts.new(center - side * w)
            vf = bm.verts.new(center + fwd * thickness)
            vr = bm.verts.new(center + side * w)
            vb = bm.verts.new(center - fwd * thickness)
            rings.append((vl, vf, vr, vb))

        for i in range(segs):
            l0, f0, r0, b0 = rings[i]
            l1, f1, r1, b1 = rings[i + 1]
            bm.faces.new((l0, f0, f1, l1))
            bm.faces.new((f0, r0, r1, f1))
            bm.faces.new((r0, b0, b1, r1))
            bm.faces.new((b0, l0, l1, b1))

    seagrass_obj = finalize_bmesh_object(bm, "SeagrassCluster", smooth=True)
    bm.free()

    def seagrass_color(co, no, idx):
        t = max(0.0, min(1.0, co.z / 1.30))
        if t < 0.33:
            return lerp_color(c_root, c_mid, t / 0.33)
        elif t < 0.68:
            return lerp_color(c_mid, c_upper, (t - 0.33) / 0.35)
        return lerp_color(c_upper, c_tip, (t - 0.68) / 0.32)

    apply_vertex_color_fn(seagrass_obj, seagrass_color, smooth=True)

    out_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "nature", "seagrass.glb")
    )
    export_glb(out_path)


if __name__ == "__main__":
    build_seagrass()
