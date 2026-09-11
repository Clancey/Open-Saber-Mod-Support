"""Procedural meshes for Open Saber, generated from scratch with Blender.

Every mesh under ``game/assets/beatsaber/meshes`` is built here out of plain
primitives: a tree is a trunk with a conical canopy, a pumpkin is a ribbed
spheroid with a stem, a car is a hull with four wheels. Nothing is imported or
traced; each shape is only fitted to the size listed in ``mesh_dims.json`` so
the environment scenes keep their layout and the gameplay objects keep their
hitboxes.

Build shapes Z-up (Blender's habit), then convert to the Y-up axes Godot's OBJ
importer expects and stretch the result onto the target bounding box.

Run:  blender --background --python tools/art/gen_meshes.py
"""

import bmesh
import json
import math
import os
import re
import sys

from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DIMS = os.path.join(HERE, "mesh_dims.json")
OUT = os.path.join(ROOT, "game", "assets", "beatsaber", "meshes")


# ----------------------------------------------------------------- primitives
def _cube(bm, sx=1.0, sy=1.0, sz=1.0, at=(0.0, 0.0, 0.0)):
    vs = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=vs)
    bmesh.ops.translate(bm, vec=at, verts=vs)
    return vs


def _cyl(bm, r=0.5, h=1.0, seg=16, at=(0.0, 0.0, 0.0), r2=None):
    vs = bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=seg,
        radius1=r, radius2=r if r2 is None else r2, depth=h,
    )["verts"]
    bmesh.ops.translate(bm, vec=at, verts=vs)
    return vs


def _sphere(bm, r=0.5, u=16, v=8, at=(0.0, 0.0, 0.0)):
    vs = bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=r)["verts"]
    bmesh.ops.translate(bm, vec=at, verts=vs)
    return vs


def _ico(bm, subd=1, r=0.5, at=(0.0, 0.0, 0.0)):
    vs = bmesh.ops.create_icosphere(bm, subdivisions=subd, radius=r)["verts"]
    bmesh.ops.translate(bm, vec=at, verts=vs)
    return vs


def _bevel(bm, offset, segments=2):
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    bmesh.ops.bevel(
        bm, geom=geom, offset=offset, segments=segments,
        affect="EDGES", profile=0.5, clamp_overlap=True,
    )


def _frame(bm, w, d, h, t):
    """Hollow rectangular frame of wall thickness ``t`` in the X/Z plane."""
    _cube(bm, w, d, t, (0, 0, (h - t) / 2))
    _cube(bm, w, d, t, (0, 0, -(h - t) / 2))
    _cube(bm, t, d, h - 2 * t, ((w - t) / 2, 0, 0))
    _cube(bm, t, d, h - 2 * t, (-(w - t) / 2, 0, 0))


# ------------------------------------------------------------------- builders
# Each builder fills ``bm`` in Z-up space; w/d/h are the target width, depth
# and height. Returning True asks for smooth shading.
def b_box(bm, w, d, h):
    _cube(bm, w, d, h)
    return False


def b_rounded_box(bm, w, d, h):
    _cube(bm, w, d, h)
    _bevel(bm, min(w, d, h) * 0.08, 2)
    return False


def b_plane(bm, w, d, h):
    _cube(bm, w, d, max(h, min(w, d) * 0.004))
    return False


def b_sphere(bm, w, d, h):
    _sphere(bm, 0.5, 20, 12)
    return True


def b_hemisphere(bm, w, d, h):
    vs = _sphere(bm, 0.5, 24, 14)
    for v in vs:
        if v.co.z < 0.0:
            v.co.z = 0.0
    return True


def b_cylinder(bm, w, d, h):
    _cyl(bm, 0.5, 1.0, 20)
    return True


def b_cone(bm, w, d, h):
    _cyl(bm, 0.5, 1.0, 20, r2=0.0)
    return True


def b_triangle(bm, w, d, h):
    _cyl(bm, 0.5, 1.0, 3)
    return False


def b_square_ring(bm, w, d, h):
    _frame(bm, w, d, h, max(w, h) * 0.035)
    return False


def b_construction(bm, w, d, h):
    """Open truss: an outer frame crossed by a few braces."""
    t = max(w, h) * 0.05
    _frame(bm, w, d, h, t)
    for i in range(3):
        x = -w / 2 + w * (i + 1) / 4.0
        _cube(bm, t * 0.7, d * 0.7, h - 2 * t, (x, 0, 0))
    return False


