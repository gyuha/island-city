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


def build_tree_round_b():
    clear_scene()

    c_trunk_dark = hex_to_rgba("#543622")
    c_trunk_light = hex_to_rgba("#7a4f30")
    c_leaf_shadow = hex_to_rgba("#256d4b")
    c_leaf_mid = hex_to_rgba("#348832")
    c_leaf_bright = hex_to_rgba("#5bb94f")
    c_leaf_high = hex_to_rgba("#81d465")
    c_leaf_top = hex_to_rgba("#c1e6a8")

    # Twin-forking curved trunk (~5.0m total tree height)
    bm_trunk = bmesh.new()
    rings = 9
    segs = 12
    height = 2.8
    ring_verts = []
    for i in range(rings + 1):
        t = i / rings
        z = t * height
        flare = 0.24 * ((1.0 - t) ** 1.3) + 0.09
        if i == 0:
            flare = 0.40
        ox = -math.sin(t * math.pi * 0.85) * 0.16
        oy = math.sin(t * math.pi * 1.2) * 0.08
        rv = []
        for s in range(segs):
            ang = (s / segs) * math.tau
            lobe = 1.0 + (0.16 * math.cos(ang * 3.0) if i < 2 else 0.0)
            rv.append(bm_trunk.verts.new((ox + math.cos(ang) * flare * lobe, oy + math.sin(ang) * flare * lobe, z)))
        ring_verts.append(rv)

    for i in range(rings):
        for s in range(segs):
            sn = (s + 1) % segs
            bm_trunk.faces.new((ring_verts[i][s], ring_verts[i][sn], ring_verts[i + 1][sn], ring_verts[i + 1][s]))
    bm_trunk.faces.new(ring_verts[0][::-1])
    bm_trunk.faces.new(ring_verts[-1])

    # Forking limbs
    branch_specs = [
        ((-0.12, 0.04, 1.85), (0.75, 0.20, 3.05), 0.14, 0.06),
        ((-0.14, 0.02, 2.15), (-0.75, -0.25, 3.30), 0.13, 0.06),
        ((-0.08, -0.02, 2.30), (0.10, -0.65, 3.10), 0.11, 0.05),
    ]
    for p0, p1, r0, r1 in branch_specs:
        v0 = Vector(p0)
        v1 = Vector(p1)
        direction = (v1 - v0).normalized()
        side = direction.cross(Vector((0, 0, 1))).normalized()
        up_ortho = side.cross(direction).normalized()
        b_rings = []
        for bi in range(4):
            bt = bi / 3.0
            center = v0.lerp(v1, bt)
            rad = r0 * (1.0 - bt) + r1 * bt
            br = []
            for s in range(8):
                ang = (s / 8.0) * math.tau
                pt = center + (side * math.cos(ang) + up_ortho * math.sin(ang)) * rad
                br.append(bm_trunk.verts.new(pt))
            b_rings.append(br)
        for bi in range(3):
            for s in range(8):
                sn = (s + 1) % 8
                bm_trunk.faces.new((b_rings[bi][s], b_rings[bi][sn], b_rings[bi + 1][sn], b_rings[bi + 1][s]))
        bm_trunk.faces.new(b_rings[-1])

    trunk_obj = finalize_bmesh_object(bm_trunk, "Trunk", smooth=True)
    bm_trunk.free()
    apply_vertex_color_fn(
        trunk_obj,
        lambda co, no, idx: lerp_color(c_trunk_dark, c_trunk_light, max(0.0, min(1.0, co.z / 2.8 * 0.7 + max(0.0, no.z) * 0.3))),
        smooth=True,
    )

    # Tiered multi-crown canopy (7 blobs, ~1.9k tris)
    bm_canopy = bmesh.new()
    blobs = [
        (-0.55, -0.10, 3.70, 1.25, 1.20, 0.98),
        (0.70, 0.25, 3.25, 1.15, 1.10, 0.90),
        (0.05, 0.65, 3.55, 0.95, 0.92, 0.80),
        (0.15, -0.70, 3.20, 0.95, 0.90, 0.78),
        (-0.10, 0.05, 4.25, 1.05, 1.00, 0.85),
        (-1.05, 0.40, 3.10, 0.80, 0.80, 0.68),
        (0.95, -0.35, 2.85, 0.78, 0.78, 0.65),
    ]
    for cx, cy, cz, rx, ry, rz in blobs:
        ret = bmesh.ops.create_icosphere(bm_canopy, subdivisions=3, radius=1.0)
        for v in ret["verts"]:
            nx, ny, nz = v.co.x, v.co.y, v.co.z
            puff = 1.0 + 0.06 * math.cos(nx * 4.5 - cy) * math.sin(ny * 4.5 + cx)
            z_scale = rz * (0.80 if nz < 0 else 1.0)
            v.co = Vector((cx + nx * rx * puff, cy + ny * ry * puff, cz + nz * z_scale * puff))

    canopy_obj = finalize_bmesh_object(bm_canopy, "Canopy", smooth=True)
    bm_canopy.free()

    def canopy_color(co, no, idx):
        h_factor = max(0.0, min(1.0, (co.z - 2.3) / 2.6))
        n_factor = max(0.0, min(1.0, (no.z + 0.8) / 1.8))
        t = h_factor * 0.55 + n_factor * 0.45
        if t < 0.28:
            return lerp_color(c_leaf_shadow, c_leaf_mid, t / 0.28)
        elif t < 0.58:
            return lerp_color(c_leaf_mid, c_leaf_bright, (t - 0.28) / 0.30)
        elif t < 0.84:
            return lerp_color(c_leaf_bright, c_leaf_high, (t - 0.58) / 0.26)
        else:
            return lerp_color(c_leaf_high, c_leaf_top, (t - 0.84) / 0.16)

    apply_vertex_color_fn(canopy_obj, canopy_color, smooth=True)

    out_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "nature", "tree_round_b.glb")
    )
    export_glb(out_path)


if __name__ == "__main__":
    build_tree_round_b()
