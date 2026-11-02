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
    export_glb,
)


def build_cattail():
    clear_scene()

    c_stem_base = hex_to_rgba("#256d4b")
    c_stem_mid = hex_to_rgba("#3aa13b")
    c_stem_tip = hex_to_rgba("#81d465")
    c_head_dark = hex_to_rgba("#5c3820")
    c_head_mid = hex_to_rgba("#7a4f30")
    c_spike_tip = hex_to_rgba("#d9c298")

    # Single combined mesh so _first_mesh(M_CATTAIL) in island.gd gets stalks + leaves + brown seed heads!
    bm = bmesh.new()
    stalk_configs = [
        (0.00, 0.00, 1.28, 0.03, 0.02),
        (0.11, 0.06, 1.15, -0.05, 0.04),
        (-0.10, 0.05, 1.08, -0.04, -0.05),
        (0.04, -0.10, 1.20, 0.06, -0.04),
    ]
    head_transforms = []

    for sx, sy, h, bend_x, bend_y in stalk_configs:
        segs = 5
        rings = 4
        ring_v = []
        for i in range(rings + 1):
            t = i / rings
            z = t * h
            cx = sx + bend_x * (t ** 1.6)
            cy = sy + bend_y * (t ** 1.6)
            rad = 0.016 * (1.0 - 0.35 * t)
            rv = []
            for s in range(segs):
                ang = (s / segs) * math.tau
                rv.append(bm.verts.new((cx + math.cos(ang) * rad, cy + math.sin(ang) * rad, z)))
            ring_v.append(rv)
        for i in range(rings):
            for s in range(segs):
                sn = (s + 1) % segs
                bm.faces.new((ring_v[i][s], ring_v[i][sn], ring_v[i + 1][sn], ring_v[i + 1][s]))
        bm.faces.new(ring_v[-1])
        head_transforms.append((sx, sy, h, bend_x, bend_y))

    # 5 arching reed leaf blades around the stalks
    for b_idx in range(5):
        ang = (b_idx / 5.0) * math.tau + 0.25
        bx = math.cos(ang) * 0.08
        by = math.sin(ang) * 0.08
        nx = -math.sin(ang)
        ny = math.cos(ang)
        ox = math.cos(ang)
        oy = math.sin(ang)
        bh = 0.72 + (b_idx % 3) * 0.14
        arch = 0.14 + (b_idx % 2) * 0.06
        b_rings = []
        for i in range(6):
            t = i / 5.0
            z = t * bh
            cx = bx + ox * arch * (t ** 1.8)
            cy = by + oy * arch * (t ** 1.8)
            w = 0.032 * math.sin(max(0.12, (1.0 - t * 0.85)) * math.pi * 0.5)
            if i == 5:
                w = 0.004
            v_left = bm.verts.new((cx - nx * w, cy - ny * w, z))
            v_mid = bm.verts.new((cx + ox * 0.008, cy + oy * 0.008, z))
            v_right = bm.verts.new((cx + nx * w, cy + ny * w, z))
            b_rings.append((v_left, v_mid, v_right))
        for i in range(5):
            l0, m0, r0 = b_rings[i]
            l1, m1, r1 = b_rings[i + 1]
            bm.faces.new((l0, m0, m1, l1))
            bm.faces.new((m0, r0, r1, m1))

    stalk_faces = set(bm.faces)

    # Brown cylindrical seed heads
    for sx, sy, h, bend_x, bend_y in head_transforms:
        segs = 6
        rings = 4
        z0 = h * 0.72
        z1 = h * 0.94
        ring_v = []
        for i in range(rings + 1):
            u = i / rings
            t = (z0 + (z1 - z0) * u) / h
            cx = sx + bend_x * (t ** 1.6)
            cy = sy + bend_y * (t ** 1.6)
            z = z0 + (z1 - z0) * u
            profile = math.sin(u * math.pi) ** 0.35
            rad = 0.038 * max(0.25, profile)
            rv = []
            for s in range(segs):
                ang = (s / segs) * math.tau
                rv.append(bm.verts.new((cx + math.cos(ang) * rad, cy + math.sin(ang) * rad, z)))
            ring_v.append(rv)
        for i in range(rings):
            for s in range(segs):
                sn = (s + 1) % segs
                bm.faces.new((ring_v[i][s], ring_v[i][sn], ring_v[i + 1][sn], ring_v[i + 1][s]))
        bm.faces.new(ring_v[0][::-1])
        bm.faces.new(ring_v[-1])

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    layer = bm.loops.layers.color.new("Color")
    for f in bm.faces:
        if f in stalk_faces:
            for loop in f.loops:
                z = loop.vert.co.z
                t = max(0.0, min(1.0, z / 1.2))
                if t < 0.45:
                    loop[layer] = lerp_color(c_stem_base, c_stem_mid, t / 0.45)
                else:
                    loop[layer] = lerp_color(c_stem_mid, c_stem_tip, (t - 0.45) / 0.55)
        else:
            for loop in f.loops:
                z = loop.vert.co.z
                if z > 1.15:
                    loop[layer] = lerp_color(c_head_mid, c_spike_tip, 0.5)
                else:
                    t = max(0.0, min(1.0, (f.normal.z + 1.0) * 0.5))
                    loop[layer] = lerp_color(c_head_dark, c_head_mid, t)

    finalize_bmesh_object(bm, "Cattail", smooth=True)
    bm.free()

    out_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "nature", "cattail.glb")
    )
    export_glb(out_path)


if __name__ == "__main__":
    build_cattail()