def b_columns(bm, w, d, h):
    n = max(2, min(6, int(round(w / max(h * 0.25, 1e-6)))))
    r = min(w / (n * 2.4), d * 0.45) or w * 0.05
    for i in range(n):
        x = -w / 2 + w * (i + 0.5) / n
        _cyl(bm, r, h, 12, (x, 0, 0))
    return True


def b_pillar(bm, w, d, h):
    _cyl(bm, min(w, d) * 0.5, h, 12)
    return True


def b_building(bm, w, d, h):
    """Blocky tower: a base slab with two narrower setbacks."""
    _cube(bm, w, d, h * 0.6, (0, 0, -h * 0.2))
    _cube(bm, w * 0.7, d * 0.7, h * 0.28, (0, 0, h * 0.24))
    _cube(bm, w * 0.4, d * 0.4, h * 0.14, (0, 0, h * 0.45))
    return False


def b_buildings(bm, w, d, h):
    """Skyline: towers of varying height spread over the whole footprint."""
    for i in range(6):
        for j in range(3):
            cx = -w / 2 + w * (i + 0.5) / 6.0
            cy = -d / 2 + d * (j + 0.5) / 3.0
            bh = h * (0.35 + 0.18 * ((i * 5 + j * 3) % 4))
            _cube(bm, w / 11.0, d / 5.5, bh, (cx, cy, -h / 2 + bh / 2))
    return False


def b_mountains(bm, w, d, h):
    for i in range(4):
        x = -w / 2 + w * (i + 0.5) / 4.0
        ph = h * (0.6 + 0.15 * ((i * 3) % 3))
        _cyl(bm, w / 7.0, ph, 5, (x, 0, -h / 2 + ph / 2), r2=0.0)
    return False


def b_cloud(bm, w, d, h):
    """Layer of puffs scattered over the patch, each about as thick as the layer."""
    r = max(h * 0.55, 1e-5)
    nx = max(1, int(w / (r * 2.2)))
    ny = max(1, int(d / (r * 2.2)))
    for i in range(nx):
        for j in range(ny):
            cx = -w / 2 + w * (i + 0.5) / nx
            cy = -d / 2 + d * (j + 0.5) / ny
            k = (i * 7 + j * 13) % 5
            for m in range(3):
                a = m * 2.1 + k
                _ico(bm, 1, r * (0.62 + 0.12 * ((k + m) % 3)),
                     (cx + math.cos(a) * r * 0.5, cy + math.sin(a) * r * 0.4, 0))
    return True


def _tree_at(bm, w, d, h, at):
    """One conifer. Flat when the source is a billboard card with no depth."""
    flat = d < w * 0.08
    dd = max(d, w * 0.06)
    _cyl(bm, w * 0.06, h * 0.42, 8, (at[0], at[1], at[2] - h * 0.29))
    if flat:
        for sc, zz in ((1.0, -0.02), (0.72, 0.22), (0.42, 0.42)):
            _cube(bm, w * sc, dd, h * 0.24, (at[0], at[1], at[2] + h * zz))
    else:
        _cyl(bm, w * 0.5, h * 0.62, 10, (at[0], at[1], at[2] + h * 0.19), r2=0.0)


def b_tree(bm, w, d, h):
    _tree_at(bm, w, d, h, (0, 0, 0))
    return False


def b_trees(bm, w, d, h):
    n = max(1, int(w / max(h * 0.55, 1e-6)))
    for i in range(n):
        cx = -w / 2 + w * (i + 0.5) / n
        _tree_at(bm, min(w / n, h * 0.65), d, h * (0.78 + 0.16 * (i % 2)), (cx, 0, 0))
    return False


def _pumpkin_at(bm, r, at):
    """Ribbed spheroid with a stubby stem."""
    for i in range(7):
        a = i * math.pi * 2.0 / 7.0
        _sphere(bm, r, 8, 6,
                (at[0] + math.cos(a) * r * 0.26, at[1] + math.sin(a) * r * 0.26, at[2]))
    _cyl(bm, r * 0.15, r * 0.66, 6, (at[0], at[1], at[2] + r * 0.95))


def b_pumpkin(bm, w, d, h):
    _pumpkin_at(bm, min(w, d, h) * 0.5, (0, 0, 0))
    return True


