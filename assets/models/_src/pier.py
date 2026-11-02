import os
import sys
import math
import bpy
import bmesh
from mathutils import Vector, Matrix, Euler

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import (
    clear_scene,
    hex_to_rgba,
    lerp_color,
    finalize_bmesh_object,
    apply_vertex_color_fn,
    export_glb,
)


def add_beveled_box(bm, center: Vector, size: Vector, rot_euler=(0.0, 0.0, 0.0), bevel_amt=0.015):
    ret = bmesh.ops.create_cube(bm, size=1.0)
    verts = ret["verts"]
    rot_mat = Euler(rot_euler, "XYZ").to_matrix().to_4x4()
    scale_mat = Matrix.Diagonal((size.x, size.y, size.z, 1.0))
    xform = Matrix.Translation(center) @ rot_mat @ scale_mat
    bmesh.ops.transform(bm, matrix=xform, verts=verts)
    if bevel_amt > 0.0:
        edges = list({e for v in verts for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=edges, offset=bevel_amt, segments=1, affect="EDGES")


def build_pier():
    clear_scene()

    c_wood_wet = hex_to_rgba("#3d4d47")
    c_wood_dark = hex_to_rgba("#6e472b")
    c_wood_mid = hex_to_rgba("#9c6b43")
    c_wood_light = hex_to_rgba("#c48f5c")
    c_rope = hex_to_rgba("#e2c98f")

    # Target: 1k-2k tris
    # Extends along +Z in Godot (-Y in Blender: Y = -0.25 to -12.75, length ~13m, width 2.4m, deck height Z=0.62)
    bm = bmesh.new()

    length = 12.6
    y_center = -6.5
    width = 2.4

    # 1. Two longitudinal stringer beams along -Y
    for sx in (-1.02, 1.02):
        add_beveled_box(bm, Vector((sx, y_center, 0.50)), Vector((0.16, length, 0.16)), bevel_amt=0.015)

    # 2. 22 uneven transverse deck planks along -Y
    num_planks = 22
    for i in range(num_planks):
        y = -0.35 - i * (12.30 / (num_planks - 1))
        w_var = width + 0.08 * math.sin(i * 1.9)
        d_var = 0.44 + 0.03 * math.cos(i * 2.7)
        z_var = 0.62 + 0.012 * math.sin(i * 3.1)
        yaw_var = 0.020 * math.sin(i * 2.3)
        roll_var = 0.012 * math.cos(i * 1.7)
        add_beveled_box(
            bm,
            Vector((0.0, y, z_var)),
            Vector((w_var, d_var, 0.09)),
            rot_euler=(roll_var, 0.0, yaw_var),
            bevel_amt=0.014,
        )

    # 3. 10 vertical cylindrical support posts (5 pairs) extending down into water
    post_y_positions = [-0.5, -3.5, -6.5, -9.5, -12.4]
    for p_idx, py in enumerate(post_y_positions):
        for side_idx, px in enumerate((-1.15, 1.15)):
            segs = 8
            rings = 3
            z_bot = -1.80
            z_top = 1.12 + 0.05 * math.sin(p_idx + side_idx)
            tilt_x = 0.018 * math.cos(p_idx * 1.7 + side_idx)
            tilt_y = 0.018 * math.sin(p_idx * 2.1)
            p_rings = []
            for r in range(rings + 1):
                t = r / rings
                z = z_bot + (z_top - z_bot) * t
                rad = 0.13 * (1.0 - 0.06 * t)
                rv = []
                for s in range(segs):
                    ang = (s / segs) * math.tau
                    rv.append(
                        bm.verts.new((
                            px + tilt_x * z + math.cos(ang) * rad,
                            py + tilt_y * z + math.sin(ang) * rad,
                            z,
                        ))
                    )
                p_rings.append(rv)
            for r in range(rings):
                for s in range(segs):
                    sn = (s + 1) % segs
                    bm.faces.new((p_rings[r][s], p_rings[r][sn], p_rings[r + 1][sn], p_rings[r + 1][s]))
            bm.faces.new(p_rings[0][::-1])
            bm.faces.new(p_rings[-1])

            if p_idx in (0, 4):
                for coil in range(2):
                    cz = z_top - 0.15 - coil * 0.06
                    ret = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
                    for v in ret["verts"]:
                        v.co = Vector((
                            px + tilt_x * cz + v.co.x * 0.15,
                            py + tilt_y * cz + v.co.y * 0.15,
                            cz + v.co.z * 0.032,
                        ))

    pier_obj = finalize_bmesh_object(bm, "WoodenPier", smooth=False)
    bm.free()

    def pier_color(co, no, idx):
        if co.z > 0.80 and abs(co.x) > 0.98 and (co.y > -0.8 or co.y < -12.1):
            return c_rope
        if co.z < 0.15:
            t_wet = max(0.0, min(1.0, (co.z + 1.0) / 1.15))
            return lerp_color(c_wood_wet, c_wood_dark, t_wet)
        plank_band = int(round(abs(co.y) / 0.56))
        plank_var = 0.5 + 0.5 * math.sin(plank_band * 2.4)
        base = lerp_color(c_wood_dark, c_wood_mid, plank_var * 0.7 + 0.2)
        if no.z > 0.5:
            return lerp_color(base, c_wood_light, 0.55)
        return base

    apply_vertex_color_fn(pier_obj, pier_color, smooth=False)

    out_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "buildings", "pier.glb")
    )
    export_glb(out_path)


if __name__ == "__main__":
    build_pier()
