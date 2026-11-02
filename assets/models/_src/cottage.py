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


def add_box(bm, center: Vector, size: Vector, rot_euler=(0.0, 0.0, 0.0), bevel_amt=0.02):
    ret = bmesh.ops.create_cube(bm, size=1.0)
    verts = ret["verts"]
    rot_mat = Euler(rot_euler, "XYZ").to_matrix().to_4x4()
    scale_mat = Matrix.Diagonal((size.x, size.y, size.z, 1.0))
    xform = Matrix.Translation(center) @ rot_mat @ scale_mat
    bmesh.ops.transform(bm, matrix=xform, verts=verts)
    if bevel_amt > 0.0:
        edges = list({e for v in verts for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=edges, offset=bevel_amt, segments=1, affect="EDGES")


def build_cottage():
    clear_scene()

    # Palette matching keyart_02.png & docs/art-style-prompts.md 4.3
    c_wall_light = hex_to_rgba("#f7f0de")
    c_wall_shadow = hex_to_rgba("#d8e6df")
    c_stone_base = hex_to_rgba("#7c96a6")
    c_stone_light = hex_to_rgba("#9bb2bf")
    c_timber_dark = hex_to_rgba("#6b4428")
    c_timber_light = hex_to_rgba("#8f5d38")
    c_roof_dark = hex_to_rgba("#c44937")
    c_roof_mid = hex_to_rgba("#d95f4b")
    c_roof_light = hex_to_rgba("#eb7b65")
    c_window_glow = hex_to_rgba("#ffe380")
    c_door_wood = hex_to_rgba("#825332")

    # Target: 2k-5k tris (cozy cottage, white plaster walls, red tiled roof, wooden door, chimney, chunky proportions)
    # Front faces +Y in Blender (-Z in Godot)

    # 1. Foundation + Walls + Timber Framing + Chimney + Door + Windows
    bm_base = bmesh.new()

    # Stone foundation plinth
    add_box(bm_base, Vector((0.0, 0.0, 0.22)), Vector((4.20, 3.60, 0.44)), bevel_amt=0.04)
    # Front porch stone step (+Y)
    add_box(bm_base, Vector((0.0, 2.05, 0.14)), Vector((1.65, 0.65, 0.28)), bevel_amt=0.03)

    # Main plaster wall body with gabled roof peak at Z=3.85
    w_x, w_y = 1.92, 1.62
    z_bot, z_eave, z_peak = 0.42, 2.45, 3.82
    v_bl_f = bm_base.verts.new((-w_x, w_y, z_bot))
    v_br_f = bm_base.verts.new((w_x, w_y, z_bot))
    v_bl_b = bm_base.verts.new((-w_x, -w_y, z_bot))
    v_br_b = bm_base.verts.new((w_x, -w_y, z_bot))

    v_tl_f = bm_base.verts.new((-w_x, w_y, z_eave))
    v_tr_f = bm_base.verts.new((w_x, w_y, z_eave))
    v_tl_b = bm_base.verts.new((-w_x, -w_y, z_eave))
    v_tr_b = bm_base.verts.new((w_x, -w_y, z_eave))

    v_pk_f = bm_base.verts.new((0.0, w_y, z_peak))
    v_pk_b = bm_base.verts.new((0.0, -w_y, z_peak))

    # Walls + gables
    bm_base.faces.new((v_bl_f, v_br_f, v_tr_f, v_tl_f))
    bm_base.faces.new((v_tl_f, v_tr_f, v_pk_f))
    bm_base.faces.new((v_br_b, v_bl_b, v_tl_b, v_tr_b))
    bm_base.faces.new((v_tr_b, v_tl_b, v_pk_b))
    bm_base.faces.new((v_bl_b, v_bl_f, v_tl_f, v_tl_b))
    bm_base.faces.new((v_br_f, v_br_b, v_tr_b, v_tr_f))
    bm_base.faces.new((v_tl_b, v_tl_f, v_pk_f, v_pk_b))
    bm_base.faces.new((v_tr_f, v_tr_b, v_pk_b, v_pk_f))

    # Corner timber posts & horizontal beams
    for sx in (-1.94, 1.94):
        for sy in (-1.64, 1.64):
            add_box(bm_base, Vector((sx, sy, 1.44)), Vector((0.18, 0.18, 2.08)), bevel_amt=0.015)
    for sy in (-1.64, 1.64):
        add_box(bm_base, Vector((0.0, sy, 2.42)), Vector((4.02, 0.16, 0.16)), bevel_amt=0.015)
    for sx in (-1.94, 1.94):
        add_box(bm_base, Vector((sx, 0.0, 2.42)), Vector((0.16, 3.42, 0.16)), bevel_amt=0.015)

    # Front door (+Y) & frame + porch posts
    add_box(bm_base, Vector((0.0, 1.63, 1.24)), Vector((0.92, 0.14, 1.64)), bevel_amt=0.02)
    add_box(bm_base, Vector((0.0, 1.68, 1.20)), Vector((0.74, 0.10, 1.52)), bevel_amt=0.015)
    for px in (-0.72, 0.72):
        add_box(bm_base, Vector((px, 2.22, 1.18)), Vector((0.14, 0.14, 1.82)), bevel_amt=0.015)

    # Windows on front (+Y) and sides (±X)
    win_front_x = [-1.18, 1.18]
    for wx in win_front_x:
        add_box(bm_base, Vector((wx, 1.63, 1.48)), Vector((0.68, 0.14, 0.72)), bevel_amt=0.015)
        add_box(bm_base, Vector((wx, 1.67, 1.48)), Vector((0.52, 0.08, 0.56)), bevel_amt=0.01)
        # Window flower box
        add_box(bm_base, Vector((wx, 1.74, 1.06)), Vector((0.74, 0.22, 0.16)), bevel_amt=0.015)

    for sx in (-1.93, 1.93):
        for wy in (-0.65, 0.65):
            add_box(bm_base, Vector((sx, wy, 1.48)), Vector((0.14, 0.68, 0.72)), bevel_amt=0.015)
            add_box(bm_base, Vector((sx + (0.04 if sx > 0 else -0.04), wy, 1.48)), Vector((0.08, 0.52, 0.56)), bevel_amt=0.01)

    # Stone Chimney on right slope (+X, -Y)
    add_box(bm_base, Vector((1.25, -0.75, 2.95)), Vector((0.68, 0.68, 2.80)), bevel_amt=0.03)
    add_box(bm_base, Vector((1.25, -0.75, 4.38)), Vector((0.80, 0.80, 0.18)), bevel_amt=0.02)

    base_obj = finalize_bmesh_object(bm_base, "CottageBase", smooth=False)
    bm_base.free()

    def base_color(co, no, idx):
        # Chimney stone & foundation stone
        if co.z < 0.44 or (co.x > 0.85 and co.y < -0.35 and co.z > 2.48):
            return lerp_color(c_stone_base, c_stone_light, max(0.0, min(1.0, (no.z + 0.6) / 1.6)))
        # Glowing windows
        if 1.19 < co.z < 1.77:
            if abs(co.y) > 1.65 and 0.90 < abs(co.x) < 1.45:
                return c_window_glow
            if abs(co.x) > 1.95 and 0.38 < abs(co.y) < 0.92:
                return c_window_glow
        # Front door wood
        if co.y > 1.66 and abs(co.x) < 0.38 and co.z < 1.98:
            return c_door_wood
        # Timber beams, frames, porch posts, flower boxes
        if (
            (abs(co.x) > 1.84 and abs(co.y) > 1.54)
            or (2.33 < co.z < 2.51 and (abs(co.x) > 1.85 or abs(co.y) > 1.55))
            or (co.y > 1.60 and abs(co.x) < 0.85 and co.z < 2.15)
            or (1.10 < co.z < 1.86 and (abs(co.y) > 1.60 or abs(co.x) > 1.90))
            or (0.96 < co.z < 1.16 and co.y > 1.62)
        ):
            return lerp_color(c_timber_dark, c_timber_light, max(0.0, no.z * 0.5 + 0.5))
        # White-cream plaster walls with soft teal underside shading
        return lerp_color(c_wall_shadow, c_wall_light, max(0.0, min(1.0, (no.z + 0.8) / 1.8)))

    apply_vertex_color_fn(base_obj, base_color, smooth=False)

    # 2. Chunky scalloped terracotta-red roof tiles + front porch awning (~2.2k tris)
    bm_roof = bmesh.new()
    slope_angle = math.atan2(z_peak - z_eave + 0.12, w_x + 0.35)

    # Underlying solid roof slabs
    for sign in (-1.0, 1.0):
        cx = sign * 1.18
        cz = 3.16
        add_box(
            bm_roof,
            Vector((cx, 0.0, cz)),
            Vector((2.58, 4.05, 0.14)),
            rot_euler=(0.0, sign * slope_angle, 0.0),
            bevel_amt=0.02,
        )

    # Chunky rows of rounded terracotta roof tiles on left and right slopes
    rows_down = 4
    cols_along_y = 7
    for sign in (-1.0, 1.0):
        for r in range(rows_down):
            u = (r + 0.5) / rows_down
            rx = sign * (0.24 + u * 2.02)
            rz = 3.88 - u * 1.50
            for c in range(cols_along_y):
                ry = -1.80 + c * (3.60 / (cols_along_y - 1))
                add_box(
                    bm_roof,
                    Vector((rx, ry, rz)),
                    Vector((0.58, 0.50, 0.11)),
                    rot_euler=(0.0, sign * (slope_angle - 0.06), 0.0),
                    bevel_amt=0.018,
                )

    # Ridge cap tiles along top peak
    for c in range(cols_along_y):
        ry = -1.80 + c * (3.60 / (cols_along_y - 1))
        add_box(bm_roof, Vector((0.0, ry, 3.96)), Vector((0.32, 0.50, 0.14)), bevel_amt=0.02)

    # Front porch terracotta awning over door (+Y)
    for c in range(5):
        px = -0.68 + c * 0.34
        add_box(
            bm_roof,
            Vector((px, 2.02, 2.18)),
            Vector((0.31, 0.78, 0.10)),
            rot_euler=(0.32, 0.0, 0.0),
            bevel_amt=0.02,
        )

    roof_obj = finalize_bmesh_object(bm_roof, "CottageRoof", smooth=False)
    bm_roof.free()

    def roof_color(co, no, idx):
        tile_band = int(round((co.y + 2.5) / 0.33)) + int(round(abs(co.x) / 0.40))
        var = 0.5 + 0.5 * math.sin(tile_band * 2.1)
        base = lerp_color(c_roof_dark, c_roof_mid, var)
        if no.z > 0.65:
            return lerp_color(base, c_roof_light, (no.z - 0.65) / 0.35 * 0.75)
        return base

    apply_vertex_color_fn(roof_obj, roof_color, smooth=False)

    out_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "buildings", "cottage.glb")
    )
    export_glb(out_path)


if __name__ == "__main__":
    build_cottage()