def b_pumpkins(bm, w, d, h):
    """A patch of pumpkins scattered across the plot."""
    r = max(h * 0.42, 1e-5)
    nx = max(1, int(w / (r * 2.6)))
    ny = max(1, int(d / (r * 2.6)))
    for i in range(nx):
        for j in range(ny):
            cx = -w / 2 + w * (i + 0.5) / nx
            cy = -d / 2 + d * (j + 0.5) / ny
            _pumpkin_at(bm, r * (0.72 + 0.13 * ((i + j) % 3)), (cx, cy, 0))
    return True


def b_speaker(bm, w, d, h):
    """Stack of cabinets, each fronted by two driver rings."""
    n = max(1, int(h / max(min(w, d) * 1.15, 1e-6)))
    cab = h / n
    for i in range(n):
        cz = -h / 2 + cab * (i + 0.5)
        _cube(bm, w, d, cab * 0.92, (0, 0, cz))
        for zz, cr in ((cab * 0.2, w * 0.3), (-cab * 0.2, w * 0.34)):
            vs = _cyl(bm, cr, d * 0.1, 12, (0, 0, 0))
            bmesh.ops.transform(bm, matrix=Matrix.Rotation(math.pi / 2, 4, "X"), verts=vs)
            bmesh.ops.translate(bm, vec=(0, -d * 0.5, cz + zz), verts=vs)
    return False


def b_car(bm, w, d, h):
    """Generic hull: lower body, cabin, four wheels."""
    _cube(bm, w, d * 0.92, h * 0.42, (0, 0, -h * 0.06))
    _cube(bm, w * 0.62, d * 0.5, h * 0.32, (0, 0, h * 0.3))
    r = h * 0.26
    for sx in (-1, 1):
        for sy in (-1, 1):
            vs = _cyl(bm, r, w * 0.16, 12, (0, 0, 0))
            m = Matrix.Rotation(math.pi / 2, 4, "Y")
            bmesh.ops.transform(bm, matrix=m, verts=vs)
            bmesh.ops.translate(
                bm, vec=(sx * w * 0.46, sy * d * 0.3, -h * 0.28), verts=vs
            )
    return False


def b_wheels(bm, w, d, h):
    for sy in (-1, 1):
        vs = _cyl(bm, 0.5, 0.34, 14, (0, 0, 0))
        m = Matrix.Rotation(math.pi / 2, 4, "Y")
        bmesh.ops.transform(bm, matrix=m, verts=vs)
        bmesh.ops.translate(bm, vec=(0, sy * 0.5, 0), verts=vs)
    return True


def b_hand(bm, w, d, h):
    """Palm slab with four fingers and a thumb."""
    _cube(bm, w * 0.6, d * 0.32, h * 0.42, (0, 0, -h * 0.16))
    for i in range(4):
        x = -w * 0.26 + w * 0.52 * i / 3.0
        fh = h * (0.42 + 0.07 * (1 if i in (1, 2) else 0))
        _cube(bm, w * 0.1, d * 0.22, fh, (x, 0, h * 0.05 + fh / 2))
    _cube(bm, w * 0.3, d * 0.2, h * 0.12, (-w * 0.38, 0, -h * 0.1))
    return False


def b_arena(bm, w, d, h):
    """Stadium bowl: an outer wall stepped inward."""
    for i, (rr, zz) in enumerate(((0.5, -0.5), (0.44, -0.1), (0.38, 0.3))):
        outer = _cyl(bm, rr, h * 0.34, 24, (0, 0, h * zz))
    return True


def b_tombstone(bm, w, d, h):
    _cube(bm, w, d, h * 0.8, (0, 0, -h * 0.1))
    _cyl(bm, w * 0.5, d, 12, (0, 0, h * 0.3))
    return False


def b_railing(bm, w, d, h):
    t = h * 0.09
    _cube(bm, w, t, t, (0, 0, h / 2 - t / 2))
    _cube(bm, w, t, t, (0, 0, -h * 0.1))
    for i in range(6):
        x = -w / 2 + w * (i + 0.5) / 6.0
        _cube(bm, t, t, h, (x, 0, 0))
    return False


def b_bars(bm, w, d, h):
    n = 8
    for i in range(n):
        x = -w / 2 + w * (i + 0.5) / n
        bh = h * (0.35 + 0.65 * abs(math.sin(i * 1.1)))
        _cube(bm, w / (n * 1.8), d, bh, (x, 0, -h / 2 + bh / 2))
    return False


