import os
import sys
import math
import bpy
import bmesh
from mathutils import Vector, Euler

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import (
    clear_scene,
    hex_to_rgba,
    lerp_color,
    finalize_bmesh_object,
    apply_vertex_color_fn,
    export_glb,
)


def build_glider_wings():
    clear_scene()

    c_white = hex_to_rgba("#fffdf5")
    c_cream_shadow = hex_to_rgba("#d7ede8")
    c_pink_mid = hex_to_rgba("#f5988c")
    c_pink_tip = hex_to_rgba("#e86a58")
    c_gold_mount = hex_to_rgba("#f2c94c")

    # Target: 1k-2k tris (pair of white feathered glider wings with pink tips, attachable to back)
    bm = bmesh.new()

    def add_feather(start: Vector, end: Vector, width: float, thickness: float):
        vec = end - start
        length = vec.length
        direction = vec.normalized()
        # Wing lies mostly in X-Z plane, slightly swept in -Y (back)
        fwd = Vector((0.0, 1.0, 0.0))
        side_ortho = direction.cross(fwd).normalized()
        rings = []
        segs = 4
        rad_segs = 6
        for i in range(segs + 1):
            t = i / segs
            center = start.lerp(end, t)
            # Rounded chunky feather silhouette (wider toward outer half)
            profile = math.sin(min(1.0, t * 0.92 + 0.08) * math.pi) ** 0.55
            w = width * max(0.15, profile)
            th = thickness * max(0.20, profile)
            rv = []
            for s in range(rad_segs):
                ang = (s / rad_segs) * math.tau
                pt = center + side_ortho * (math.cos(ang) * w) + fwd * (math.sin(ang) * th)
                rv.append(bm.verts.new(pt))
            rings.append(rv)
        for i in range(segs):
            for s in range(rad_segs):
                sn = (s + 1) % rad_segs
                bm.faces.new((rings[i][s], rings[i][sn], rings[i + 1][sn], rings[i + 1][s]))
        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])

    # Build symmetric left (-X) and right (+X) wings
    for sign in (-1.0, 1.0):
        # Upper arch bone/covert ridge
        p0 = Vector((sign * 0.08, 0.0, 0.02))
        p1 = Vector((sign * 0.48, -0.04, 0.22))
        p2 = Vector((sign * 0.88, -0.08, 0.14))
        add_feather(p0, p1, 0.075, 0.032)
        add_feather(p1, p2, 0.068, 0.028)

        # Primary outer flight feathers (8 chunky feathers per wing)
        for f_idx in range(8):
            u = f_idx / 7.0
            root_x = sign * (0.14 + u * 0.66)
            root_z = 0.06 + math.sin(u * math.pi * 0.85) * 0.14
            root_y = -0.02 - u * 0.05
            root = Vector((root_x, root_y, root_z))

            # Fan angle outward and downward
            angle = (-0.75 + u * 0.92)
            flen = 0.42 + math.sin(u * math.pi) * 0.16
            tip = root + Vector((
                sign * math.cos(angle) * flen,
                -0.04,
                math.sin(angle) * flen - 0.14 * (1.0 - u),
            ))
            add_feather(root, tip, 0.066, 0.024)

        # Secondary upper covert feathers (6 overlapping smaller feathers per wing)
        for c_idx in range(6):
            u = c_idx / 5.0
            root = Vector((sign * (0.12 + u * 0.52), 0.015, 0.08 + math.sin(u * math.pi) * 0.12))
            angle = -0.55 + u * 0.75
            flen = 0.25 + math.sin(u * math.pi) * 0.08
            tip = root + Vector((
                sign * math.cos(angle) * flen,
                0.01,
                math.sin(angle) * flen - 0.06,
            ))
            add_feather(root, tip, 0.058, 0.022)

    # Central back mount badge
    ret = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.085)
    for v in ret["verts"]:
        v.co = Vector((v.co.x * 1.2, v.co.y * 0.5, v.co.z * 1.0 + 0.04))

    wings_obj = finalize_bmesh_object(bm, "GliderWings", smooth=True)
    bm.free()

    def wing_color(co, no, idx):
        span = abs(co.x)
        if span < 0.105 and abs(co.z - 0.04) < 0.09:
            return c_gold_mount
        # Outer rim & upper arch get warm coral-pink gradient (as seen in frame_01s & keyart_01)
        radial = math.hypot(span, co.z * 0.7)
        if co.z > 0.08 and span > 0.22:
            t_pink = min(1.0, (co.z - 0.04) / 0.18 + (span - 0.22) * 0.6)
            return lerp_color(c_pink_mid, c_pink_tip, t_pink)
        if radial > 0.62:
            t_tip = min(1.0, (radial - 0.62) / 0.35)
            return lerp_color(c_white, c_pink_mid, t_tip)
        shade = max(0.0, min(1.0, (no.z + 0.8) / 1.8))
        return lerp_color(c_cream_shadow, c_white, shade)

    apply_vertex_color_fn(wings_obj, wing_color, smooth=True)

    out_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "gear", "glider_wings.glb")
    )
    export_glb(out_path)


if __name__ == "__main__":
    build_glider_wings()
