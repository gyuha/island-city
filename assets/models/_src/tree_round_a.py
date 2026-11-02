import os
import sys
import math
import random
import bpy
import bmesh
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import (
    clear_scene,
    hex_to_rgba,
    lerp_color,
    color_bm_faces,
    finalize_bmesh_object,
    apply_vertex_color_fn,
    export_glb,
)


def build_tree_round_a():
    clear_scene()
    random.seed(42)

    c_trunk_dark = hex_to_rgba("#5c3d28")
    c_trunk_light = hex_to_rgba("#7a4f30")
    c_leaf_shadow = hex_to_rgba("#256d4b")
    c_leaf_mid = hex_to_rgba("#3aa13b")
    c_leaf_bright = hex_to_rgba("#5bb94f")
    c_leaf_high = hex_to_rgba("#81d465")
    c_leaf_top = hex_to_rgba("#c1e6a8")

    # 1. Trunk + main branches
    bm_trunk = bmesh.new()
    rings = 8
    segs = 12
    height = 2.5
    ring_verts = []
    for i in range(rings + 1):
        t = i / rings
        z = t * height
        # Slight organic curve and root flare
        flare = 0.26 * ((1.0 - t) ** 1.4) + 0.10
        if i == 0:
            flare = 0.42
        elif i == 1:
            flare = 0.31
        ox = math.sin(t * math.pi * 1.1) * 0.08
        oy = math.cos(t * math.pi * 0.9) * 0.05
        rv = []
        for s in range(segs):
            ang = (s / segs) * math.tau
            root_lobe = 1.0 + (0.18 * math.sin(ang * 4.0) if i < 2 else 0.0)
            x = ox + math.cos(ang) * flare * root_lobe
            y = oy + math.sin(ang) * flare * root_lobe
            rv.append(bm_trunk.verts.new((x, y, z)))
        ring_verts.append(rv)

    for i in range(rings):
        for s in range(segs):
            s_next = (s + 1) % segs
            bm_trunk.faces.new((
                ring_verts[i][s],
                ring_verts[i][s_next],
                ring_verts[i + 1][s_next],
                ring_verts[i + 1][s],
            ))
    bm_trunk.faces.new(ring_verts[0][::-1])
    bm_trunk.faces.new(ring_verts[-1])

    # Add 3 upper branches reaching into canopy blobs
    branch_specs = [
        ((0.05, 0.02, 1.95), (0.65, 0.35, 2.75), 0.12, 0.06),
        ((-0.04, 0.03, 2.05), (-0.60, 0.25, 2.85), 0.11, 0.05),
        ((0.02, -0.04, 2.00), (0.05, -0.60, 2.70), 0.11, 0.05),
    ]
    for p0, p1, r0, r1 in branch_specs:
        v0 = Vector(p0)
        v1 = Vector(p1)
        direction = (v1 - v0).normalized()
        up = Vector((0, 0, 1))
        side = direction.cross(up).normalized()
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

    def trunk_color(co, no, idx):
        t = max(0.0, min(1.0, (co.z / 2.5) * 0.7 + max(0.0, no.z) * 0.3))
        return lerp_color(c_trunk_dark, c_trunk_light, t)

    apply_vertex_color_fn(trunk_obj, trunk_color, smooth=True)

    # 2. Clumpy round canopy (6 overlapping organic blobs, total ~1.6k tris)
    bm_canopy = bmesh.new()
    blobs = [
        # (center_x, center_y, center_z, rx, ry, rz)
        (0.0, 0.0, 3.35, 1.35, 1.30, 1.05),
        (0.85, 0.40, 2.85, 0.95, 0.90, 0.78),
        (-0.80, 0.35, 2.95, 0.92, 0.88, 0.76),
        (0.15, -0.80, 2.80, 0.95, 0.88, 0.74),
        (-0.45, -0.55, 3.15, 0.82, 0.82, 0.72),
        (0.45, 0.55, 3.60, 0.85, 0.85, 0.70),
    ]
    for cx, cy, cz, rx, ry, rz in blobs:
        ret = bmesh.ops.create_icosphere(bm_canopy, subdivisions=3, radius=1.0)
        for v in ret["verts"]:
            # Gentle puffy displacement for clumpy hand-sculpted silhouette
            nx, ny, nz = v.co.x, v.co.y, v.co.z
            puff = 1.0 + 0.07 * math.sin(nx * 5.0 + cx) * math.cos(ny * 5.0 + cy)
            # Slightly flatten underside of each clump
            z_scale = rz * (0.82 if nz < 0 else 1.0)
            v.co = Vector((
                cx + nx * rx * puff,
                cy + ny * ry * puff,
                cz + nz * z_scale * puff,
            ))

    canopy_obj = finalize_bmesh_object(bm_canopy, "Canopy", smooth=True)
    bm_canopy.free()

    def canopy_color(co, no, idx):
        # Stylized vertical + normal gradient: teal-green shadow at bottom -> bright lime highlight at top
        h_factor = max(0.0, min(1.0, (co.z - 2.1) / 2.2))
        n_factor = max(0.0, min(1.0, (no.z + 0.8) / 1.8))
        t = h_factor * 0.55 + n_factor * 0.45
        if t < 0.30:
            return lerp_color(c_leaf_shadow, c_leaf_mid, t / 0.30)
        elif t < 0.60:
            return lerp_color(c_leaf_mid, c_leaf_bright, (t - 0.30) / 0.30)
        elif t < 0.85:
            return lerp_color(c_leaf_bright, c_leaf_high, (t - 0.60) / 0.25)
        else:
            return lerp_color(c_leaf_high, c_leaf_top, (t - 0.85) / 0.15)

    apply_vertex_color_fn(canopy_obj, canopy_color, smooth=True)

    out_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "nature", "tree_round_a.glb")
    )
    export_glb(out_path)


if __name__ == "__main__":
    build_tree_round_a()