def b_panels(bm, w, d, h):
    for i in range(4):
        x = -w / 2 + w * (i + 0.5) / 4.0
        _cube(bm, w / 5.5, d, h * 0.9, (x, 0, 0))
    return False


# -------------------------------------------------------------- classification
# Ordered: the first pattern that matches a file name wins, so put the specific
# words ahead of the generic ones ("TrackMirror" is a mirror, not a track).
RULES = [
    (r"rlcar|_car|carbody|interscope.*body|\bbody\b", b_car),
    (r"wheel", b_wheels),
    (r"speaker", b_speaker),
    (r"pumpkinsmain|pumpkins", b_pumpkins),
    (r"pumpkin", b_pumpkin),
    (r"zombiehand|hand", b_hand),
    (r"arena", b_arena),
    (r"tombstone", b_tombstone),
    (r"cloud", b_cloud),
    (r"mountain", b_mountains),
    (r"trees", b_trees),
    (r"tree", b_tree),
    (r"buildings|farbuildings|backgroundbuildings", b_buildings),
    (r"building", b_building),
    (r"mirror|reflector|floor|ceiling|waterfall|rain|flat|curve|runway|pier", b_plane),
    (r"ring", b_square_ring),
    (r"construction|structure", b_construction),
    (r"column", b_columns),
    (r"pillar|tube", b_pillar),
    (r"hemisphere", b_hemisphere),
    (r"sphere|dome", b_sphere),
    (r"cone", b_cone),
    (r"triangle", b_triangle),
    (r"rail", b_railing),
    (r"spectrogram|strip|bars", b_bars),
    (r"panel", b_panels),
    (r"cylinder|pipe", b_cylinder),
]

# Gameplay objects: exact names, so they keep the shapes the game logic expects.
CORE = {
    "note_cube.obj": ("rounded_cube", True),
    "bomb.obj": ("bomb", True),
    "chain_link.obj": ("chain_link", False),
    "note_arrow.obj": ("arrow", False),
    "box_frame.obj": ("box_frame", False),
    "box_fake_glow.obj": ("box", False),
    "saber_blade.obj": ("saber", True),
    "saber_handle.obj": ("saber", True),
    "saber_glowing_edges.obj": ("saber", True),
    "ring_big.obj": ("square_ring", False),
    "ring_small.obj": ("square_ring", False),
}


def build_core(bm, kind, w, d, h):
    if kind == "rounded_cube":
        _cube(bm, w, d, h)
        _bevel(bm, min(w, d, h) * 0.11, 3)
        return True
    if kind == "bomb":
        _ico(bm, 2, 0.5)
        return True
    if kind == "chain_link":
        _cube(bm, w, d, h)
        _bevel(bm, min(w, h) * 0.16, 2)
        return True
    if kind == "arrow":
        bm2 = bm
        v = [bm2.verts.new(p) for p in (
            (-0.5, 0.0, 0.5), (0.0, 0.0, -0.5), (0.5, 0.0, 0.5),
            (0.0, 0.0, 0.12),
        )]
        bm2.faces.new((v[0], v[1], v[3]))
        bm2.faces.new((v[1], v[2], v[3]))
        bmesh.ops.solidify(bm2, geom=list(bm2.faces), thickness=0.06)
        return False
    if kind == "box_frame":
        _frame(bm, w, d, h, min(w, h) * 0.06)
        return False
    if kind == "square_ring":
        _frame(bm, w, d, h, max(w, h) * 0.03)
        return False
    if kind == "saber":
        _cyl(bm, 0.5, 1.0, 14)
        return True
    _cube(bm, w, d, h)
    return False


def pick(name):
    low = name.lower()
    for pat, fn in RULES:
        if re.search(pat, low):
            return fn
    return b_rounded_box


# How each shape meets its target box:
#   fit     - stretch to fill it (walls, floors, frames, structural pieces)
#   uniform - scale evenly and centre, so the object keeps its proportions
#   place   - the builder already worked at the target size, so only centre it
PLACE = {b_cloud, b_trees, b_tree, b_buildings, b_pumpkins, b_speaker}
UNIFORM = {b_car, b_hand, b_pumpkin, b_tombstone, b_arena, b_wheels}


