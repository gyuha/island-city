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
    get_vertex_color_material,
    count_scene_tris,
)


def paint_new_faces(bm, old_faces_set, color_fn):
    layer = bm.loops.layers.color.get("Color")
    if layer is None:
        layer = bm.loops.layers.color.new("Color")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f not in old_faces_set:
            for loop in f.loops:
                v = loop.vert
                loop[layer] = color_fn(v.co, f.normal)


def finalize_part(bm, name: str, origin: Vector, smooth: bool = True):
    bmesh.ops.translate(bm, vec=-origin, verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    if "Color" in mesh.color_attributes:
        mesh.color_attributes.active_color = mesh.color_attributes["Color"]
        mesh.color_attributes.render_color_index = mesh.color_attributes.find("Color")
    mat = get_vertex_color_material()
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    obj.location = origin
    bpy.context.collection.objects.link(obj)
    return obj


def build_player():
    clear_scene()

    # Exact palette from docs/style-reference/player_sheet.png
    c_skin = hex_to_rgba("#fbe3c8")
    c_skin_shade = hex_to_rgba("#e5c9ae")
    c_blush = hex_to_rgba("#f49b88")
    c_hair_dark = hex_to_rgba("#4d3326")
    c_hair_mid = hex_to_rgba("#694635")
    c_eye_dark = hex_to_rgba("#1b4349")
    c_eye_teal = hex_to_rgba("#388882")
    c_eye_white = hex_to_rgba("#ffffff")

    c_hat_yellow = hex_to_rgba("#f5c84c")
    c_hat_shade = hex_to_rgba("#dfa836")
    c_ribbon_coral = hex_to_rgba("#e86652")
    c_ribbon_shade = hex_to_rgba("#c94e3c")
    c_leaf_green = hex_to_rgba("#76c84d")
    c_leaf_tip = hex_to_rgba("#a8e06c")

    c_scarf_mint = hex_to_rgba("#52cfa8")
    c_scarf_shade = hex_to_rgba("#359e84")
    c_poncho_coral = hex_to_rgba("#e86652")
    c_poncho_shade = hex_to_rgba("#cc5240")
    c_poncho_cream = hex_to_rgba("#f7ebd2")
    c_shorts_navy = hex_to_rgba("#1f4d5c")

    c_bag_tan = hex_to_rgba("#c99456")
    c_bag_shade = hex_to_rgba("#a8763e")
    c_strap_brown = hex_to_rgba("#6e472c")
    c_buckle_gold = hex_to_rgba("#f5c84c")
    c_boot_brown = hex_to_rgba("#6b462e")
    c_boot_cuff = hex_to_rgba("#f3e3c6")

    # =========================================================================
    # 1. HEAD (Pivot at neck: (0, 0, 0.50), total height reaches Z = 1.00m)
    # Front is +Y in Blender (-Z in Godot)
    # =========================================================================
    bm_head = bmesh.new()

    # 1a. Face sphere
    old = set(bm_head.faces)
    ret_h = bmesh.ops.create_uvsphere(bm_head, u_segments=28, v_segments=18, radius=1.0)
    for v in ret_h["verts"]:
        nx, ny, nz = v.co.x, v.co.y, v.co.z
        cheek = 1.0 + 0.08 * max(0.0, -nz) * (1.0 - abs(nz))
        v.co = Vector((nx * 0.162 * cheek, ny * 0.152 * cheek, 0.635 + nz * 0.142))

    def face_col(co, no):
        if co.y > 0.115 and 0.575 < co.z < 0.618 and 0.072 < abs(co.x) < 0.125:
            return lerp_color(c_skin, c_blush, 0.68)
        return lerp_color(c_skin_shade, c_skin, max(0.0, (no.z + 0.8) / 1.8))

    paint_new_faces(bm_head, old, face_col)

    # 1b. Ears
    old = set(bm_head.faces)
    for sign in (-1.0, 1.0):
        ret = bmesh.ops.create_icosphere(bm_head, subdivisions=2, radius=1.0)
        for v in ret["verts"]:
            v.co = Vector((sign * 0.162 + v.co.x * 0.030, 0.01 + v.co.y * 0.022, 0.622 + v.co.z * 0.036))
    paint_new_faces(bm_head, old, lambda co, no: c_skin)

    # 1c. Eyes + white highlight dots on front (+Y)
    for sign in (-1.0, 1.0):
        old = set(bm_head.faces)
        ret_e = bmesh.ops.create_icosphere(bm_head, subdivisions=2, radius=1.0)
        for v in ret_e["verts"]:
            v.co = Vector((sign * 0.062 + v.co.x * 0.028, 0.150 + v.co.y * 0.016, 0.625 + v.co.z * 0.038))
        paint_new_faces(
            bm_head,
            old,
            lambda co, no: c_eye_teal if co.z < 0.615 else c_eye_dark,
        )
        old = set(bm_head.faces)
        ret_sp = bmesh.ops.create_icosphere(bm_head, subdivisions=1, radius=1.0)
        for v in ret_sp["verts"]:
            v.co = Vector((sign * 0.052 + v.co.x * 0.011, 0.165 + v.co.y * 0.008, 0.640 + v.co.z * 0.011))
        paint_new_faces(bm_head, old, lambda co, no: c_eye_white)

    # 1d. Fluffy chestnut hair tufts (bangs, side locks, back hair)
    old = set(bm_head.faces)
    hair_blobs = [
        (0.00, 0.142, 0.705, 0.065, 0.038, 0.045),
        (-0.072, 0.130, 0.695, 0.058, 0.038, 0.045),
        (0.072, 0.130, 0.695, 0.058, 0.038, 0.045),
        (-0.152, 0.035, 0.622, 0.050, 0.062, 0.092),
        (0.152, 0.035, 0.622, 0.050, 0.062, 0.092),
        (-0.172, -0.015, 0.592, 0.046, 0.052, 0.062),
        (0.172, -0.015, 0.592, 0.046, 0.052, 0.062),
        (0.00, -0.045, 0.650, 0.172, 0.152, 0.132),
        (-0.102, -0.112, 0.575, 0.072, 0.062, 0.062),
        (0.102, -0.112, 0.575, 0.072, 0.062, 0.062),
        (0.00, -0.132, 0.565, 0.082, 0.062, 0.062),
    ]
    for cx, cy, cz, rx, ry, rz in hair_blobs:
        ret = bmesh.ops.create_icosphere(bm_head, subdivisions=2, radius=1.0)
        for v in ret["verts"]:
            v.co = Vector((cx + v.co.x * rx, cy + v.co.y * ry, cz + v.co.z * rz))
    paint_new_faces(
        bm_head,
        old,
        lambda co, no: lerp_color(c_hair_dark, c_hair_mid, max(0.0, (no.z + 0.8) / 1.8)),
    )

    # 1e. Wide sunny-yellow sun hat + coral ribbon band (tilted back +0.24 rad so face is open in front)
    hat_tilt = 0.24
    rot_hat = Euler((hat_tilt, 0.0, 0.0), "XYZ").to_matrix()
    hat_center = Vector((0.0, -0.020, 0.735))

    hat_segs = 32
    hat_profile = [
        (0.320, -0.035),
        (0.328, -0.015),
        (0.255, 0.010),
        (0.196, 0.024),
        (0.198, 0.066),
        (0.180, 0.115),
        (0.125, 0.155),
        (0.055, 0.175),
        (0.000, 0.180),
    ]
    h_rings = []
    for rad, lz in hat_profile:
        if rad == 0.0:
            v_top = bm_head.verts.new(hat_center + rot_hat @ Vector((0.0, 0.0, lz)))
            h_rings.append([v_top])
        else:
            rv = []
            for s in range(hat_segs):
                ang = (s / hat_segs) * math.tau
                pt_local = Vector((math.cos(ang) * rad, math.sin(ang) * rad * 0.96, lz))
                rv.append(bm_head.verts.new(hat_center + rot_hat @ pt_local))
            h_rings.append(rv)

    old_hat = set(bm_head.faces)
    v_bot_c = bm_head.verts.new(hat_center + rot_hat @ Vector((0.0, 0.0, -0.01)))
    for s in range(hat_segs):
        sn = (s + 1) % hat_segs
        bm_head.faces.new((v_bot_c, h_rings[0][sn], h_rings[0][s]))

    ribbon_faces = set()
    for r_idx in range(len(h_rings) - 1):
        r0 = h_rings[r_idx]
        r1 = h_rings[r_idx + 1]
        if len(r1) == 1:
            for s in range(hat_segs):
                sn = (s + 1) % hat_segs
                bm_head.faces.new((r0[s], r0[sn], r1[0]))
        else:
            for s in range(hat_segs):
                sn = (s + 1) % hat_segs
                f = bm_head.faces.new((r0[s], r0[sn], r1[sn], r1[s]))
                if r_idx == 3:  # exact ribbon band ring
                    ribbon_faces.add(f)

    paint_new_faces(
        bm_head,
        old_hat,
        lambda co, no: lerp_color(c_hat_shade, c_hat_yellow, max(0.0, (no.z + 0.6) / 1.6)),
    )
    # Paint ribbon band ring coral
    layer = bm_head.loops.layers.color.get("Color")
    for f in ribbon_faces:
        for loop in f.loops:
            loop[layer] = c_ribbon_coral

    # 1f. Coral ribbon bow on back of hat (-Y)
    old = set(bm_head.faces)
    for sign in (-1.0, 1.0):
        ret_b = bmesh.ops.create_icosphere(bm_head, subdivisions=2, radius=1.0)
        for v in ret_b["verts"]:
            pt = Vector((sign * (0.062 + v.co.x * 0.052), -0.202 + v.co.y * 0.022, 0.045 + v.co.z * 0.036))
            v.co = hat_center + rot_hat @ pt
        ret_t = bmesh.ops.create_icosphere(bm_head, subdivisions=2, radius=1.0)
        for v in ret_t["verts"]:
            pt = Vector((
                sign * (0.050 + v.co.x * 0.030 - v.co.z * 0.018),
                -0.212 + v.co.y * 0.016,
                -0.035 + v.co.z * 0.062,
            ))
            v.co = hat_center + rot_hat @ pt
    paint_new_faces(
        bm_head,
        old,
        lambda co, no: lerp_color(c_ribbon_shade, c_ribbon_coral, max(0.0, (no.z + 0.7) / 1.7)),
    )

    # 1g. Twin green leaf sprout on very top of hat (reaches Z = 1.00m)
    old = set(bm_head.faces)
    sprout_base = hat_center + rot_hat @ Vector((0.0, 0.0, 0.175))
    for sign, l_scale, pitch in ((-1.0, 0.095, 0.65), (1.0, 0.115, 0.85)):
        ret_l = bmesh.ops.create_icosphere(bm_head, subdivisions=2, radius=1.0)
        for v in ret_l["verts"]:
            u = (v.co.x + 1.0) * 0.5
            lx = sign * (0.01 + u * l_scale * math.cos(pitch))
            ly = v.co.y * 0.028 * math.sin(u * math.pi)
            lz = u * l_scale * math.sin(pitch) + v.co.z * 0.016 * math.sin(u * math.pi)
            v.co = sprout_base + Vector((lx, ly, lz))
    paint_new_faces(
        bm_head,
        old,
        lambda co, no: lerp_color(c_leaf_green, c_leaf_tip, min(1.0, max(0.0, (co.z - 0.885) / 0.115))),
    )

    finalize_part(bm_head, "Head", Vector((0.0, 0.0, 0.50)), smooth=True)
    bm_head.free()

    # =========================================================================
    # 2. BODY (Pivot at (0, 0, 0.34))
    # =========================================================================
    bm_body = bmesh.new()

    # 2a. Flared A-line coral poncho with cream geometric hem band
    old = set(bm_body.faces)
    p_segs = 32
    p_rings = 10
    ring_v = []
    for i in range(p_rings + 1):
        t = i / p_rings
        z = 0.24 + t * 0.27
        rx = 0.225 * (1.0 - t * 0.49) + 0.015 * math.sin(t * math.pi)
        ry = 0.185 * (1.0 - t * 0.48) + 0.012 * math.sin(t * math.pi)
        rv = []
        for s in range(p_segs):
            ang = (s / p_segs) * math.tau
            rv.append(bm_body.verts.new((math.cos(ang) * rx, math.sin(ang) * ry, z)))
        ring_v.append(rv)
    for i in range(p_rings):
        for s in range(p_segs):
            sn = (s + 1) % p_segs
            bm_body.faces.new((ring_v[i][s], ring_v[i][sn], ring_v[i + 1][sn], ring_v[i + 1][s]))
    bm_body.faces.new(ring_v[0][::-1])
    bm_body.faces.new(ring_v[-1])

    def poncho_col(co, no):
        if co.z < 0.305:
            ang = math.atan2(co.y, co.x)
            tri_wave = math.sin(ang * 12.0)
            local_h = (co.z - 0.24) / (0.305 - 0.24)
            if 0.18 < local_h < 0.82 and local_h > (0.5 + 0.32 * tri_wave):
                return c_poncho_coral
            return c_poncho_cream
        return lerp_color(c_poncho_shade, c_poncho_coral, max(0.0, (no.z + 0.8) / 1.8))

    paint_new_faces(bm_body, old, poncho_col)

    # 2b. Mint-teal neckerchief collar & front knot tails (+Y)
    old = set(bm_body.faces)
    ret_sc = bmesh.ops.create_uvsphere(bm_body, u_segments=20, v_segments=10, radius=1.0)
    for v in ret_sc["verts"]:
        v.co = Vector((v.co.x * 0.138, v.co.y * 0.125 + 0.01, 0.495 + v.co.z * 0.032))
    for sign in (-1.0, 1.0):
        ret_st = bmesh.ops.create_icosphere(bm_body, subdivisions=2, radius=1.0)
        for v in ret_st["verts"]:
            v.co = Vector((
                sign * (0.036 + v.co.x * 0.026),
                0.145 + v.co.y * 0.018,
                0.435 + v.co.z * 0.052,
            ))
    paint_new_faces(
        bm_body,
        old,
        lambda co, no: lerp_color(c_scarf_shade, c_scarf_mint, max(0.0, (no.z + 0.8) / 1.8)),
    )

    # 2c. Navy shorts pelvis block
    old = set(bm_body.faces)
    for sign in (-1.0, 1.0):
        ret_sh = bmesh.ops.create_uvsphere(bm_body, u_segments=16, v_segments=10, radius=1.0)
        for v in ret_sh["verts"]:
            v.co = Vector((sign * 0.075 + v.co.x * 0.088, v.co.y * 0.105, 0.215 + v.co.z * 0.055))
    paint_new_faces(bm_body, old, lambda co, no: c_shorts_navy)

    # 2d. Tan leather backpack on back (-Y)
    old = set(bm_body.faces)
    ret_bag = bmesh.ops.create_icosphere(bm_body, subdivisions=3, radius=1.0)
    for v in ret_bag["verts"]:
        nx, ny, nz = v.co.x, v.co.y, v.co.z
        sx = math.copysign(abs(nx) ** 0.65, nx) * 0.122
        sy = math.copysign(abs(ny) ** 0.65, ny) * 0.065
        sz = math.copysign(abs(nz) ** 0.65, nz) * 0.105
        v.co = Vector((sx, -0.175 + sy, 0.365 + sz))

    def bag_col(co, no):
        if co.y < -0.222 and abs(co.x) < 0.028 and 0.330 < co.z < 0.375:
            return c_buckle_gold
        if co.y < -0.218 and abs(co.x) < 0.022 and 0.270 < co.z < 0.415:
            return c_strap_brown
        return lerp_color(c_bag_shade, c_bag_tan, max(0.0, (no.z + 0.8) / 1.8))

    paint_new_faces(bm_body, old, bag_col)

    # 2e. Front shoulder straps (+Y) with gold buckles
    old = set(bm_body.faces)
    for sign in (-1.0, 1.0):
        ret_str = bmesh.ops.create_icosphere(bm_body, subdivisions=2, radius=1.0)
        for v in ret_str["verts"]:
            v.co = Vector((
                sign * 0.095 + v.co.x * 0.018,
                0.142 + v.co.y * 0.015 - (v.co.z * 0.035),
                0.405 + v.co.z * 0.085,
            ))
    paint_new_faces(
        bm_body,
        old,
        lambda co, no: c_buckle_gold if 0.405 < co.z < 0.435 else c_strap_brown,
    )

    finalize_part(bm_body, "Body", Vector((0.0, 0.0, 0.34)), smooth=True)
    bm_body.free()

    # =========================================================================
    # 3. LEFT ARM & RIGHT ARM (Pivots at shoulders: (±0.155, 0.0, 0.455))
    # =========================================================================
    for side_name, sign in (("LeftArm", -1.0), ("RightArm", 1.0)):
        bm_arm = bmesh.new()
        shoulder = Vector((sign * 0.155, 0.0, 0.455))
        old = set(bm_arm.faces)
        a_segs = 16
        a_rings = 6
        s_rings = []
        for i in range(a_rings + 1):
            t = i / a_rings
            center = shoulder + Vector((sign * t * 0.095, 0.0, -t * 0.135))
            rad = 0.048 + t * 0.032
            rv = []
            for s in range(a_segs):
                ang = (s / a_segs) * math.tau
                rv.append(
                    bm_arm.verts.new(
                        center + Vector((math.cos(ang) * rad * 0.85, math.sin(ang) * rad, 0.0))
                    )
                )
            s_rings.append(rv)
        for i in range(a_rings):
            for s in range(a_segs):
                sn = (s + 1) % a_segs
                bm_arm.faces.new((s_rings[i][s], s_rings[i][sn], s_rings[i + 1][sn], s_rings[i + 1][s]))
        bm_arm.faces.new(s_rings[0][::-1])
        bm_arm.faces.new(s_rings[-1])
        paint_new_faces(
            bm_arm,
            old,
            lambda co, no: c_poncho_cream if co.z < 0.355 else c_poncho_coral,
        )

        old = set(bm_arm.faces)
        hand_center = shoulder + Vector((sign * 0.115, 0.0, -0.160))
        ret_hand = bmesh.ops.create_icosphere(bm_arm, subdivisions=2, radius=0.042)
        for v in ret_hand["verts"]:
            v.co = hand_center + v.co
        paint_new_faces(bm_arm, old, lambda co, no: c_skin)

        finalize_part(bm_arm, side_name, shoulder, smooth=True)
        bm_arm.free()

    # =========================================================================
    # 4. LEFT LEG & RIGHT LEG (Pivots at hips: (±0.078, 0.0, 0.20), sole at Z=0.0)
    # =========================================================================
    for leg_name, sign in (("LeftLeg", -1.0), ("RightLeg", 1.0)):
        bm_leg = bmesh.new()
        lx = sign * 0.078
        old = set(bm_leg.faces)
        l_segs = 16
        l_rings = 5
        lv = []
        for i in range(l_rings + 1):
            t = i / l_rings
            z = 0.085 + t * 0.120
            rad = 0.048
            rv = []
            for s in range(l_segs):
                ang = (s / l_segs) * math.tau
                rv.append(bm_leg.verts.new((lx + math.cos(ang) * rad, math.sin(ang) * rad, z)))
            lv.append(rv)
        for i in range(l_rings):
            for s in range(l_segs):
                sn = (s + 1) % l_segs
                bm_leg.faces.new((lv[i][s], lv[i][sn], lv[i + 1][sn], lv[i + 1][s]))
        bm_leg.faces.new(lv[-1])
        paint_new_faces(
            bm_leg,
            old,
            lambda co, no: c_shorts_navy if co.z > 0.172 else c_skin,
        )

        old = set(bm_leg.faces)
        ret_cuff = bmesh.ops.create_uvsphere(bm_leg, u_segments=16, v_segments=8, radius=1.0)
        for v in ret_cuff["verts"]:
            v.co = Vector((lx + v.co.x * 0.058, v.co.y * 0.060, 0.092 + v.co.z * 0.020))
        paint_new_faces(bm_leg, old, lambda co, no: c_boot_cuff)

        old = set(bm_leg.faces)
        ret_boot = bmesh.ops.create_uvsphere(bm_leg, u_segments=18, v_segments=10, radius=1.0)
        for v in ret_boot["verts"]:
            nx, ny, nz = v.co.x, v.co.y, v.co.z
            z = 0.042 + nz * 0.042
            if nz < 0.0:
                z = max(0.0, (nz + 1.0) * 0.042)
            fwd_shift = 0.018 if ny > 0 else 0.0
            v.co = Vector((lx + nx * 0.056, ny * 0.072 + fwd_shift, z))
        paint_new_faces(
            bm_leg,
            old,
            lambda co, no: c_boot_cuff if co.z < 0.014 else c_boot_brown,
        )

        finalize_part(bm_leg, leg_name, Vector((lx, 0.0, 0.20)), smooth=True)
        bm_leg.free()

    out_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "characters", "player.glb")
    )
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    tris = count_scene_tris()
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        export_yup=True,
        export_apply=False,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=True,
        export_active_vertex_color_when_no_material=True,
        export_cameras=False,
        export_lights=False,
    )
    print(f"[EXPORTED] {out_path} | Total Tris: {tris}")


if __name__ == "__main__":
    build_player()
