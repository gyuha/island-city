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


def build_lilypad():
    clear_scene()

    c_pad_edge = hex_to_rgba("#256d4b")
    c_pad_mid = hex_to_rgba("#5bb94f")
    c_pad_center = hex_to_rgba("#81d465")
    c_petal_base = hex_to_rgba("#e86a8c")
    c_petal_tip = hex_to_rgba("#ffd6e4")
    c_stamen = hex_to_rgba("#f2c94c")

    # Target: 100-300 tris
    # 1. Notched circular lily pad (pac-man wedge cut out)
    bm_pad = bmesh.new()
    segs = 20
    radius = 0.46
    thickness = 0.022
    notch_angle = 0.38  # radians half-width

    top_center = bm_pad.verts.new((0.0, 0.0, thickness))
    bot_center = bm_pad.verts.new((0.0, 0.0, 0.0))

    top_ring = []
    bot_ring = []
    for i in range(segs + 1):
        t = i / segs
        ang = notch_angle + t * (math.tau - 2.0 * notch_angle)
        # Gentle organic wave along rim
        r = radius * (1.0 + 0.04 * math.sin(ang * 5.0))
        x = math.cos(ang) * r
        y = math.sin(ang) * r
        z_lip = thickness + 0.008 * math.sin(ang * 3.0)
        top_ring.append(bm_pad.verts.new((x, y, z_lip)))
        bot_ring.append(bm_pad.verts.new((x * 0.96, y * 0.96, 0.0)))

    for i in range(segs):
        bm_pad.faces.new((top_center, top_ring[i], top_ring[i + 1]))
        bm_pad.faces.new((bot_center, bot_ring[i + 1], bot_ring[i]))
        bm_pad.faces.new((top_ring[i], bot_ring[i], bot_ring[i + 1], top_ring[i + 1]))

    # Close the V-notch sides
    bm_pad.faces.new((top_center, bot_center, bot_ring[0], top_ring[0]))
    bm_pad.faces.new((top_center, top_ring[-1], bot_ring[-1], bot_center))

    pad_obj = finalize_bmesh_object(bm_pad, "LilyPadLeaf", smooth=True)
    bm_pad.free()

    def pad_color(co, no, idx):
        dist = min(1.0, math.hypot(co.x, co.y) / radius)
        if co.z < 0.005:
            return c_pad_edge
        if dist < 0.45:
            return lerp_color(c_pad_center, c_pad_mid, dist / 0.45)
        return lerp_color(c_pad_mid, c_pad_edge, (dist - 0.45) / 0.55)

    apply_vertex_color_fn(pad_obj, pad_color, smooth=True)

    # 2. Pink lotus flower on top (2 rings of 6 petals + yellow center dome)
    bm_flower = bmesh.new()
    flower_offset = Vector((-0.05, 0.04, thickness))

    def add_petal(base_pos, yaw, pitch, length, width, height_arch):
        forward = Vector((math.cos(yaw), math.sin(yaw), 0.0))
        side = Vector((-math.sin(yaw), math.cos(yaw), 0.0))
        up = Vector((0.0, 0.0, 1.0))

        p_base = bm_flower.verts.new(base_pos)
        p_mid_l = bm_flower.verts.new(
            base_pos + forward * (length * 0.52) * math.cos(pitch) - side * width + up * (length * 0.52 * math.sin(pitch) + height_arch)
        )
        p_mid_r = bm_flower.verts.new(
            base_pos + forward * (length * 0.52) * math.cos(pitch) + side * width + up * (length * 0.52 * math.sin(pitch) + height_arch)
        )
        p_mid_c = bm_flower.verts.new(
            base_pos + forward * (length * 0.55) * math.cos(pitch) + up * (length * 0.52 * math.sin(pitch))
        )
        p_tip = bm_flower.verts.new(
            base_pos + forward * length * math.cos(pitch) + up * (length * math.sin(pitch) + height_arch * 0.5)
        )
        bm_flower.faces.new((p_base, p_mid_r, p_mid_c))
        bm_flower.faces.new((p_base, p_mid_c, p_mid_l))
        bm_flower.faces.new((p_mid_c, p_mid_r, p_tip))
        bm_flower.faces.new((p_mid_l, p_mid_c, p_tip))

    # Outer 7 petals
    for i in range(7):
        yaw = (i / 7.0) * math.tau
        add_petal(flower_offset + Vector((0, 0, 0.005)), yaw, 0.35, 0.16, 0.052, 0.018)

    # Inner 6 petals
    for i in range(6):
        yaw = (i / 6.0) * math.tau + 0.45
        add_petal(flower_offset + Vector((0, 0, 0.015)), yaw, 0.72, 0.13, 0.044, 0.015)

    # Yellow stamen dome in center
    ret = bmesh.ops.create_icosphere(bm_flower, subdivisions=1, radius=0.042)
    for v in ret["verts"]:
        v.co = flower_offset + Vector((v.co.x, v.co.y, max(0.0, v.co.z * 0.8) + 0.012))

    flower_obj = finalize_bmesh_object(bm_flower, "LotusBlossom", smooth=True)
    bm_flower.free()

    def flower_color(co, no, idx):
        rel = co - flower_offset
        r = math.hypot(rel.x, rel.y)
        if r < 0.046 and rel.z < 0.055:
            return c_stamen
        t = max(0.0, min(1.0, (r - 0.02) / 0.14 + rel.z * 3.0))
        return lerp_color(c_petal_base, c_petal_tip, t)

    apply_vertex_color_fn(flower_obj, flower_color, smooth=True)

    out_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "nature", "lilypad.glb")
    )
    export_glb(out_path)


if __name__ == "__main__":
    build_lilypad()