# ------------------------------------------------------------------ conversion
def zup_to_yup(bm):
    bmesh.ops.transform(bm, matrix=Matrix.Rotation(-math.pi / 2, 4, "X"), verts=bm.verts)


def _bounds(bm):
    co = [v.co for v in bm.verts]
    mn = [min(c[i] for c in co) for i in range(3)]
    mx = [max(c[i] for c in co) for i in range(3)]
    return mn, mx


def fit(bm, tmin, tmax):
    if not bm.verts:
        return
    mn, mx = _bounds(bm)
    size = [mx[i] - mn[i] for i in range(3)]
    for v in bm.verts:
        for i in range(3):
            if size[i] > 1e-9:
                t = (v.co[i] - mn[i]) / size[i]
                v.co[i] = tmin[i] + t * (tmax[i] - tmin[i])
            else:
                v.co[i] = (tmin[i] + tmax[i]) * 0.5


def fit_uniform(bm, tmin, tmax):
    """Scale evenly so the shape keeps its proportions inside the target box."""
    if not bm.verts:
        return
    mn, mx = _bounds(bm)
    ratios = [
        (tmax[i] - tmin[i]) / (mx[i] - mn[i])
        for i in range(3)
        if mx[i] - mn[i] > 1e-9
    ]
    s = min(ratios) if ratios else 1.0
    for v in bm.verts:
        for i in range(3):
            c = (mn[i] + mx[i]) * 0.5
            v.co[i] = (v.co[i] - c) * s + (tmin[i] + tmax[i]) * 0.5


def center(bm, tmin, tmax):
    if not bm.verts:
        return
    mn, mx = _bounds(bm)
    for v in bm.verts:
        for i in range(3):
            v.co[i] += (tmin[i] + tmax[i]) * 0.5 - (mn[i] + mx[i]) * 0.5


def write_obj(path, bm, smooth):
    bm.normal_update()
    bm.verts.ensure_lookup_table()
    for i, v in enumerate(bm.verts):
        v.index = i
    co = [v.co for v in bm.verts]
    mn = [min(c[i] for c in co) for i in range(3)]
    ext = [max(max(c[i] for c in co) - mn[i], 1e-6) for i in range(3)]

    out = ["# generated by tools/art/gen_meshes.py"]
    for c in co:
        out.append("v %.6f %.6f %.6f" % (c.x, c.y, c.z))

    uvs, nrm, faces = [], [], []
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        ui, vi = [i for i in range(3) if i != ax]
        idx = []
        for loop in f.loops:
            p = loop.vert.co
            uvs.append(((p[ui] - mn[ui]) / ext[ui], (p[vi] - mn[vi]) / ext[vi]))
            nn = loop.vert.normal if smooth else n
            nrm.append((nn.x, nn.y, nn.z))
            idx.append((loop.vert.index + 1, len(uvs), len(nrm)))
        faces.append(idx)

    for u, v in uvs:
        out.append("vt %.6f %.6f" % (u, v))
    for a, b, c in nrm:
        out.append("vn %.6f %.6f %.6f" % (a, b, c))
    for idx in faces:
        out.append("f " + " ".join("%d/%d/%d" % t for t in idx))

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        fh.write("\n".join(out) + "\n")
    return len(co), len(faces)


def main():
    dims = json.load(open(DIMS))
    total = 0
    for rel in sorted(dims):
        spec = dims[rel]
        tmin, tmax = spec["min"], spec["max"]
        w = max(tmax[0] - tmin[0], 1e-4)
        h = max(tmax[1] - tmin[1], 1e-4)   # target Y is up
        d = max(tmax[2] - tmin[2], 1e-4)

        bm = bmesh.new()
        base = os.path.basename(rel)
        if base in CORE:
            smooth = build_core(bm, CORE[base][0], w, d, h)
            mode = "fit"
        else:
            fn = pick(base)
            smooth = fn(bm, w, d, h)
            mode = "place" if fn in PLACE else "uniform" if fn in UNIFORM else "fit"

        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        zup_to_yup(bm)
        if mode == "fit":
            fit(bm, tmin, tmax)
        elif mode == "uniform":
            fit_uniform(bm, tmin, tmax)
        else:
            center(bm, tmin, tmax)
        nv, nf = write_obj(os.path.join(OUT, rel), bm, smooth)
        bm.free()
        total += 1
    print("generated %d meshes into %s" % (total, OUT))


if __name__ == "__main__":
    main()
